// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuoteOverlay",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "QuoteOverlay", path: "Sources/QuoteOverlay")
    ]
)
