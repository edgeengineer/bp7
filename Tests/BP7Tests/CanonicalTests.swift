import Testing
import CBOR
@testable import BP7

@Suite("Canonical Tests")
struct CanonicalTests {
    
    @Test("Canonical Block Creation")
    func testCanonicalBlockCreation() {
        // Test creating a basic canonical block
        let block = CanonicalBlock.new()
        #expect(block.blockType == PAYLOAD_BLOCK)
        #expect(block.blockNumber == 0)
        #expect(block.blockControlFlags == 0)
        #expect(block.crc == .crcNo)
        
        if case .data(let data) = block.getData() {
            #expect(data.isEmpty)
        } else {
            #expect(Bool(false), "Expected data type")
        }
    }
    
    @Test("Canonical Block Builder")
    func testCanonicalBlockBuilder() {
        // Test the builder pattern
        do {
            let block = try CanonicalBlockBuilder()
                .blockType(PAYLOAD_BLOCK)
                .blockNumber(1)
                .blockControlFlags(0x01)
                .data(.data([1, 2, 3, 4]))
                .build()
            
            #expect(block.blockType == PAYLOAD_BLOCK)
            #expect(block.blockNumber == 1)
            #expect(block.blockControlFlags == 0x01)
            
            if case .data(let data) = block.getData() {
                #expect(data == [1, 2, 3, 4])
            } else {
                #expect(Bool(false), "Expected data type")
            }
        } catch {
            #expect(Bool(false), "Block builder should not throw: \(error)")
        }
        
        // Test missing data error
        do {
            let _ = try CanonicalBlockBuilder()
                .blockType(PAYLOAD_BLOCK)
                .blockNumber(1)
                .blockControlFlags(0x01)
                .build()
            
            #expect(Bool(false), "Should throw missing data error")
        } catch CanonicalError.missingData {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Expected missing data error, got: \(error)")
        }
    }
    
    @Test("Payload Block")
    func testPayloadBlock() {
        do {
            let payload: [UInt8] = [1, 2, 3, 4, 5]
            let block = try newPayloadBlock(blockControlFlags: [], data: payload)
            
            #expect(block.blockType == PAYLOAD_BLOCK)
            #expect(block.blockNumber == PAYLOAD_BLOCK_NUMBER)
            #expect(block.blockControlFlags == 0)
            
            if let data = block.payloadData() {
                #expect(data == payload)
            } else {
                #expect(Bool(false), "Expected payload data")
            }
            
            // Validate the block
            do {
                try block.validate()
                #expect(Bool(true))
            } catch {
                #expect(Bool(false), "Valid payload block should not throw: \(error)")
            }
        } catch {
            #expect(Bool(false), "Creating payload block should not throw: \(error)")
        }
    }
    
    @Test("Hop Count Block")
    func testHopCountBlock() {
        do {
            let limit: UInt8 = 10
            var block = try newHopCountBlock(blockNumber: 2, blockControlFlags: [], limit: limit)
            
            #expect(block.blockType == HOP_COUNT_BLOCK)
            #expect(block.blockNumber == 2)
            
            if let (hopLimit, hopCount) = block.getHopCount() {
                #expect(hopLimit == limit)
                #expect(hopCount == 0)
            } else {
                #expect(Bool(false), "Expected hop count data")
            }
            
            // Test increasing hop count
            let increased = block.increaseHopCount()
            #expect(increased)
            
            if let (hopLimit, hopCount) = block.getHopCount() {
                #expect(hopLimit == limit)
                #expect(hopCount == 1)
            } else {
                #expect(Bool(false), "Expected hop count data after increase")
            }
            
            // Test hop count exceeded
            #expect(!block.isHopCountExceeded())
            
            // Manually set to exceeded
            block.setData(.hopCount(limit, limit + 1))
            #expect(block.isHopCountExceeded())
        } catch {
            #expect(Bool(false), "Creating hop count block should not throw: \(error)")
        }
    }
    
    @Test("Bundle Age Block")
    func testBundleAgeBlock() {
        do {
            let age: UInt64 = 1000
            var block = try newBundleAgeBlock(blockNumber: 3, blockControlFlags: [], timeInMillis: age)
            
            #expect(block.blockType == BUNDLE_AGE_BLOCK)
            #expect(block.blockNumber == 3)
            
            if let bundleAge = block.getBundleAge() {
                #expect(bundleAge == age)
            } else {
                #expect(Bool(false), "Expected bundle age data")
            }
            
            // Test updating bundle age
            let newAge: UInt64 = 2000
            let updated = block.updateBundleAge(newAge)
            #expect(updated)
            
            if let bundleAge = block.getBundleAge() {
                #expect(bundleAge == newAge)
            } else {
                #expect(Bool(false), "Expected bundle age data after update")
            }
        } catch {
            #expect(Bool(false), "Creating bundle age block should not throw: \(error)")
        }
    }
    
