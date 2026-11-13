// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SleepScience",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SleepScience", targets: ["SleepScience"]),
        .executable(name: "sleep-curve", targets: ["SleepCurve"]),
    ],
    targets: [
        .target(name: "SleepScience"),
        .executableTarget(name: "SleepCurve", dependencies: ["SleepScience"]),
        .testTarget(name: "SleepScienceTests", dependencies: ["SleepScience"]),
    ]
)
