// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeTelegram",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NeTelegram", targets: ["NeTelegramApp"]),
        .library(name: "NeTelegramCore", targets: ["NeTelegramCore"]),
    ],
    targets: [
        .target(name: "TDLibCBridge", publicHeadersPath: "include"),
        .target(name: "NeTelegramCore", dependencies: ["TDLibCBridge"]),
        .executableTarget(name: "NeTelegramApp", dependencies: ["NeTelegramCore"]),
        .testTarget(name: "NeTelegramCoreTests", dependencies: ["NeTelegramCore"]),
    ]
)
