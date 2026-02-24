// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "libghosttyx",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "libghosttyx",
            targets: ["libghosttyx"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "libghostty",
            path: "Frameworks/libghostty.xcframework"
        ),
        .target(
            name: "libghosttyx",
            dependencies: ["libghostty"],
            path: "Sources/libghosttyx",
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
