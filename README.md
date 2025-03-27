# Bundle Protocol Version 7 (BP7)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20iOS%20tvOS%20watchOS%20visionOS-brightgreen.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://github.com/apache-edge/bp7/actions/workflows/swift.yml/badge.svg)](https://github.com/apache-edge/bp7/actions/workflows/swift.yml)
[![Linux](https://github.com/apache-edge/bp7/actions/workflows/swift.yml/badge.svg)](https://github.com/apache-edge/bp7/actions/workflows/swift.yml)
[![Windows](https://github.com/apache-edge/bp7/actions/workflows/swift.yml/badge.svg)](https://github.com/apache-edge/bp7/actions/workflows/swift.yml)

A cross-platform Swift implementation of Bundle Protocol Version 7 (BPv7) as defined in [RFC 9171](https://www.rfc-editor.org/rfc/rfc9171.txt).

## Overview

Bundle Protocol Version 7 (BPv7) is a network protocol designed for Delay-Tolerant Networking (DTN). DTN enables communication in challenging environments with:

- Intermittent connectivity
- Long or variable delays
- High bit error rates
- Asymmetric data rates

This Swift package provides a native implementation of BPv7 for Apple platforms, allowing applications to create, process, and manage DTN bundles.

## Key Features

- **Store-Carry-Forward Overlay Network**: Enables data transmission even when end-to-end connectivity is not available
- **Late Binding**: Overlay-network endpoint identifiers to underlying network addresses
- **Scheduled and Opportunistic Connectivity**: Takes advantage of both planned and unplanned connection opportunities
- **Cross-Platform Support**: Works on macOS, iOS, and tvOS
- **Swift 6 Native**: Built with the latest Swift language features

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/apache-edge/bp7.git", from: "0.0.1")
```

Then include "BP7" as a dependency in your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["BP7"]
),
```

## Usage

### Basic Example

```swift
import BP7

// Create endpoint identifiers
let sourceEID = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source-node/"))
let destinationEID = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination-node/"))

// Create a primary block
let primaryBlock = try! PrimaryBlockBuilder()
    .version(7)
    .bundleControlFlags([])
    .crc(.crc32)
    .destination(destinationEID)
    .source(sourceEID)
    .reportTo(sourceEID) // Report back to source
    .creationTimestamp(CreationTimestamp(time: DtnTime.currentTime(), sequenceNumber: 1))
    .lifetime(3600) // 1 hour lifetime
    .build()

// Create a payload block with data
let message = "Hello, DTN!"
let payloadData: [UInt8] = Array(message.utf8)
let payloadBlock = try! CanonicalBlock.newPayloadBlock(
    blockControlFlags: [],
    data: payloadData
)

// Create the bundle
let bundle = Bundle(
    primary: primaryBlock,
    canonicals: [payloadBlock]
)

// Serialize the bundle to CBOR for transmission
let serializedBundle = try! bundle.toCbor()

// When receiving a bundle, deserialize it from CBOR
let receivedBundle = try! Bundle.fromCbor(serializedBundle)

// Access the payload
if let payload = receivedBundle.payload(),
   let receivedMessage = String(bytes: payload, encoding: .utf8) {
    print("Received message: \(receivedMessage)")
}
```

## Bundle Protocol Concepts

### Endpoints and EIDs

Bundles are addressed to endpoints identified by Endpoint Identifiers (EIDs). BPv7 supports two URI schemes:

1. **dtn scheme**: `dtn://node-name/~service-name`
2. **ipn scheme**: `ipn:node-number.service-number`

### Bundle Structure

A bundle consists of:

- **Primary Block**: Contains routing information (source, destination, etc.)
- **Payload Block**: Contains the application data
- **Extension Blocks**: Optional blocks for additional functionality (Previous Node, Bundle Age, Hop Count, etc.)

### Creating Bundles

BP7 provides a builder pattern for creating bundles. Here's an example of how to create a bundle:

```swift
import BP7

// Create endpoint identifiers
let sourceEID = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source-node/"))
let destinationEID = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination-node/"))
let reportToEID = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to-node/"))

// Create a primary block using PrimaryBlockBuilder
let primaryBlock = try! PrimaryBlockBuilder()
    .version(7)
    .bundleControlFlags([.bundleRequestStatusTime])
    .crc(.crc32)
    .destination(destinationEID)
    .source(sourceEID)
    .reportTo(reportToEID)
    .creationTimestamp(CreationTimestamp(time: DtnTime.currentTime(), sequenceNumber: 1))
    .lifetime(3600) // 1 hour lifetime
    .build()

// Create a payload block with data
let payloadData: [UInt8] = Array("Hello, Bundle Protocol 7!".utf8)
let payloadBlock = try! CanonicalBlock.newPayloadBlock(
    blockControlFlags: [],
    data: payloadData
)

// Create a hop count block (optional extension block)
let hopCountBlock = try! CanonicalBlock.newHopCountBlock(
    blockNumber: 2,
    blockControlFlags: [],
    limit: 10
)

// Create the bundle using BundleBuilder
let bundle = try! BundleBuilder(primary: primaryBlock)
    .addCanonical(payloadBlock)
    .addCanonical(hopCountBlock)
    .build()

// Alternatively, you can create a bundle directly
let simpleBundle = Bundle(
    primary: primaryBlock,
    canonicals: [payloadBlock, hopCountBlock]
)

// Access the payload
if let payload = bundle.payload(), 
   let message = String(bytes: payload, encoding: .utf8) {
    print("Bundle payload: \(message)")
}
```

### Bundle Processing

The protocol handles:

- Bundle creation and transmission
- Forwarding and routing
- Reception and delivery
- Fragmentation and reassembly
- Administrative records (status reports)

## Dependencies

- [CBOR](https://github.com/apache-edge/cbor.git) - Concise Binary Object Representation for efficient binary encoding

## Security

Bundle Protocol Security (BPSec) as specified in [RFC 9172](https://www.rfc-editor.org/info/rfc9172) provides security services for the Bundle Protocol. This implementation now includes:

- **Integrity Block (BIB)**: Implements the Bundle Authentication Block (BAB) as defined in [RFC 9172](https://www.rfc-editor.org/info/rfc9172)
- **BIB-HMAC-SHA2 Security Context**: Implements the integrity mechanism as defined in [RFC 9173](https://www.rfc-editor.org/info/rfc9173)
- **Integrity Protected Plaintext (IPPT)**: Supports integrity protection for primary blocks, payload blocks, and security headers
- **Flexible Security Parameters**: Configurable SHA variants (SHA-256, SHA-384, SHA-512) and integrity scope flags

The security implementation allows bundles to be protected against unauthorized modification during transit through untrusted networks.

Example usage:

```swift
// Create security parameters with SHA-384
let securityParams = BibSecurityContextParameter(
    shaVariant: ShaVariantParameter(id: 1, variant: HMAC_SHA_384),
    wrappedKey: nil,
    integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: IntegrityScopeFlags.all.rawValue)
)

// Create an integrity block to protect a payload block
let integrityBlock = try IntegrityBlockBuilder()
    .securityTargets([1]) // Target the payload block (block number 1)
    .securityContextFlags(SEC_CONTEXT_PRESENT)
    .securitySource(myNodeEndpoint)
    .securityContextParameters(securityParams)
    .build()

// Compute HMAC for the target block
try integrityBlock.computeHmac(keyBytes: sharedSecretKey, ipptList: [(1, ipptData)])
```

## References

- [RFC 9171: Bundle Protocol Version 7](https://www.rfc-editor.org/rfc/rfc9171.txt)
- [RFC 9172: Bundle Protocol Security (BPSec)](https://www.rfc-editor.org/info/rfc9172)
- [RFC 9173: Bundle Protocol Security (BPSec) - BIB-HMAC-SHA2](https://www.rfc-editor.org/info/rfc9173)
- [RFC 4838: Delay-Tolerant Networking Architecture](https://www.rfc-editor.org/info/rfc4838)

## License

This project is licensed under the Apache License, Version 2.0 - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
