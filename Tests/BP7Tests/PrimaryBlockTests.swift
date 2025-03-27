import Testing
@testable import BP7

@Suite("Primary Block Tests")
struct PrimaryBlockTests {
    
    @Test("Primary Block Creation")
    func testPrimaryBlockCreation() {
        // Create a primary block using the builder
        let builder = PrimaryBlockBuilder()
            .destination(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")))
            .source(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .reportTo(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")))
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .bundleControlFlags([.bundleMustNotFragmented])
        
        let primaryBlock = try! builder.build()
        
        // Verify the block properties
        #expect(primaryBlock.version == 7)
        #expect(primaryBlock.destination.description == "dtn://destination/")
        #expect(primaryBlock.source.description == "dtn://source/")
        #expect(primaryBlock.reportTo.description == "dtn://report-to/")
        #expect(primaryBlock.creationTimestamp.getDtnTime() == 1000)
        #expect(primaryBlock.creationTimestamp.getSequenceNumber() == 1)
        #expect(primaryBlock.lifetime == 3600)
        #expect(primaryBlock.bundleControlFlags.contains(.bundleMustNotFragmented))
        #expect(!primaryBlock.bundleControlFlags.contains(.bundleIsFragment))
        #expect(primaryBlock.fragmentationOffset == 0)
        #expect(primaryBlock.totalDataLength == 0)
    }
    
    @Test("Primary Block Validation")
    func testPrimaryBlockValidation() {
        // Create a valid primary block
        let validBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        // Validate, should pass
        do {
            try validBlock.validate()
            #expect(Bool(true), "Validation passed as expected")
        } catch {
            #expect(Bool(false), "Validation failed unexpectedly: \(error)")
        }
    }
    
    @Test("Primary Block Fragmentation")
    func testPrimaryBlockFragmentation() {
        // Create a primary block with fragmentation
        let fragmentBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [.bundleIsFragment],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600,
            fragmentationOffset: 100,
            totalDataLength: 1000
        )
        
        #expect(fragmentBlock.hasFragmentation)
        #expect(fragmentBlock.fragmentationOffset == 100)
        #expect(fragmentBlock.totalDataLength == 1000)
    }
    
    @Test("Primary Block Lifetime")
    func testPrimaryBlockLifetime() {
        // Create a primary block with a timestamp in the past
        let pastTime = DisruptionTolerantNetworkingTime.now() - 10000 // 10 seconds ago
        let expiredBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: pastTime, sequenceNumber: 1),
            lifetime: 5 // 5 seconds
        )
        
        // Test that the block is expired
        #expect(expiredBlock.hasExpired())
        
        // Create a primary block with a timestamp in the future
        let futureTime = DisruptionTolerantNetworkingTime.now() + 10000 // 10 seconds in the future
        let unexpiredBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: futureTime, sequenceNumber: 1),
            lifetime: 60
        )
        
        // Test that the block is not expired
        #expect(!unexpiredBlock.hasExpired())
    }
    
    @Test("Primary Block CBOR Serialization")
    func testPrimaryBlockCborSerialization() throws {
        // Create a primary block
        let primaryBlock = try! PrimaryBlockBuilder()
            .destination(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")))
            .source(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .reportTo(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")))
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .bundleControlFlags([.bundleMustNotFragmented])
            .build()
        
        // Serialize to CBOR
        let cbor = primaryBlock.toCbor()
        
        // Deserialize from CBOR
        let deserializedBlock = try PrimaryBlock(from: cbor)
        
        // Check that the deserialized block matches the original
        #expect(deserializedBlock.version == primaryBlock.version)
        #expect(deserializedBlock.bundleControlFlags.rawValue == primaryBlock.bundleControlFlags.rawValue)
        #expect(deserializedBlock.destination.description == primaryBlock.destination.description)
        #expect(deserializedBlock.source.description == primaryBlock.source.description)
        #expect(deserializedBlock.reportTo.description == primaryBlock.reportTo.description)
        #expect(deserializedBlock.creationTimestamp.getDtnTime() == primaryBlock.creationTimestamp.getDtnTime())
        #expect(deserializedBlock.creationTimestamp.getSequenceNumber() == primaryBlock.creationTimestamp.getSequenceNumber())
        #expect(deserializedBlock.lifetime == primaryBlock.lifetime)
    }
    
    @Test("CRC Block Functionality")
    func testCrcBlockFunctionality() {
        // Create a primary block with no CRC
        var primaryBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        // Check that the block has no CRC
        #expect(!primaryBlock.hasCrc())
        #expect(primaryBlock.crcValue() == .crcNo)
        
        // Set the CRC
        primaryBlock.setCrc(.crc16Empty)
        
        // Check that the block now has a CRC
        #expect(primaryBlock.hasCrc())
        #expect(primaryBlock.crcValue() == .crc16Empty)
    }
    
    @Test("Primary Block Builder")
    func testPrimaryBlockBuilder() {
        // Create a primary block using the builder
        let primaryBlock = try! PrimaryBlockBuilder()
            .destination(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")))
            .source(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .reportTo(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")))
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .build()
        
        // Verify the block properties
        #expect(primaryBlock.version == 7)
        #expect(primaryBlock.destination.description == "dtn://destination/")
        #expect(primaryBlock.source.description == "dtn://source/")
        #expect(primaryBlock.reportTo.description == "dtn://report-to/")
        #expect(primaryBlock.creationTimestamp.getDtnTime() == 1000)
        #expect(primaryBlock.creationTimestamp.getSequenceNumber() == 1)
        #expect(primaryBlock.lifetime == 3600)
        #expect(primaryBlock.fragmentationOffset == 0)
        #expect(primaryBlock.totalDataLength == 0)
    }
    
    @Test("Primary Block Builder Validation")
    func testPrimaryBlockBuilderValidation() {
        // Create a builder without setting a destination
        let builder = PrimaryBlockBuilder()
            .source(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .lifetime(3600)
        
        // Attempt to build, should fail
        do {
            _ = try builder.build()
            #expect(Bool(false), "Build should have failed due to missing destination")
        } catch {
            #expect(Bool(true), "Build failed as expected")
        }
    }
    
    @Test("Primary Block Version Validation")
    func testPrimaryBlockVersionValidation() {
        // Create a primary block with an invalid version
        let primaryBlock = PrimaryBlock(
            version: 6, // Invalid version
            bundleControlFlags: [],
            crc: .crcNo,
            destination: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        // Validate, should fail
        do {
            try primaryBlock.validate()
            #expect(Bool(false), "Validation should have failed due to invalid version")
        } catch let error as BP7Error {
            switch error {
            case .invalidValue:
                #expect(Bool(true), "Validation failed with invalid value error as expected")
            default:
                #expect(Bool(false), "Unexpected error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    @Test("Primary Block CBOR Encoding")
    func testPrimaryBlockCborEncoding() {
        // Create a primary block
        let primaryBlock = try! PrimaryBlockBuilder()
            .destination(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")))
            .source(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .reportTo(try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")))
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .bundleControlFlags([.bundleMustNotFragmented])
            .build()
        
        // Convert to CBOR
        let cbor = primaryBlock.toCbor()
        
        // Decode from CBOR
        do {
            let decoded = try PrimaryBlock(from: cbor)
            
            // Check the properties
            #expect(decoded.version == primaryBlock.version)
            #expect(decoded.destination.description == primaryBlock.destination.description)
            #expect(decoded.source.description == primaryBlock.source.description)
            #expect(decoded.reportTo.description == primaryBlock.reportTo.description)
            #expect(decoded.creationTimestamp.getDtnTime() == primaryBlock.creationTimestamp.getDtnTime())
            #expect(decoded.creationTimestamp.getSequenceNumber() == primaryBlock.creationTimestamp.getSequenceNumber())
            #expect(decoded.lifetime == primaryBlock.lifetime)
            #expect(decoded.bundleControlFlags.rawValue == primaryBlock.bundleControlFlags.rawValue)
            #expect(decoded.fragmentationOffset == primaryBlock.fragmentationOffset)
            #expect(decoded.totalDataLength == primaryBlock.totalDataLength)
        } catch {
            #expect(Bool(false), "Decoding primary block failed: \(error)")
        }
    }
}
