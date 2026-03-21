// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenNotch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "OpenNotch", targets: ["OpenNotch"]),
        .library(name: "OpenNotchCore", targets: ["OpenNotchCore"]),
    ],
    targets: [
        .target(
            name: "OpenNotchCore"
        ),
        .executableTarget(
            name: "OpenNotch",
            dependencies: ["OpenNotchCore"]
        ),
        .testTarget(
            name: "OpenNotchCoreTests",
            dependencies: ["OpenNotchCore"]
        ),
    ]
)
