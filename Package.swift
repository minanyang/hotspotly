// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "steadywifi",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "steadywifi", targets: ["steadywifi"]),
        .executable(name: "SteadyWiFiBar", targets: ["SteadyWiFiBar"]),
    ],
    targets: [
        .target(name: "SteadyWiFiCore"),
        .executableTarget(name: "steadywifi", dependencies: ["SteadyWiFiCore"]),
        .executableTarget(name: "SteadyWiFiBar", dependencies: ["SteadyWiFiCore"]),
    ]
)
