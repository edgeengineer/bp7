# BP7 - Bundle Protocol Version 7

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20Linux%20|%20Windows%20|%20Android-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=macOS)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Linux](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Linux)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Windows](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Windows)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-blue)](https://edgeengineer.github.io/bp7/documentation/bp7/)

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
- [Documentation](#documentation)
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

## Documentation

Comprehensive documentation is available via DocC:

- [Online Documentation](https://edgeengineer.github.io/bp7/documentation/bp7/)
- Generate locally with: `swift package --allow-writing-to-directory ./docs generate-documentation --target BP7`

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
let sourceEID = try EndpointID(uri: "dtn://node1.dtn/app")
let destinationEID = try EndpointID(uri: "dtn://node2.dtn/app")

// Create a bundle with basic configuration
let bundle = try Bundle(
    source: sourceEID,
    destination: destinationEID,
    creationTimestamp: Date(),
    lifetime: 3600, // 1 hour lifetime
    payload: "Hello, DTN World!".data(using: .utf8)!
)

print("Created bundle with ID:", bundle.bundleID)
```

### 2. Encoding and Decoding Bundles

```swift
import BP7

// Create a bundle
let bundle = try Bundle(
    source: EndpointID(uri: "dtn://sender.dtn/app"),
    destination: EndpointID(uri: "dtn://receiver.dtn/app"),
    creationTimestamp: Date(),
    lifetime: 7200,
    payload: "Bundle payload data".data(using: .utf8)!
)

// Encode the bundle to wire format
do {
    let encoder = BP7Encoder()
    let encodedData = try encoder.encode(bundle)
    print("Encoded bundle size:", encodedData.count, "bytes")
    
    // Decode the bundle from wire format
    let decoder = BP7Decoder()
    let decodedBundle = try decoder.decode(Bundle.self, from: encodedData)
    print("Successfully decoded bundle:", decodedBundle.bundleID)
} catch {
    print("Encoding/Decoding error:", error)
}
```

### 3. Working with Bundle Blocks

```swift
import BP7

// Create a bundle with additional blocks
var bundle = try Bundle(
    source: EndpointID(uri: "dtn://node1.dtn/service"),
    destination: EndpointID(uri: "dtn://node2.dtn/service"),
    creationTimestamp: Date(),
    lifetime: 1800,
    payload: Data()
)

// Add a hop count block
let hopCountBlock = HopCountBlock(hopLimit: 10, hopCount: 0)
try bundle.addBlock(hopCountBlock)

// Add a previous node block
let previousNodeBlock = PreviousNodeBlock(
    nodeID: EndpointID(uri: "dtn://router.dtn/")
)
try bundle.addBlock(previousNodeBlock)

// Add metadata extension block
let metadataBlock = MetadataBlock(metadata: [
    "priority": "high",
    "category": "telemetry"
])
try bundle.addBlock(metadataBlock)

print("Bundle now has", bundle.blocks.count, "total blocks")
```

### 4. Bundle Processing

```swift
import BP7

// Simulate receiving a bundle from the network
let receivedData: Data = // ... bundle data from network
let decoder = BP7Decoder()

do {
    let bundle = try decoder.decode(Bundle.self, from: receivedData)
    
    // Check if bundle is still valid (not expired)
    if bundle.isExpired {
        print("Bundle has expired, discarding")
        return
    }
    
    // Check if this node is the destination
    let localNodeID = EndpointID(uri: "dtn://local.dtn/")
    if bundle.destination.matches(localNodeID) {
        print("Bundle delivered to local node")
        // Process payload
        if let payloadData = bundle.payloadData {
            let payload = String(data: payloadData, encoding: .utf8)
            print("Payload:", payload ?? "Binary data")
        }
    } else {
        print("Bundle needs forwarding to:", bundle.destination)
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
    let bundle = try Bundle(
        source: EndpointID(uri: "invalid://uri"),
        destination: EndpointID(uri: "dtn://valid.dtn/app"),
        creationTimestamp: Date(),
        lifetime: 3600,
        payload: Data()
    )
} catch let error as BP7Error {
    switch error {
    case .invalidEndpointID(let uri):
        print("Invalid endpoint ID: \(uri)")
    case .bundleExpired:
        print("Bundle has expired")
    case .invalidBlockType(let type):
        print("Unsupported block type: \(type)")
    case .encodingError(let description):
        print("Encoding failed: \(description)")
    default:
        print("BP7 error:", error.localizedDescription)
    }
} catch {
    print("Unexpected error:", error)
}
```

### 6. Advanced Bundle Configuration

```swift
import BP7

// Create a bundle with advanced options
var bundle = try Bundle(
    source: EndpointID(uri: "dtn://source.dtn/app"),
    destination: EndpointID(uri: "dtn://dest.dtn/app"),
    reportTo: EndpointID(uri: "dtn://reports.dtn/status"),
    creationTimestamp: Date(),
    sequenceNumber: 12345,
    lifetime: 86400, // 24 hours
    priority: .expedited,
    requestStatusReports: [.reception, .delivery, .deletion],
    fragmentationAllowed: true,
    payload: "Critical mission data".data(using: .utf8)!
)

// Set bundle processing flags
bundle.setFlag(.mustNotFragment, to: false)
bundle.setFlag(.applicationDataUnit, to: true)
bundle.setFlag(.isFragment, to: false)

// Add routing and security blocks as needed
let ageBlock = AgeBlock(ageInMicroseconds: 0)
try bundle.addBlock(ageBlock)

print("Advanced bundle configured with", bundle.blocks.count, "blocks")
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
