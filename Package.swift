// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BP7",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BP7",
            targets: ["BP7"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/edgeengineer/cbor.git", from: "0.0.6"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.14.0"),
        .package(url: "https://github.com/edgeengineer/cyclic-redundancy-check.git", from: "0.0.5"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BP7",
            dependencies: [
                .product(name: "CBOR", package: "cbor"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CyclicRedundancyCheck", package: "cyclic-redundancy-check")
            ]
        ),
        .testTarget(
            name: "BP7Tests",
            dependencies: ["BP7"]
        ),
    ]
)
