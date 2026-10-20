// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "hotspotly",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "hotspotly", targets: ["hotspotly"]),
        .executable(name: "HotspotlyBar", targets: ["HotspotlyBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(name: "HotspotlyCore"),
        .executableTarget(name: "hotspotly", dependencies: ["HotspotlyCore"]),
        .executableTarget(name: "HotspotlyHelper", dependencies: ["HotspotlyCore"]),
        .executableTarget(name: "HotspotlyBar", dependencies: ["HotspotlyCore", .product(name: "Sparkle", package: "Sparkle")]),
    ]
)
