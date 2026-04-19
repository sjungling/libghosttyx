import AppKit
import libghostty

/// An NSView that hosts a ghostty terminal surface.
///
/// This is the main public API for embedding a terminal in a macOS app.
/// It wraps a `ghostty_surface_t` and handles keyboard, mouse, IME,
/// focus, resize, and display change events.
///
/// ## Usage
/// ```swift
/// let terminal = TerminalView(frame: bounds)
/// terminal.delegate = self
/// try terminal.startTerminal(configuration: .init(fontSize: 14))
/// contentView.addSubview(terminal)
/// ```
///
/// ## Important
/// This view does NOT set `wantsLayer` — libghostty creates an `IOSurfaceLayer`
/// and assigns it to the view's layer. Do not manipulate the layer yourself.
@MainActor
open class TerminalView: NSView, @preconcurrency NSTextInputClient {
  /// Delegate for receiving terminal callbacks.
  public weak var delegate: TerminalViewDelegate?

  /// The underlying ghostty surface wrapper.
  internal private(set) var surface: GhosttySurface?

  /// The configuration used to start this terminal.
  public private(set) var configuration: TerminalConfiguration?

  /// Whether the terminal has been started.
  public var isRunning: Bool { surface != nil }

  /// Returns the text content of a single viewport row (0-indexed from top).
  public func readLineText(row: Int) -> String? {
    guard let size = surface?.size else { return nil }
    let sel = ghostty_selection_s(
      top_left: ghostty_point_s(
        tag: GHOSTTY_POINT_VIEWPORT, coord: GHOSTTY_POINT_COORD_EXACT, x: 0, y: UInt32(row)),
      bottom_right: ghostty_point_s(
        tag: GHOSTTY_POINT_VIEWPORT, coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT,
        x: UInt32(size.columns), y: UInt32(row)),
      rectangle: true
    )
    return surface?.readText(selection: sel)
  }

  /// Returns grid dimensions and cell size in points (for coordinate mapping).
  public var gridInfo: (columns: Int, rows: Int, cellWidth: CGFloat, cellHeight: CGFloat)? {
    guard let size = surface?.size else { return nil }
    let scale = window?.backingScaleFactor ?? 1.0
    return (
      columns: Int(size.columns),
      rows: Int(size.rows),
      cellWidth: CGFloat(size.cell_width_px) / scale,
      cellHeight: CGFloat(size.cell_height_px) / scale
    )
  }

  /// Current terminal title.
  public private(set) var title: String = ""

  /// Current working directory.
  public private(set) var workingDirectory: String?

  /// The OSC 8 hyperlink URL currently under the mouse cursor, or nil.
  public private(set) var currentHoverLink: String?

  /// Marked text for IME composition.
  private var markedTextStorage: NSMutableAttributedString = .init()
  private var _markedRange: NSRange = .init(location: NSNotFound, length: 0)
  private var _selectedRange: NSRange = .init(location: 0, length: 0)

  /// Text accumulated from insertText during a keyDown event.
  /// When non-nil, we're inside a keyDown → interpretKeyEvents call.
  private var keyTextAccumulator: [String]?

  /// Display link for driving rendering.
  private var displayLink: CVDisplayLink?

  /// Raw pointer to the retained WeakBox passed to CVDisplayLink.
  /// Stored for teardown — released in deinit via Unmanaged.
  private var displayLinkBoxPtr: UnsafeMutableRawPointer?

  // MARK: - Initialization

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    commonInit()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    // Accept first responder for keyboard input
    // Do NOT set wantsLayer — libghostty creates the layer

    // Register for appearance change notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appearanceDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  deinit {
    // Capture locals before any writes so we don't touch main-actor
    // state from the nonisolated deinit context.
    if let link = displayLink {
      CVDisplayLinkStop(link)
    }
    if let ptr = displayLinkBoxPtr {
      Unmanaged<WeakBox<TerminalView>>.fromOpaque(ptr).release()
    }
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Teardown

