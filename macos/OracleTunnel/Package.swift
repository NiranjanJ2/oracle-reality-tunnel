// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OracleTunnel",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OracleTunnelCore", targets: ["OracleTunnelCore"]),
        .executable(name: "OracleTunnel", targets: ["OracleTunnelApp"]),
    ],
    targets: [
        .target(name: "OracleTunnelCore"),
        .executableTarget(name: "OracleTunnelApp", dependencies: ["OracleTunnelCore"]),
        .testTarget(name: "OracleTunnelCoreTests", dependencies: ["OracleTunnelCore"]),
    ]
)
