# BP7 - Bundle Protocol Version 7

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20Linux%20|%20Windows%20|%20Android-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=macOS)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Linux](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Linux)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Windows](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Windows)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)

BP7 is a lightweight implementation of the [Bundle Protocol Version 7](https://tools.ietf.org/rfc/rfc9171.txt) in Swift. Bundle Protocol Version 7 (BP7) is defined in RFC 9171 and provides a store-and-forward overlay network protocol for delay-tolerant networking (DTN). This implementation allows you to create, encode, decode, and manipulate BP7 bundles with full support for the protocol specification.

## Features

- **Complete BP7 Implementation:**  
  Full support for Bundle Protocol Version 7 as specified in RFC 9171, including primary blocks, canonical blocks, and all standard block types.

- **Memory-Optimized for Embedded Swift:**  
  Uses efficient memory management techniques optimized for resource-constrained environments, avoiding unnecessary heap allocations where possible.

- **Bundle Creation & Processing:**  
  Create bundles with source/destination endpoints, set bundle flags, add payload and extension blocks, and process received bundles.

- **Full Codable Support:**  
  Use `BP7Encoder` and `BP7Decoder` for complete support of Swift's `Codable` protocol with BP7 bundles and blocks.

- **CBOR Integration:**  
  Built on top of efficient CBOR encoding/decoding for wire format compatibility and interoperability.

- **Routing & Forwarding:**  
  Support for bundle routing decisions, custody transfer, and store-and-forward operations essential for DTN networks.

- **Error Handling:**  
  Comprehensive error types to help diagnose bundle processing issues and protocol violations.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
  - [Creating a Simple Bundle](#1-creating-a-simple-bundle)
  - [Encoding and Decoding Bundles](#2-encoding-and-decoding-bundles)
  - [Working with Bundle Blocks](#3-working-with-bundle-blocks)
  - [Bundle Processing](#4-bundle-processing)
  - [Error Handling](#5-error-handling)
  - [Advanced Bundle Configuration](#6-advanced-bundle-configuration)
- [Bundle Protocol Concepts](#bundle-protocol-concepts)
- [License](#license)

For more information about the Bundle Protocol specification, see [RFC 9171](https://tools.ietf.org/rfc/rfc9171.txt).

## Installation

### Swift Package Manager

Add the BP7 package to your Swift package dependencies:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(url: "https://github.com/edgeengineer/bp7", from: "0.0.8")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "BP7", package: "bp7")
            ]
        )
    ]
)
```

## Quick Start 

### 1. Creating a Simple Bundle

```swift
import BP7

// Create endpoint identifiers
let sourceEID = try EndpointID.from("dtn://node1.dtn/app")
let destinationEID = try EndpointID.from("dtn://node2.dtn/app")

// Create a primary block using the builder
let primaryBlock = PrimaryBlockBuilder(destination: destinationEID)
    .source(sourceEID)
    .reportTo(EndpointID.none())
    .creationTimestamp(CreationTimestamp.now())
    .lifetime(3600.0) // 1 hour lifetime
    .bundleControlFlags([.bundleMustNotFragmented])
    .build()

// Create a payload block
let payloadData = "Hello, DTN World!".data(using: .utf8)!
let payloadBlock = CanonicalBlock(
    blockControlFlags: [],
    payloadData: Array(payloadData)
)

// Create the complete bundle
let bundle = Bundle(primary: primaryBlock, canonicals: [payloadBlock])

print("Created bundle from:", bundle.primary.source)
print("Created bundle to:", bundle.primary.destination)
```

### 2. Encoding and Decoding Bundles

```swift
import BP7

// Create endpoint identifiers
let source = try EndpointID.from("dtn://sender.dtn/app")
let destination = try EndpointID.from("dtn://receiver.dtn/app")

// Create a primary block
let primary = PrimaryBlockBuilder(destination: destination)
    .source(source)
    .creationTimestamp(CreationTimestamp.now())
    .lifetime(7200.0)
    .build()

// Create payload block
let payloadData = "Bundle payload data".data(using: .utf8)!
let payloadBlock = CanonicalBlock(
    blockControlFlags: [],
    payloadData: Array(payloadData)
)

// Create bundle
let bundle = Bundle(primary: primary, canonicals: [payloadBlock])

// Encode the bundle to wire format
do {
    let encodedData = bundle.encode()
    print("Encoded bundle size:", encodedData.count, "bytes")
    
    // Decode the bundle from wire format
    let decodedBundle = try Bundle.decode(from: encodedData)
    print("Successfully decoded bundle from:", decodedBundle.primary.source)
    print("Successfully decoded bundle to:", decodedBundle.primary.destination)
} catch {
    print("Encoding/Decoding error:", error)
}
```

### 3. Working with Bundle Blocks

```swift
import BP7

// Create endpoints
let source = try EndpointID.from("dtn://node1.dtn/service")
let destination = try EndpointID.from("dtn://node2.dtn/service")

// Create primary block
let primary = PrimaryBlockBuilder(destination: destination)
    .source(source)
    .creationTimestamp(CreationTimestamp.now())
    .lifetime(1800.0)
    .build()

// Create payload block
let payloadBlock = CanonicalBlock(
    blockControlFlags: [],
    payloadData: []
)

// Create a hop count block
let hopCountBlock = CanonicalBlock(
    blockNumber: 2,
    blockControlFlags: [],
    hopLimit: 10
)

// Create a previous node block
let routerEID = try EndpointID.from("dtn://router.dtn/")
let previousNodeBlock = CanonicalBlock(
    blockNumber: 3,
    blockControlFlags: [],
    previousNode: routerEID
)

// Create a bundle age block
let bundleAgeBlock = CanonicalBlock(
    blockNumber: 4,
    blockControlFlags: [],
    bundleAge: 0
)

// Create the bundle with all blocks
var bundle = Bundle(primary: primary, canonicals: [
    payloadBlock,
    hopCountBlock,
    previousNodeBlock,
    bundleAgeBlock
])

print("Bundle now has", bundle.canonicals.count, "canonical blocks")
```

### 4. Bundle Processing

```swift
import BP7

// Simulate receiving bundle data from the network
let receivedData: [UInt8] = // ... bundle data from network

do {
    let bundle = try Bundle.decode(from: receivedData)
    
    // Check if bundle has expired
    if bundle.primary.hasExpired() {
        print("Bundle has expired, discarding")
        return
    }
    
    // Check if this node is the destination
    let localNodeID = try EndpointID.from("dtn://local.dtn/")
    if bundle.primary.destination.description.contains("local.dtn") {
        print("Bundle delivered to local node")
        
        // Process payload
        if let payloadData = bundle.payload() {
            let payload = String(bytes: payloadData, encoding: .utf8)
            print("Payload:", payload ?? "Binary data")
        }
    } else {
        print("Bundle needs forwarding to:", bundle.primary.destination)
        // Implement routing logic here
    }
    
} catch {
    print("Bundle processing error:", error)
}
```

### 5. Error Handling

```swift
import BP7

do {
    let invalidEID = try EndpointID.from("invalid://uri")
    let validEID = try EndpointID.from("dtn://valid.dtn/app")
    
    let primary = PrimaryBlockBuilder(destination: validEID)
        .source(invalidEID)
        .build()
        
} catch let error as BP7Error {
    switch error {
    case .endpointID(let eidError):
        print("EndpointID error:", eidError)
    case .invalidBundle:
        print("Invalid bundle")
    case .invalidBlock:
        print("Invalid block")
    case .invalidValue:
        print("Invalid value")
    default:
        print("BP7 error:", error.description)
    }
} catch {
    print("Unexpected error:", error)
}
```

### 6. Advanced Bundle Configuration

```swift
import BP7

// Create endpoints
let source = try EndpointID.from("dtn://source.dtn/app")
let destination = try EndpointID.from("dtn://dest.dtn/app")
let reportTo = try EndpointID.from("dtn://reports.dtn/status")

// Create a primary block with advanced options
let primary = PrimaryBlockBuilder(destination: destination)
    .source(source)
    .reportTo(reportTo)
    .creationTimestamp(CreationTimestamp(time: DisruptionTolerantNetworkingTime.now(), sequenceNumber: 12345))
    .lifetime(86400.0) // 24 hours
    .bundleControlFlags([
        .bundleStatusRequestReception,
        .bundleStatusRequestDelivery,
        .bundleRequestStatusTime
    ])
    .build()

// Create payload with critical data
let criticalData = "Critical mission data".data(using: .utf8)!
let payloadBlock = CanonicalBlock(
    blockControlFlags: [.blockReplicate], // Replicate in fragments
    payloadData: Array(criticalData)
)

// Create a bundle age block to track age
let ageBlock = CanonicalBlock(
    blockNumber: 7, // Bundle Age block type
    blockControlFlags: [],
    bundleAge: 0
)

// Create the bundle with CRC protection
var bundle = Bundle(primary: primary, canonicals: [payloadBlock, ageBlock])
bundle.setCrc(.crc32Empty) // Add CRC-32 protection to all blocks

print("Advanced bundle configured with", bundle.canonicals.count, "canonical blocks")
print("Bundle has CRC protection:", bundle.primary.hasCrc())
```

## Bundle Protocol Concepts

The Bundle Protocol Version 7 (BP7) is designed for delay-tolerant networking (DTN) where end-to-end connectivity cannot be assumed. Key concepts include:

- **Bundles**: The fundamental data unit in BP7, containing a primary block and zero or more canonical blocks
- **Endpoint IDs**: Identify sources, destinations, and report-to nodes using URI schemes
- **Store-and-Forward**: Bundles are stored at intermediate nodes when forwarding paths are not immediately available
- **Custody Transfer**: Optional mechanism for reliable delivery with hop-by-hop acknowledgments
- **Fragmentation**: Large bundles can be fragmented for transmission over constrained links
- **Routing**: Flexible routing schemes accommodate various network topologies and mobility patterns

For complete details, refer to [RFC 9171 - Bundle Protocol Version 7](https://tools.ietf.org/rfc/rfc9171.txt).

## Platform Compatibility

This BP7 library is designed to work across all Swift-supported platforms:

- **Apple platforms** (macOS, iOS, tvOS, watchOS, visionOS): Full feature support
- **Linux**: Full feature support  
- **Windows**: Full feature support
- **Android**: Cross-platform compatibility maintained

The library is optimized for both resource-rich and resource-constrained environments, making it suitable for everything from mobile devices to embedded systems participating in DTN networks.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
