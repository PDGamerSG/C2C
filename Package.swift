// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "C2CCore", targets: ["C2CCore"]),
    .executable(name: "C2CSmoke", targets: ["C2CSmoke"])
]

var targets: [Target] = [
    .target(name: "C2CCore"),
    .executableTarget(name: "C2CSmoke", dependencies: ["C2CCore"]),
    .target(name: "C2CLinuxSupport", dependencies: ["C2CCore"]),
    .executableTarget(name: "C2CLinux", dependencies: ["C2CCore", "C2CLinuxSupport", "C2CLinuxGTK"]),
    .target(
        name: "C2CLinuxGTK",
        dependencies: ["C2CGTK"],
        path: "Sources/C2CLinuxGTK",
        publicHeadersPath: "include",
        linkerSettings: [.linkedLibrary("gtk-4", .when(platforms: [.linux]))]
    ),
    .systemLibrary(
        name: "C2CGTK",
        path: "Sources/C2CGTK",
        pkgConfig: "gtk4",
        providers: [.apt(["libgtk-4-dev"]), .brew(["gtk4"])]
    ),
    .testTarget(name: "C2CCoreTests", dependencies: ["C2CCore"]),
    .testTarget(name: "C2CLinuxTests", dependencies: ["C2CLinuxSupport"])
]

#if os(macOS)
products.append(.executable(name: "C2C", targets: ["C2CApp"]))
targets.insert(.executableTarget(name: "C2CApp", dependencies: ["C2CCore"]), at: 2)
#endif

let package = Package(name: "C2C", platforms: [.macOS(.v13)], products: products, targets: targets)
