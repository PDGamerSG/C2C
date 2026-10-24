// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "C2C",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "C2CCore", targets: ["C2CCore"]),
        .executable(name: "C2C", targets: ["C2CApp"]),
        .executable(name: "C2CSmoke", targets: ["C2CSmoke"])
    ],
    targets: [
        .target(name: "C2CCore"),
        .executableTarget(name: "C2CApp", dependencies: ["C2CCore"]),
        .executableTarget(name: "C2CSmoke", dependencies: ["C2CCore"]),
        .testTarget(name: "C2CCoreTests", dependencies: ["C2CCore"])
    ]
)
