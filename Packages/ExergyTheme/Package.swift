// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExergyTheme",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "ExergyTheme", targets: ["ExergyTheme"]),
    ],
    dependencies: [
        .package(path: "../ExergyCore"),
    ],
    targets: [
        .target(
            name: "ExergyTheme",
            dependencies: [
                .product(name: "ExergyCore", package: "ExergyCore"),
            ]
        ),
        .testTarget(
            name: "ExergyThemeTests",
            dependencies: ["ExergyTheme"]
        ),
    ]
)
