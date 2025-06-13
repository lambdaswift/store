// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Store",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Store",
            targets: ["Store", "StoreExamples"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lambdaswift/dependencies", from: "0.0.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Store"),
        .target(
            name: "StoreExamples",
            dependencies: [
                "Store",
                .product(name: "Dependencies", package: "dependencies")
            ],
            path: "Sources/StoreExamples"
        ),
        .testTarget(
            name: "StoreTests",
            dependencies: ["Store"]
        ),
        .testTarget(
            name: "StoreExamplesTests",
            dependencies: ["StoreExamples", "Store"]
        ),
    ]
)
