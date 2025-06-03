# Bundle Protocol Version 7 (BP7)

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20iOS%20tvOS%20watchOS%20visionOS%20Linux%20Windows-brightgreen.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=macOS)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Linux](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Linux)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)
[![Windows](https://img.shields.io/github/actions/workflow/status/edgeengineer/bp7/swift.yml?branch=main&label=Windows)](https://github.com/edgeengineer/bp7/actions/workflows/swift.yml)

A cross-platform Swift 6 implementation of Bundle Protocol Version 7 (BPv7) as defined in [RFC 9171](https://www.rfc-editor.org/rfc/rfc9171.txt).

## Overview

Bundle Protocol Version 7 (BPv7) is a network protocol designed for Disruption Tolerant Networking (DTN). DTN enables communication in challenging environments with:

- Intermittent connectivity
- Long or variable delays
- High bit error rates
- Asymmetric data rates

This Swift package provides a native implementation of BPv7 for Apple platforms (macOS, iOS, tvOS, watchOS, visionOS), Linux, and Windows, allowing applications to create, process, and manage DTN bundles across all major operating systems.

## Key Features

- **Store-Carry-Forward Overlay Network**: Enables data transmission even when end-to-end connectivity is not available
- **Late Binding**: Overlay-network endpoint identifiers to underlying network addresses
- **Scheduled and Opportunistic Connectivity**: Takes advantage of both planned and unplanned connection opportunities
- **Cross-Platform Support**: Works on macOS, iOS, tvOS, watchOS, visionOS, Linux, and Windows
- **Swift 6 Native**: Built with the latest Swift language features
- **Swift Concurrency Support**: Built with the latest Swift concurrency features
- **Comprehensive Security**: Supports Bundle Protocol Security (BPSec) as defined in RFC 9172
- **Extensible Architecture**: Easily add custom block types and processing rules

## Architecture

BP7 implements the Bundle Protocol architecture as defined in RFC 9171, consisting of:

### Core Components

- **Bundle**: The primary data unit in DTN, containing a payload and metadata
- **Primary Block**: Contains essential routing and identification information
- **Canonical Blocks**: Extension blocks for additional capabilities
- **Endpoint IDs**: Identifiers for source and destination endpoints
- **Creation Timestamps**: Uniquely identifies bundles from the same source

### Security Features

- **Bundle Authentication Block (BAB)**: Provides hop-by-hop authentication
- **Block Integrity Block (BIB)**: Ensures integrity of specific blocks
- **Block Confidentiality Block (BCB)**: Encrypts block contents
- **Security Context Parameters**: Configurable security options

### Cross-Platform Implementation

The codebase uses conditional compilation to ensure compatibility across platforms:
- Platform-specific imports for system libraries
- Custom implementations for platform-specific features
- Consistent API regardless of the underlying platform

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/edgeengineer/bp7.git", from: "0.0.4")
```

Then include "BP7" as a dependency in your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["BP7"]
),
```

## Usage

### Creating and Sending a Bundle

```swift
import BP7

// Create source and destination endpoints
let source = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source-node/"))
let destination = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination-node/"))

// Create bundle with payload
let payload = "Hello, DTN World!".data(using: .utf8)!
var bundle = try Bundle(
    source: source,
    destination: destination,
    payloadBlock: PayloadBlock(payload: payload)
)

// Add a lifetime
bundle.primaryBlock.lifetime = 86400 // 24 hours in seconds

// Serialize the bundle to binary format (CBOR)
let serializedBundle = try bundle.serialize()

// Send the bundle through your DTN transport layer
// dtnTransport.send(serializedBundle)
```

### Receiving and Processing a Bundle

```swift
import BP7

// Assuming you have received serialized bundle data
// let receivedData = dtnTransport.receive()

// Deserialize the bundle
let receivedBundle = try Bundle.deserialize(from: receivedData)

// Access bundle information
let sourceID = receivedBundle.primaryBlock.sourceID
let destinationID = receivedBundle.primaryBlock.destinationID
let creationTime = receivedBundle.primaryBlock.creationTimestamp

// Process the payload
if let payloadBlock = receivedBundle.getBlockOfType(BlockType.PAYLOAD) as? PayloadBlock,
   let payloadString = String(data: payloadBlock.payload, encoding: .utf8) {
    print("Received message: \(payloadString)")
}
```

### Working with Security Blocks

```swift
import BP7
import Crypto

// Create a bundle with integrity protection
let source = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//secure-source/"))
let destination = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//secure-destination/"))

// Create bundle with payload
let payload = "Secure DTN message".data(using: .utf8)!
var bundle = try Bundle(
    source: source,
    destination: destination,
    payloadBlock: PayloadBlock(payload: payload)
)

// Add integrity protection to the payload block
let securityTargets: [UInt64] = [1] // Target the payload block
let securitySource = source
let securityParams = BibSecurityContextParameter(
    securityContext: SecurityContext.SHA256,
    securitySource: securitySource
)

// Create and add the Block Integrity Block
let bib = try BlockIntegrityBlock(
    securityTargets: securityTargets,
    securityContextParameters: securityParams
)
try bundle.addBlock(bib)

// Serialize the bundle
let serializedBundle = try bundle.serialize()
```

## Advanced Features

### Custom Block Types

You can extend BP7 with custom block types by implementing the `CanonicalBlock` protocol:

```swift
import BP7

public final class MyCustomBlock: CanonicalBlock {
    public static let blockType: UInt64 = 194 // Choose a number in the private range
    
    // Your custom properties
    public var customData: Data
    
    // Implementation of required methods
    // ...
}
```

### Fragmentation and Reassembly

BP7 supports bundle fragmentation for large payloads:

```swift
import BP7

// Fragment a large bundle
let fragments = try bundle.fragment(maxFragmentSize: 1024)

// Reassemble fragments
let reassembledBundle = try Bundle.reassemble(fragments: receivedFragments)
```

## Contributing

Contributions to BP7 are welcome! Here's how you can help:

1. **Report Issues**: File bugs or feature requests on the GitHub issue tracker
2. **Submit Pull Requests**: Implement new features or fix bugs
3. **Improve Documentation**: Help make the documentation more comprehensive
4. **Cross-Platform Testing**: Test the library on different platforms

Please ensure your code follows the Swift style guidelines and includes appropriate tests.

## License

This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The Bundle Protocol specification (RFC 9171)
- The Bundle Security Protocol specification (RFC 9172)
- The Apache Edge community
- Largely based on the [https://github.com/dtn7/bp7-rs](https://github.com/dtn7/bp7-rs) Rust implementation 