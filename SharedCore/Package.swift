// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: ["Starscream"]),
        .testTarget(
            name: "SharedCoreTests",
            dependencies: ["SharedCore"]),
    ]
)
