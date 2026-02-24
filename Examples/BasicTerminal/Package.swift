// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BasicTerminal",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "BasicTerminal",
            dependencies: [
                .product(name: "libghosttyx", package: "libghosttyx"),
            ],
            path: "Sources"
        ),
    ]
)
