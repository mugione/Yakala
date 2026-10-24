// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yakala",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Yakala"),
        .testTarget(name: "YakalaTests", dependencies: ["Yakala"]),
    ]
)
