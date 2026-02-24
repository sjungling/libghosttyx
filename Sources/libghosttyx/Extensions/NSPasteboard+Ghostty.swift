import AppKit

extension NSPasteboard {
    /// Reads the clipboard content as a UTF-8 string suitable for ghostty.
    var ghosttyString: String? {
        return string(forType: .string)
    }

    /// Writes a string to the clipboard from ghostty.
    func setGhosttyString(_ string: String) {
        clearContents()
        setString(string, forType: .string)
    }
}