  /// Stops rendering, releases the ghostty surface, and detaches from
  /// notification observers.
  ///
  /// Use this when embedding the view in a container (e.g. SwiftUI
  /// `NSViewRepresentable`) that may keep the view alive longer than
  /// you need it — for example, `WindowGroup` retains scene state for
  /// tabbed windows even after the tab closes. Calling `close()` frees
  /// the expensive resources (display link, Metal surface, PTY) even if
  /// the NSView itself is still reachable from the outer view tree.
  ///
  /// Safe to call multiple times. After calling `close()`, the view
  /// cannot be restarted — create a new instance instead.
  public func close() {
    if let link = displayLink {
      CVDisplayLinkStop(link)
      self.displayLink = nil
    }
    if let ptr = displayLinkBoxPtr {
      Unmanaged<WeakBox<TerminalView>>.fromOpaque(ptr).release()
      self.displayLinkBoxPtr = nil
    }
    // Dropping the surface runs GhosttySurface.deinit which calls
    // ghostty_surface_free, releasing the PTY, renderer, and child
    // process group.
    self.surface = nil
    NotificationCenter.default.removeObserver(self)
  }

  /// Pauses or resumes the terminal's Metal renderer.
  ///
  /// Pass `true` when the view is removed from the window (parked in a cache)
  /// so the CVDisplayLink draw callbacks become no-ops. Pass `false` when the
  /// view is re-attached to resume rendering.
  ///
  /// This is called automatically when the window's occlusion state changes.
  /// Call it explicitly when removing the view from the hierarchy without
  /// destroying it (e.g. to preserve scroll history across navigation).
  public func setOccluded(_ occluded: Bool) {
    surface?.setOcclusion(occluded)
  }

  /// Stops the display link, pausing Metal rendering without destroying the surface.
  ///
  /// Call this when removing the view from the window hierarchy without intending
  /// to tear it down (e.g. parking in a view cache to preserve scroll history).
  /// The surface, PTY, and scroll buffer remain intact — only the 60 Hz render
  /// loop is stopped. Call `resumeDisplayLink()` to restart rendering when the
  /// view is re-attached.
  public func pauseDisplayLink() {
    guard let link = displayLink else { return }
    CVDisplayLinkStop(link)
  }

  /// Restarts the display link after `pauseDisplayLink()`.
  ///
  /// Call this when re-inserting a previously-paused view into the window
  /// hierarchy. No-op if the display link was never started or already running.
  public func resumeDisplayLink() {
    guard let link = displayLink else { return }
    CVDisplayLinkStart(link)
  }

  // MARK: - Starting the Terminal

  /// Starts the terminal with the given configuration.
  ///
  /// This creates a ghostty surface and begins rendering. The engine must
  /// be initialized before calling this method.
  ///
  /// - Parameter configuration: Terminal configuration.
  /// - Throws: `GhosttyError` if the engine isn't initialized or surface creation fails.
  public func startTerminal(configuration: TerminalConfiguration = .init()) throws {
    guard surface == nil else { return }

    let engine = GhosttyEngine.shared
    guard engine.isInitialized else {
      throw GhosttyError.notInitialized
    }

    self.configuration = configuration

    var surfaceConfig = GhosttySurfaceConfig()
    surfaceConfig.scaleFactor = Double(window?.backingScaleFactor ?? 2.0)
    surfaceConfig.fontSize = configuration.fontSize
    surfaceConfig.workingDirectory = configuration.workingDirectory
    surfaceConfig.command = configuration.command
    surfaceConfig.environmentVariables = configuration.environmentVariables

    let newSurface = try engine.createSurface(for: self, config: surfaceConfig)
    self.surface = newSurface

    // Set initial properties
    if let window = window {
      let scale = window.backingScaleFactor
      newSurface.setContentScale(scale)
      updateSurfaceSize()
      updateDisplayID()
    }

    updateColorScheme()

    // Start display link to drive rendering. The ghostty renderer thread's
    // async layer.contents updates aren't reliably composited by CA in a
    // minimal AppKit app. A display link calling ghostty_surface_draw()
    // synchronously renders and presents via the setSurfaceSync path.
    startDisplayLink()
  }

