// swift-tools-version: 5.9
// swift-format-ignore-file
//
// This manifest is rewritten by the release workflow. Do not reformat — the
// trailing `// libghosttyx-url` and `// libghosttyx-checksum` anchors MUST
// stay on the same line as their value literals for CI's sed substitution to
// find them. If you edit this file, preserve those anchors exactly.

import Foundation
import PackageDescription

// --- Remote binary configuration (updated by CI on release) ---
let xcframeworkURL = "https://github.com/sjungling/libghosttyx/releases/download/v0.3.18/libghostty.xcframework.zip"  // libghosttyx-url
let xcframeworkChecksum = "4f7913b19ee87f5594657d00e978899a3bb3f504d696667bbc0db652e54b579d"  // libghosttyx-checksum

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