    @Test("Previous Node Block")
    func testPreviousNodeBlock() {
        do {
            let dtnNode = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//node1/"))
            var block = try newPreviousNodeBlock(blockNumber: 4, blockControlFlags: [], previousNode: dtnNode)
            
            #expect(block.blockType == PREVIOUS_NODE_BLOCK)
            #expect(block.blockNumber == 4)
            
            if let prevNode = block.getPreviousNode() {
                #expect(prevNode == dtnNode)
            } else {
                #expect(Bool(false), "Expected previous node data")
            }
            
            // Test updating previous node
            let newNode = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//node2/"))
            let updated = block.updatePreviousNode(newNode)
            #expect(updated)
            
            if let prevNode = block.getPreviousNode() {
                #expect(prevNode == newNode)
            } else {
                #expect(Bool(false), "Expected previous node data after update")
            }
        } catch {
            #expect(Bool(false), "Creating previous node block should not throw: \(error)")
        }
    }
    
    @Test("Block Validation")
    func testBlockValidation() {
        // Test valid payload block
        do {
            let block = try newPayloadBlock(blockControlFlags: [], data: [1, 2, 3])
            
            do {
                try block.validate()
                #expect(Bool(true))
            } catch {
                #expect(Bool(false), "Valid payload block should not throw: \(error)")
            }
        } catch {
            #expect(Bool(false), "Creating payload block should not throw: \(error)")
        }
        
        // Test invalid block type
        do {
            var block = try newPayloadBlock(blockControlFlags: [], data: [1, 2, 3])
            // Change block type but keep payload data
            block = CanonicalBlock(
                blockType: HOP_COUNT_BLOCK,
                blockNumber: block.blockNumber,
                blockControlFlags: block.blockControlFlags,
                crc: block.crc,
                data: block.getData()
            )
            
            do {
                try block.validate()
                #expect(Bool(false), "Invalid block should throw")
            } catch CanonicalError.canonicalBlockError(_) {
                #expect(Bool(true))
            } catch {
                #expect(Bool(false), "Expected canonical block error, got: \(error)")
            }
        } catch {
            #expect(Bool(false), "Creating payload block should not throw: \(error)")
        }
        
        // Test invalid block number for payload
        do {
            let block = CanonicalBlock(
                blockType: PAYLOAD_BLOCK,
                blockNumber: 2, // Should be 1 for payload
                blockControlFlags: 0,
                crc: .crcNo,
                data: .data([1, 2, 3])
            )
            
            do {
                try block.validate()
                #expect(Bool(false), "Invalid block number should throw")
            } catch CanonicalError.canonicalBlockError(_) {
                #expect(Bool(true))
            } catch {
                #expect(Bool(false), "Expected canonical block error, got: \(error)")
            }
        } catch {
            #expect(Bool(false), "Creating block should not throw: \(error)")
        }
    }
    
