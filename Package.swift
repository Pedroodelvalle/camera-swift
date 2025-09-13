// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraApp",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "CameraApp",
            targets: ["CameraApp"]),
    ],
    dependencies: [
        // Add your dependencies here
        // Example: .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CameraApp",
            dependencies: [],
            path: "Camera",
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CameraAppTests",
            dependencies: ["CameraApp"],
            path: "CameraTests"
        ),
    ]
)
