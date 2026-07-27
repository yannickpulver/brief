// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brief",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Brief", path: "Sources/Brief")
    ]
)
