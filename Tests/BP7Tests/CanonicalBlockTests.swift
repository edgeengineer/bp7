import Testing
import CBOR
@testable import BP7

@Suite("Canonical Tests")
struct CanonicalTests {
    
    @Test("Canonical Block Creation")
    func testCanonicalBlockCreation() {
        // Test payload block
        do {
            let payload: [UInt8] = [1, 2, 3, 4, 5]
            
            // Create a payload block
            let block = CanonicalBlock(
                blockControlFlags: BlockControlFlags(),
                payloadData: payload
            )
            
            #expect(block.blockType == BlockType.payload.rawValue)
            #expect(block.blockNumber == BlockType.payload.rawValue)
            #expect(block.blockControlFlags == 0)
            #expect(block.crc == .crcNo)
            
            if case .data(let blockData) = block.getData() {
                #expect(blockData == payload)
            } else {
                #expect(Bool(false), "Expected payload data")
            }
        }
        
        // Test hop count block
        do {
            let limit: UInt8 = 10
            
            // Create a hop count block
            var block = CanonicalBlock(
                blockNumber: 2,
                blockControlFlags: BlockControlFlags(),
                hopLimit: limit
            )
            
            #expect(block.blockType == BlockType.hopCount.rawValue)
            #expect(block.blockNumber == 2)
            #expect(block.blockControlFlags == 0)
            #expect(block.crc == .crcNo)
            
            if let (hopLimit, hopCount) = block.getHopCount() {
                #expect(hopLimit == limit)
                #expect(hopCount == 0)
            } else {
                #expect(Bool(false), "Expected hop count data")
            }
            
            // Test incrementing hop count
            let increased = block.increaseHopCount()
            #expect(increased)
            
            if let (hopLimit, hopCount) = block.getHopCount() {
                #expect(hopLimit == limit)
                #expect(hopCount == 1)
            } else {
                #expect(Bool(false), "Expected hop count data after increment")
            }
        }
        
        // Test bundle age block
        do {
            let age: UInt64 = 1000
            
            // Create a bundle age block
            var block = CanonicalBlock(
                blockNumber: 3,
                blockControlFlags: BlockControlFlags(),
                bundleAge: age
            )
            
            #expect(block.blockType == BlockType.bundleAge.rawValue)
            #expect(block.blockNumber == 3)
            #expect(block.blockControlFlags == 0)
            #expect(block.crc == .crcNo)
            
            if let bundleAge = block.getBundleAge() {
                #expect(bundleAge == age)
            } else {
                #expect(Bool(false), "Expected bundle age data")
            }
            
            // Test updating bundle age
            let newAge: UInt64 = 2000
            block.updateBundleAge(newAge)
            
            if let bundleAge = block.getBundleAge() {
                #expect(bundleAge == newAge)
            } else {
                #expect(Bool(false), "Expected updated bundle age data")
            }
        }
        
        // Test previous node block
        do {
            let dtnNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//node1/"))
            
            // Create a previous node block
            let block = CanonicalBlock(
                blockNumber: 4,
                blockControlFlags: BlockControlFlags(),
                previousNode: dtnNode
            )
            
            #expect(block.blockType == BlockType.previousNode.rawValue)
            #expect(block.blockNumber == 4)
            #expect(block.blockControlFlags == 0)
            #expect(block.crc == .crcNo)
            
            if let prevNode = block.getPreviousNode() {
                #expect(prevNode == dtnNode)
            } else {
                #expect(Bool(false), "Expected previous node data")
            }
        }
    }
    
    @Test("Block Validation")
    func testBlockValidation() {
        // Test valid payload block
        // Create a payload block
        let block = CanonicalBlock(
            blockControlFlags: BlockControlFlags(),
            payloadData: [1, 2, 3]
        )
        
        do {
            try block.validate()
        } catch {
            #expect(Bool(false), "Valid block should not throw on validation: \(error)")
        }
        
        // Test invalid block type
        var invalidBlock = CanonicalBlock(
            blockControlFlags: BlockControlFlags(),
            payloadData: [1, 2, 3]
        )
        // Change block type but keep payload data
        invalidBlock = CanonicalBlock(
            blockType: BlockType.hopCount.rawValue,
            blockNumber: invalidBlock.blockNumber,
            blockControlFlags: invalidBlock.blockControlFlags,
            crc: invalidBlock.crc,
            data: invalidBlock.getData()
        )
        
        do {
            try invalidBlock.validate()
            #expect(Bool(false), "Invalid block should throw on validation")
        } catch {
            // Expected to throw
        }
        
        // Test invalid data type
        do {
            let block = CanonicalBlock(
                blockType: BlockType.payload.rawValue,
                blockNumber: 1,
                blockControlFlags: 0,
                crc: .crcNo,
                data: .hopCount(10, 0)
            )
            
            do {
                try block.validate()
                #expect(Bool(false), "Invalid block should throw on validation")
            } catch {
                // Expected to throw
            }
        }
    }
    