    @Test("CBOR Serialization")
    func testCborSerialization() {
        do {
            let payload: [UInt8] = [1, 2, 3, 4, 5]
            let block = try newPayloadBlock(blockControlFlags: [], data: payload)
            
            let cbor = try block.toCbor()
            #expect(!cbor.isEmpty)
            
            // Basic verification of CBOR structure
            let decoded = try CBOR.decode(cbor)
            if case .array(let items) = decoded, items.count >= 5 {
                if case .unsignedInt(let blockType) = items[0] {
                    #expect(blockType == PAYLOAD_BLOCK)
                } else {
                    #expect(Bool(false), "Expected unsigned int for block type")
                }
                
                if case .unsignedInt(let blockNumber) = items[1] {
                    #expect(blockNumber == PAYLOAD_BLOCK_NUMBER)
                } else {
                    #expect(Bool(false), "Expected unsigned int for block number")
                }
                
                if case .unsignedInt(let flags) = items[2] {
                    #expect(flags == 0)
                } else {
                    #expect(Bool(false), "Expected unsigned int for flags")
                }
                
                if case .unsignedInt(let crcType) = items[3] {
                    #expect(crcType == 0) // CRC_NO
                } else {
                    #expect(Bool(false), "Expected unsigned int for CRC type")
                }
                
                if case .byteString(let data) = items[4] {
                    #expect(data == payload)
                } else {
                    #expect(Bool(false), "Expected byte string for payload data")
                }
            } else {
                #expect(Bool(false), "Expected array with at least 5 items")
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
            let originalBlock = try newPayloadBlock(blockControlFlags: [.blockReplicate], data: payload)
            
            // Serialize to CBOR
            let cbor = try originalBlock.toCbor()
            
            // Deserialize from CBOR
            let decodedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify the decoded block matches the original
            #expect(decodedBlock.blockType == originalBlock.blockType)
            #expect(decodedBlock.blockNumber == originalBlock.blockNumber)
            #expect(decodedBlock.blockControlFlags == originalBlock.blockControlFlags)
            #expect(decodedBlock.crc == originalBlock.crc)
            
            if case .data(let decodedData) = decodedBlock.getData(),
               case .data(let originalData) = originalBlock.getData() {
                #expect(decodedData == originalData)
            } else {
                #expect(Bool(false), "Data types don't match")
            }
        } catch {
            #expect(Bool(false), "CBOR round-trip should not throw: \(error)")
        }
        
        // Test hop count block
        do {
            let limit: UInt8 = 10
            let originalBlock = try newHopCountBlock(blockNumber: 2, blockControlFlags: [.blockReplicate], limit: limit)
            
            // Serialize to CBOR
            let cbor = try originalBlock.toCbor()
            
            // Deserialize from CBOR
            let decodedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify the decoded block matches the original
            #expect(decodedBlock.blockType == originalBlock.blockType)
            #expect(decodedBlock.blockNumber == originalBlock.blockNumber)
            #expect(decodedBlock.blockControlFlags == originalBlock.blockControlFlags)
            
            if let (decodedLimit, decodedCount) = decodedBlock.getHopCount(),
               let (originalLimit, originalCount) = originalBlock.getHopCount() {
                #expect(decodedLimit == originalLimit)
                #expect(decodedCount == originalCount)
            } else {
                #expect(Bool(false), "Failed to get hop count data")
            }
        } catch {
            #expect(Bool(false), "Hop count block round-trip should not throw: \(error)")
        }
        
        // Test bundle age block
        do {
            let age: UInt64 = 1000
            let originalBlock = try newBundleAgeBlock(blockNumber: 3, blockControlFlags: [.blockReplicate], timeInMillis: age)
            
            // Serialize to CBOR
            let cbor = try originalBlock.toCbor()
            
            // Deserialize from CBOR
            let decodedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify the decoded block matches the original
            #expect(decodedBlock.blockType == originalBlock.blockType)
            #expect(decodedBlock.blockNumber == originalBlock.blockNumber)
            #expect(decodedBlock.blockControlFlags == originalBlock.blockControlFlags)
            
            if let decodedAge = decodedBlock.getBundleAge(),
               let originalAge = originalBlock.getBundleAge() {
                #expect(decodedAge == originalAge)
            } else {
                #expect(Bool(false), "Failed to get bundle age data")
            }
        } catch {
            #expect(Bool(false), "Bundle age block round-trip should not throw: \(error)")
        }
        
        // Test previous node block
        do {
            let dtnNode = try EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//node1/"))
            let originalBlock = try newPreviousNodeBlock(blockNumber: 4, blockControlFlags: [.blockReplicate], previousNode: dtnNode)
            
            // Serialize to CBOR
            let cbor = try originalBlock.toCbor()
            
            // Deserialize from CBOR
            let decodedBlock = try CanonicalBlock.fromCbor(cbor)
            
            // Verify the decoded block matches the original
            #expect(decodedBlock.blockType == originalBlock.blockType)
            #expect(decodedBlock.blockNumber == originalBlock.blockNumber)
            #expect(decodedBlock.blockControlFlags == originalBlock.blockControlFlags)
            
            if let decodedNode = decodedBlock.getPreviousNode(),
               let originalNode = originalBlock.getPreviousNode() {
                #expect(decodedNode == originalNode)
            } else {
                #expect(Bool(false), "Failed to get previous node data")
            }
        } catch {
            #expect(Bool(false), "Previous node block round-trip should not throw: \(error)")
        }
    }
}