  private func startDisplayLink() {
    var link: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(&link)
    guard let link = link else { return }

    let box = WeakBox(self)
    let ud = Unmanaged.passRetained(box).toOpaque()
    self.displayLinkBoxPtr = ud
    CVDisplayLinkSetOutputCallback(
      link,
      { (_, _, _, _, _, userInfo) -> CVReturn in
        guard let userInfo = userInfo else { return kCVReturnSuccess }
        let box = Unmanaged<WeakBox<TerminalView>>.fromOpaque(userInfo).takeUnretainedValue()
        guard let view = box.value else { return kCVReturnSuccess }
        DispatchQueue.main.async { [weak view] in
          view?.surface?.draw()
        }
        return kCVReturnSuccess
      }, ud)

    self.displayLink = link
    CVDisplayLinkStart(link)
  }

  // MARK: - Public API

  /// Sends text to the terminal's shell stdin.
  public func sendText(_ text: String) {
    surface?.sendText(text)
  }

  /// Sends a synthetic key press + release for the given macOS keycode.
  ///
  /// Unlike ``sendText(_:)``, this goes through the keyboard input path
  /// (not the paste path), so it isn't wrapped in bracketed-paste fenceposts.
  /// Use this for control keys like Return that must trigger shell execution.
  public func sendSyntheticKey(keyCode: UInt16, text: String? = nil) {
    guard let surface else { return }

    var key_ev = ghostty_input_key_s()
    key_ev.action = GHOSTTY_ACTION_PRESS
    key_ev.mods = ghostty_input_mods_e(0)
    key_ev.consumed_mods = ghostty_input_mods_e(0)
    key_ev.keycode = UInt32(keyCode)
    key_ev.composing = false
    key_ev.unshifted_codepoint = 0

    if let text {
      text.withCString { ptr in
        key_ev.text = ptr
        surface.sendKey(key_ev)
      }
    } else {
      key_ev.text = nil
      surface.sendKey(key_ev)
    }

    key_ev.action = GHOSTTY_ACTION_RELEASE
    key_ev.text = nil
    surface.sendKey(key_ev)
  }

