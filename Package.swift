// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mqt2",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "mqt2",
            targets: ["mqt2"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/emqx/CocoaMQTT.git",
            from: "2.2.4"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "mqt2",
            dependencies: [
                .product(name: "CocoaMQTT", package: "CocoaMQTT")
            ]
        ),
        .testTarget(
            name: "mqt2Tests",
            dependencies: ["mqt2"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
