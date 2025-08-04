// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisruptionTolerantNetworking",
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
        .library(
            name: "DisruptionTolerantNetworking",
            targets: ["DisruptionTolerantNetworking"]),
        .library(
            name: "TransportServices",
            targets: ["TransportServices"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/edgeengineer/cbor.git", from: "0.0.6"),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0" ..< "4.0.0"),
        .package(url: "https://github.com/edgeengineer/cyclic-redundancy-check.git", from: "0.0.4"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.0.0"),
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
        .target(
            name: "DisruptionTolerantNetworking",
            dependencies: ["BP7"]),
        .target(
            name: "TransportServices",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]),
        .testTarget(
            name: "BP7Tests",
            dependencies: ["BP7"]
        ),
    ]
)