  /// Explicitly sets the terminal color scheme.
  public func setColorScheme(dark: Bool) {
    surface?.setColorScheme(dark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
  }

  /// Sets the terminal font size (in points).
  public func setFontSize(_ size: Float) {
    surface?.bindingAction("set_font_size:\(size)")
  }

  /// Increases the font size by the given delta.
  public func increaseFontSize(_ delta: Float = 1) {
    surface?.bindingAction("increase_font_size:\(delta)")
  }

  /// Decreases the font size by the given delta.
  public func decreaseFontSize(_ delta: Float = 1) {
    surface?.bindingAction("decrease_font_size:\(delta)")
  }

  /// Resets font size to the configured default.
  public func resetFontSize() {
    surface?.bindingAction("reset_font_size")
  }

  // MARK: - View Lifecycle

  open override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    if let window = window {
      surface?.setContentScale(window.backingScaleFactor)
      updateSurfaceSize()
      updateDisplayID()

      // Observe window changes
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidChangeBackingProperties),
        name: NSWindow.didChangeBackingPropertiesNotification,
        object: window
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(windowDidChangeOcclusionState),
        name: NSWindow.didChangeOcclusionStateNotification,
        object: window
      )
    }
  }

  open override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    updateSurfaceSize()
  }

  open override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateColorScheme()
  }

  // MARK: - Focus

  open override var acceptsFirstResponder: Bool { true }

  open override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.type == .keyDown else { return false }
    guard let surface = surface else { return false }

    // Check if this key event is a Ghostty binding. If it is, route it
    // through keyDown so Ghostty handles it directly (e.g. Cmd+V →
    // paste_from_clipboard, Cmd+C → copy_to_clipboard). Without this,
    // returning false here causes the macOS menu to intercept those
    // shortcuts and fire paste:/copy: on the responder chain. AppKit's
    // NSResponder paste: falls back to sendText: outside a keyDown
    // context, bypassing Ghostty entirely and producing unexpected behavior.
    var keyEvent = event.ghosttyKeyEvent(GHOSTTY_ACTION_PRESS)
    let (isBinding, _) = (event.characters ?? "").withCString { ptr in
      keyEvent.text = ptr
      return surface.keyIsBinding(keyEvent)
    }
    guard isBinding else { return false }

    // Don't intercept app-level shortcuts — let the macOS menu handle them.
    // Ghostty has default bindings for quit (Cmd+Q), close (Cmd+W),
    // new-window (Cmd+N), new-tab (Cmd+T), and open-config (Cmd+,).
    // Returning false for these lets the macOS menu fire the appropriate
    // app actions (NSApp terminate, window close, etc.) rather than routing
    // through Ghostty's action callback which the host returns false for.
    // Also exclude Cmd+H (hide) and Cmd+M (minimize), which are system shortcuts.
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let char = event.charactersIgnoringModifiers?.lowercased() ?? ""
    if flags == .command && ["q", "w", "n", "t", ",", "h", "m"].contains(char) {
      return false
    }

    keyDown(with: event)
    return true
  }

  open override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    if result {
      surface?.setFocus(true)
    }
    return result
  }

  open override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    if result {
      surface?.setFocus(false)
    }
    return result
  }

  // MARK: - Keyboard Input

  open override func keyDown(with event: NSEvent) {
    guard surface != nil else {
      interpretKeyEvents([event])
      return
    }

    let action: ghostty_input_action_e =
      event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS

    // Track whether we had marked text before this event
    let markedTextBefore = markedTextStorage.length > 0

    // Begin accumulating text from insertText calls
    keyTextAccumulator = []
    defer { keyTextAccumulator = nil }

    interpretKeyEvents([event])

    // Sync preedit state
    if markedTextStorage.length > 0 {
      surface?.sendPreedit(markedTextStorage.string)
    } else if markedTextBefore {
      surface?.sendPreedit(nil)
    }

    if let list = keyTextAccumulator, !list.isEmpty {
      // We have composed text from insertText — send key with that text
      for text in list {
        sendKeyAction(action, event: event, text: text)
      }
    } else {
      // No composed text — send key event with the event's characters
      sendKeyAction(
        action,
        event: event,
        text: event.ghosttyCharacters,
        composing: markedTextStorage.length > 0 || markedTextBefore
      )
    }
  }

  open override func keyUp(with event: NSEvent) {
    sendKeyAction(GHOSTTY_ACTION_RELEASE, event: event)
  }

  open override func doCommand(by selector: Selector) {
    // Intentionally empty — prevents NSBeep for unhandled selectors
  }

  /// Sends a key event to the ghostty surface.
  private func sendKeyAction(
    _ action: ghostty_input_action_e,
    event: NSEvent,
    text: String? = nil,
    composing: Bool = false
  ) {
    guard let surface = surface else { return }

    var key_ev = event.ghosttyKeyEvent(action)
    key_ev.composing = composing

    // Only send text if it's not a control character (ghostty handles those internally)
    var result = false
    if let text, !text.isEmpty,
      let codepoint = text.utf8.first, codepoint >= 0x20
    {
      text.withCString { ptr in
        key_ev.text = ptr
        result = surface.sendKey(key_ev)
      }
    } else {
      result = surface.sendKey(key_ev)
    }

  }

  open override func flagsChanged(with event: NSEvent) {
    // Modifier keys generate flagsChanged, not keyDown/keyUp.
    // Determine press/release based on whether the modifier is now set.
    let mods = ghosttyMods(event.modifierFlags)

    var keyEvent = ghostty_input_key_s()
    keyEvent.action = isModifierPress(event) ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE
    keyEvent.mods = mods
    keyEvent.consumed_mods = ghostty_input_mods_e(0)
    keyEvent.keycode = UInt32(event.keyCode)
    keyEvent.composing = false
    keyEvent.text = nil
    keyEvent.unshifted_codepoint = 0

    surface?.sendKey(keyEvent)
  }

  private func isModifierPress(_ event: NSEvent) -> Bool {
    let key = ghosttyKey(from: event.keyCode)
    let flags = event.modifierFlags

    switch key {
    case GHOSTTY_KEY_SHIFT_LEFT, GHOSTTY_KEY_SHIFT_RIGHT:
      return flags.contains(.shift)
    case GHOSTTY_KEY_CONTROL_LEFT, GHOSTTY_KEY_CONTROL_RIGHT:
      return flags.contains(.control)
    case GHOSTTY_KEY_ALT_LEFT, GHOSTTY_KEY_ALT_RIGHT:
      return flags.contains(.option)
    case GHOSTTY_KEY_META_LEFT, GHOSTTY_KEY_META_RIGHT:
      return flags.contains(.command)
    case GHOSTTY_KEY_CAPS_LOCK:
      return flags.contains(.capsLock)
    default:
      return false
    }
  }

  // MARK: - Mouse Input

  open override func mouseDown(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_PRESS,
      button: GHOSTTY_MOUSE_LEFT,
      mods: ghosttyMods(event.modifierFlags)
    )
  }

  open override func mouseUp(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_RELEASE,
      button: GHOSTTY_MOUSE_LEFT,
      mods: ghosttyMods(event.modifierFlags)
    )
  }

  open override func mouseDragged(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
  }

  open override func mouseMoved(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
  }

  open override func rightMouseDown(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_PRESS,
      button: GHOSTTY_MOUSE_RIGHT,
      mods: ghosttyMods(event.modifierFlags)
    )
  }

  open override func rightMouseUp(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_RELEASE,
      button: GHOSTTY_MOUSE_RIGHT,
      mods: ghosttyMods(event.modifierFlags)
    )
  }

  open override func otherMouseDown(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    let button = ghosttyMouseButton(event.buttonNumber)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_PRESS, button: button, mods: ghosttyMods(event.modifierFlags))
  }

  open override func otherMouseUp(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    let button = ghosttyMouseButton(event.buttonNumber)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))
    surface?.sendMouseButton(
      GHOSTTY_MOUSE_RELEASE, button: button, mods: ghosttyMods(event.modifierFlags))
  }

  open override func scrollWheel(with event: NSEvent) {
    let pos = convertToGhosttyCoords(event)
    surface?.sendMousePos(x: pos.x, y: pos.y, mods: ghosttyMods(event.modifierFlags))

    let precision = event.hasPreciseScrollingDeltas
    let momentum = ghosttyMomentumPhase(event.momentumPhase)
    let scrollMods = ghosttyScrollMods(precision: precision, momentumPhase: momentum)

    surface?.sendMouseScroll(
      x: event.scrollingDeltaX,
      y: event.scrollingDeltaY,
      mods: scrollMods
    )
  }

  open override func pressureChange(with event: NSEvent) {
    surface?.sendMousePressure(stage: UInt32(event.stage), pressure: Double(event.pressure))
  }

  /// Converts AppKit coordinates (origin bottom-left) to ghostty coordinates (origin top-left).
  ///
  /// Returns point coordinates (not pixels). The ghostty surface internally
  /// converts to pixels using the content scale set via `setContentScale()`.
  /// This matches the upstream Ghostty macOS app's `SurfaceView_AppKit`.
  private func convertToGhosttyCoords(_ event: NSEvent) -> NSPoint {
    let localPoint = convert(event.locationInWindow, from: nil)

    // Flip Y: AppKit is bottom-left origin, ghostty expects top-left
    let flippedY = bounds.height - localPoint.y

    return NSPoint(
      x: localPoint.x,
      y: flippedY
    )
  }

  // MARK: - NSTextInputClient (IME)

  @MainActor
  public func insertText(_ string: Any, replacementRange: NSRange) {
    guard NSApp.currentEvent != nil else { return }

    let chars: String
    switch string {
    case let v as NSAttributedString:
      chars = v.string
    case let v as String:
      chars = v
    default:
      return
    }

    // Clear marked text since insertText ends composition
    unmarkText()

    // If we're inside a keyDown event, accumulate text for later
    if keyTextAccumulator != nil {
      keyTextAccumulator!.append(chars)
      return
    }

    // Outside keyDown (shouldn't happen normally), send text directly
    surface?.sendText(chars)
  }

  @MainActor
  public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
    let attrStr: NSAttributedString
    if let s = string as? NSAttributedString {
      attrStr = s
    } else if let s = string as? String {
      attrStr = NSAttributedString(string: s)
    } else {
      return
    }

    markedTextStorage = NSMutableAttributedString(attributedString: attrStr)
    _markedRange = NSRange(location: 0, length: attrStr.length)
    _selectedRange = selectedRange

    // Send preedit to ghostty
    let text = attrStr.string
    if text.isEmpty {
      surface?.sendPreedit(nil)
    } else {
      surface?.sendPreedit(text)
    }
  }

  @MainActor
  public func unmarkText() {
    markedTextStorage.mutableString.setString("")
    _markedRange = NSRange(location: NSNotFound, length: 0)
    surface?.sendPreedit(nil)
  }

  @MainActor
  public func selectedRange() -> NSRange {
    return _selectedRange
  }

  @MainActor
  public func markedRange() -> NSRange {
    return _markedRange
  }

  @MainActor
  public func hasMarkedText() -> Bool {
    return _markedRange.location != NSNotFound && _markedRange.length > 0
  }

  @MainActor
  public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?)
    -> NSAttributedString?
  {
    return nil
  }

  @MainActor
  public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
    return []
  }

  @MainActor
  public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
    guard let surface = surface else { return .zero }

    let ime = surface.imePoint()
    let scale = window?.backingScaleFactor ?? 1.0

    // Convert from ghostty coords (top-left, pixels) to screen coords
    let viewX = ime.x / scale
    let viewY = bounds.height - (ime.y / scale)

    let viewRect = NSRect(x: viewX, y: viewY, width: ime.width / scale, height: ime.height / scale)

    // Convert to screen coordinates
    guard let window = window else { return viewRect }
    let windowRect = convert(viewRect, to: nil)
    return window.convertToScreen(windowRect)
  }

  @MainActor
  public func characterIndex(for point: NSPoint) -> Int {
    return 0
  }

  // MARK: - Action Handling (from GhosttyCallbackBridge)

  /// Reads the clipboard and completes the pending request from libghostty.
  ///
  /// Called by `GhosttyCallbackBridge.readClipboardCallback` on the main thread.
  /// Overridable so tests can observe and intercept clipboard completion without
  /// a real Ghostty surface.
  @MainActor func handleClipboardRequest(
    type: ghostty_clipboard_e,
    state: UnsafeMutableRawPointer?
  ) {
    let content: String? =
      type == GHOSTTY_CLIPBOARD_STANDARD
      ? NSPasteboard.general.string(forType: .string)
      : nil
    surface?.completeClipboardRequest(data: content, state: state, confirmed: true)
  }

  /// Handles a ghostty action routed from the callback bridge.
  @MainActor func handleAction(_ action: GhosttyAction) {
    switch action {
    case .setTitle(let newTitle):
      title = newTitle
      delegate?.setTerminalTitle(source: self, title: newTitle)

    case .setTabTitle(let newTitle):
      delegate?.setTabTitle(source: self, title: newTitle)

    case .bell:
      delegate?.bell(source: self)

    case .cellSize(_, _):
      if let size = surface?.size {
        delegate?.sizeChanged(source: self, newCols: size.columns, newRows: size.rows)
      }

    case .scrollbar(let total, let offset, let length):
      delegate?.scrolled(source: self, position: (total, offset, length))

    case .workingDirectory(let dir):
      workingDirectory = dir
      delegate?.workingDirectoryChanged(source: self, directory: dir)

    case .mouseShape(let shape):
      delegate?.mouseShapeChanged(source: self, shape: Int(shape.rawValue))
      updateCursor(shape)

    case .render:
      // Tell ghostty to execute its Metal rendering pipeline.
      // The RENDER action means "I have new content" — we must call
      // ghostty_surface_draw to actually render it to the Metal layer.
      surface?.draw()

    case .colorChange(let kind, let r, let g, let b):
      delegate?.colorChanged(source: self, kind: Int(kind.rawValue), r: r, g: g, b: b)

    case .openURL(let urlString):
      if let url = URL(string: urlString) {
        delegate?.requestOpenLink(source: self, url: url)
      }

    case .showChildExited(let exitCode, let runtimeMs):
      delegate?.processExited(source: self, exitCode: exitCode, runtimeMs: runtimeMs)

    case .desktopNotification(let title, let body):
      delegate?.desktopNotification(source: self, title: title, body: body)

    case .mouseOverLink(let url):
      currentHoverLink = url
      delegate?.mouseOverLink(source: self, url: url)

    default:
      break
    }
  }

  // MARK: - Private Helpers

  private func updateSurfaceSize() {
    guard let surface = surface, let window = window else { return }
    let scale = window.backingScaleFactor
    let pixelWidth = UInt32(bounds.width * scale)
    let pixelHeight = UInt32(bounds.height * scale)
    surface.setSize(width: pixelWidth, height: pixelHeight)
  }

  private func updateDisplayID() {
    guard let window = window,
      let screen = window.screen,
      let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    else {
      return
    }
    surface?.setDisplayID(displayID)
  }

  private func updateColorScheme() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    surface?.setColorScheme(isDark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
  }

  private func updateCursor(_ shape: ghostty_action_mouse_shape_e) {
    let cursor: NSCursor
    switch shape {
    case GHOSTTY_MOUSE_SHAPE_DEFAULT:
      cursor = .arrow
    case GHOSTTY_MOUSE_SHAPE_TEXT:
      cursor = .iBeam
    case GHOSTTY_MOUSE_SHAPE_POINTER:
      cursor = .pointingHand
    case GHOSTTY_MOUSE_SHAPE_CROSSHAIR:
      cursor = .crosshair
    case GHOSTTY_MOUSE_SHAPE_MOVE:
      cursor = .openHand
    case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED:
      cursor = .operationNotAllowed
    case GHOSTTY_MOUSE_SHAPE_EW_RESIZE:
      cursor = .resizeLeftRight
    case GHOSTTY_MOUSE_SHAPE_NS_RESIZE:
      cursor = .resizeUpDown
    default:
      cursor = .arrow
    }
    cursor.set()
  }

  @objc private func windowDidChangeBackingProperties(_ notification: Notification) {
    guard let window = window else { return }
    let scale = window.backingScaleFactor
    surface?.setContentScale(scale)
    updateSurfaceSize()
  }

  @objc private func windowDidChangeOcclusionState(_ notification: Notification) {
    guard let window = window else { return }
    let occluded = !window.occlusionState.contains(.visible)
    surface?.setOcclusion(occluded)
  }

  @objc private func appearanceDidChange(_ notification: Notification) {
    updateDisplayID()
  }
}

/// A box holding a weak reference, used to safely pass object references
/// through C callback pointers (e.g., CVDisplayLink) without preventing
/// deallocation of the referenced object.
private final class WeakBox<T: AnyObject>: @unchecked Sendable {
  weak var value: T?
  init(_ value: T) { self.value = value }
}
