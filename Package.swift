// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeTelegram",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NeTelegram", targets: ["NeTelegramApp"]),
        .library(name: "NeTelegramCore", targets: ["NeTelegramCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(name: "TDLibCBridge", publicHeadersPath: "include"),
        .target(name: "NeTelegramCore", dependencies: ["TDLibCBridge"]),
        .executableTarget(
            name: "NeTelegramApp",
            dependencies: ["NeTelegramCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"], .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(name: "NeTelegramCoreTests", dependencies: ["NeTelegramCore"]),
    ]
)
