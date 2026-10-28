// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Brief",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Keep SPARKLE_VERSION in .github/workflows/release.yml in step.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "Brief",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Brief",
            // build.sh puts Sparkle.framework into Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ]
)
