// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExergyCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "ExergyCore", targets: ["ExergyCore"]),
    ],
    targets: [
        .target(
            name: "ExergyCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ExergyCoreTests",
            dependencies: ["ExergyCore"]
        ),
    ]
)
