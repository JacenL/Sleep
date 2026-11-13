// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SleepScience",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SleepScience", targets: ["SleepScience"]),
    ],
    targets: [
        .target(name: "SleepScience"),
        .testTarget(name: "SleepScienceTests", dependencies: ["SleepScience"]),
    ]
)