    @Test("CBOR Serialization")
    func testCborSerialization() {
        do {
            let payload: [UInt8] = [1, 2, 3, 4, 5]
            
            // Create a payload block
            let block = CanonicalBlock(
                blockControlFlags: BlockControlFlags(),
                payloadData: payload
            )
            
            let cbor = block.toCbor()
            #expect(!cbor.isEmpty)
            
            // Deserialize from CBOR
            let deserializedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify deserialized block
            #expect(deserializedBlock.blockType == BlockType.payload.rawValue)
            #expect(deserializedBlock.blockNumber == 1)
            
            // Check if data matches
            if case .data(let blockData) = deserializedBlock.getData() {
                #expect(blockData == payload)
            } else {
                #expect(Bool(false), "Expected payload data")
            }
        } catch {
            #expect(Bool(false), "CBOR serialization should not throw: \(error)")
        }
    }
    
    @Test("CBOR Deserialization")
    func testCborDeserialization() {
        do {
            // Create a block to serialize
            let payload: [UInt8] = [1, 2, 3, 4, 5]
            let originalBlock = CanonicalBlock(
                blockControlFlags: BlockControlFlags.blockReplicate,
                payloadData: payload
            )
            
            // Serialize to CBOR
            let cbor = originalBlock.toCbor()
            
            // Deserialize from CBOR
            let deserializedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify deserialized block
            #expect(deserializedBlock.blockType == BlockType.payload.rawValue)
            #expect(deserializedBlock.blockNumber == 1)
            #expect(deserializedBlock.blockControlFlags == BlockControlFlags.blockReplicate.rawValue)
            
            // Check if data matches
            if case .data(let blockData) = deserializedBlock.getData() {
                #expect(blockData == payload)
            } else {
                #expect(Bool(false), "Expected payload data")
            }
        } catch {
            #expect(Bool(false), "CBOR deserialization should not throw: \(error)")
        }
        
        // Test hop count block deserialization
        do {
            // Create a hop count block
            let originalBlock = CanonicalBlock(
                blockNumber: 3,
                blockControlFlags: BlockControlFlags.blockDeleteBundle,
                hopLimit: 10
            )
            
            // Serialize to CBOR
            let cbor = originalBlock.toCbor()
            
            // Deserialize from CBOR
            let deserializedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify deserialized block
            #expect(deserializedBlock.blockType == BlockType.hopCount.rawValue)
            #expect(deserializedBlock.blockNumber == 3)
            #expect(deserializedBlock.blockControlFlags == BlockControlFlags.blockDeleteBundle.rawValue)
            
            // Check if data matches
            if let (hopLimit, hopCount) = deserializedBlock.getHopCount() {
                #expect(hopLimit == 10)
                #expect(hopCount == 0)
            } else {
                #expect(Bool(false), "Expected hop count data")
            }
        } catch {
            #expect(Bool(false), "Hop count block deserialization should not throw: \(error)")
        }
        
        // Test bundle age block deserialization
        do {
            // Create a bundle age block
            let originalBlock = CanonicalBlock(
                blockNumber: 2,
                blockControlFlags: BlockControlFlags.blockStatusReport,
                bundleAge: 1000
            )
            
            // Serialize to CBOR
            let cbor = originalBlock.toCbor()
            
            // Deserialize from CBOR
            let deserializedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify deserialized block
            #expect(deserializedBlock.blockType == BlockType.bundleAge.rawValue)
            #expect(deserializedBlock.blockNumber == 2)
            #expect(deserializedBlock.blockControlFlags == BlockControlFlags.blockStatusReport.rawValue)
            
            // Check if data matches
            if let bundleAge = deserializedBlock.getBundleAge() {
                #expect(bundleAge == 1000)
            } else {
                #expect(Bool(false), "Expected bundle age data")
            }
        } catch {
            #expect(Bool(false), "Bundle age block deserialization should not throw: \(error)")
        }
        
        // Test previous node block deserialization
        do {
            // Create a previous node block
            let dtnNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//node1/"))
            let originalBlock = CanonicalBlock(
                blockNumber: 4,
                blockControlFlags: BlockControlFlags.blockReplicate,
                previousNode: dtnNode
            )
            
            // Serialize to CBOR
            let cbor = originalBlock.toCbor()
            
            // Deserialize from CBOR
            let deserializedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify deserialized block
            #expect(deserializedBlock.blockType == BlockType.previousNode.rawValue)
            #expect(deserializedBlock.blockNumber == 4)
            #expect(deserializedBlock.blockControlFlags == BlockControlFlags.blockReplicate.rawValue)
            
            // Check if data matches
            if let prevNode = deserializedBlock.getPreviousNode() {
                #expect(prevNode == dtnNode)
            } else {
                #expect(Bool(false), "Expected previous node data")
            }
        } catch {
            #expect(Bool(false), "Previous node block deserialization should not throw: \(error)")
        }
    }
}
