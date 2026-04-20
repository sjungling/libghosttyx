// swift-tools-version: 5.9

import Foundation
import PackageDescription

// --- Remote binary configuration (updated by CI on release) ---
let xcframeworkURL =
  "https://github.com/sjungling/libghosttyx/releases/download/v0.3.13/libghostty.xcframework.zip"
let xcframeworkChecksum = "e98c329eb13491503a8999ee19e813b809eb82cb8ff9c4603010e5ce5494be70"

// Use local xcframework if present (local development), otherwise fetch from GitHub Releases
let useLocal = FileManager.default.fileExists(
  atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Frameworks/libghostty.xcframework").path
)

let libghosttyTarget: Target = {
  if useLocal {
    return .binaryTarget(name: "libghostty", path: "Frameworks/libghostty.xcframework")
  } else if !xcframeworkURL.isEmpty {
    return .binaryTarget(name: "libghostty", url: xcframeworkURL, checksum: xcframeworkChecksum)
  } else {
    fatalError(
      """
      No libghostty.xcframework found locally and no release URL configured.
      Run `make xcframework` to build locally, or use a tagged release.
      """)
  }
}()

let package = Package(
  name: "libghosttyx",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "libghosttyx",
      targets: ["libghosttyx"]
    )
  ],
  targets: [
    libghosttyTarget,
    .target(
      name: "libghosttyx",
      dependencies: ["libghostty"],
      path: "Sources/libghosttyx",
      resources: [
        .copy("ghostty"),
        .copy("terminfo"),
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("Carbon"),
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreText"),
        .linkedFramework("Foundation"),
        .linkedFramework("IOSurface"),
        .linkedFramework("Metal"),
        .linkedFramework("QuartzCore"),
        .linkedLibrary("c++"),
        .linkedLibrary("z"),
      ]
    ),
    .testTarget(
      name: "libghosttyxTests",
      dependencies: ["libghosttyx"],
      path: "Tests/libghosttyxTests"
    ),
  ]
)
