// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThreeMinutesTimerKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ThreeMinutesTimerKit",
            targets: ["ThreeMinutesTimerKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ThreeMinutesTimerKit",
            dependencies: []),
        .testTarget(
            name: "ThreeMinutesTimerKitTests",
            dependencies: ["ThreeMinutesTimerKit"]),
    ]
)
