// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YabaiBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "YabaiBar", targets: ["YabaiBar"]),
        .library(name: "YabaiBarCore", targets: ["YabaiBarCore"]),
    ],
    targets: [
        .target(
            name: "YabaiBarCore"
        ),
        .executableTarget(
            name: "YabaiBar",
            dependencies: ["YabaiBarCore"]
        ),
        .testTarget(
            name: "YabaiBarCoreTests",
            dependencies: ["YabaiBarCore"]
        ),
    ]
)
