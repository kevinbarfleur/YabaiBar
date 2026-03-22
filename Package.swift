// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VibeNotch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "VibeNotch", targets: ["VibeNotch"]),
        .library(name: "VibeNotchCore", targets: ["VibeNotchCore"]),
    ],
    targets: [
        .target(
            name: "VibeNotchCore"
        ),
        .executableTarget(
            name: "VibeNotch",
            dependencies: ["VibeNotchCore"]
        ),
        .testTarget(
            name: "VibeNotchCoreTests",
            dependencies: ["VibeNotchCore"]
        ),
    ]
)
