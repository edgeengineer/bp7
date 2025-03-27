import Testing
@testable import BP7

@Suite("Flags Tests")
struct FlagsTests {
    
    // MARK: - Block Control Flags Tests
    
    @Test("Block Control Flags Creation")
    func testBlockControlFlagsCreation() {
        // Test individual flags
        let replicateFlag = BlockControlFlags.blockReplicate
        #expect(replicateFlag.rawValue == 0x01)
        
        let statusReportFlag = BlockControlFlags.blockStatusReport
        #expect(statusReportFlag.rawValue == 0x02)
        
        let deleteBundleFlag = BlockControlFlags.blockDeleteBundle
        #expect(deleteBundleFlag.rawValue == 0x04)
        
        let removeFlag = BlockControlFlags.blockRemove
        #expect(removeFlag.rawValue == 0x10)
        
        // Test combined flags
        let combinedFlags: BlockControlFlags = [.blockReplicate, .blockStatusReport]
        #expect(combinedFlags.rawValue == 0x03)
        
        // Test contains method
        #expect(combinedFlags.contains(.blockReplicate))
        #expect(combinedFlags.contains(.blockStatusReport))
        #expect(!combinedFlags.contains(.blockDeleteBundle))
        #expect(!combinedFlags.contains(.blockRemove))
    }
    
    @Test("Block Control Flags Validation")
    func testBlockControlFlagsValidation() {
        // Valid flags
        var validFlags: BlockControlFlagsType = 0x07 // Replicate + StatusReport + DeleteBundle
        do {
            try validFlags.validate()
            // If we get here, validation succeeded as expected
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Validation should succeed for valid flags")
        }
        
        // Invalid flags with reserved bits
        let invalidFlags: BlockControlFlagsType = 0xF0 // Reserved bits
        do {
            try invalidFlags.validate()
            #expect(Bool(false), "Validation should fail for reserved bits")
        } catch let error as FlagsError {
            if case .blockControlFlagsError(let message) = error {
                #expect(message == "Given flag contains reserved bits")
            } else {
                #expect(Bool(false), "Unexpected error type")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }
        
        // Test set method
        validFlags.set([.blockReplicate, .blockRemove])
        #expect(validFlags == 0x11)
    }
    
    // MARK: - Bundle Control Flags Tests
    
    @Test("Bundle Control Flags Creation")
    func testBundleControlFlagsCreation() {
        // Test individual flags
        let deletionFlag = BundleControlFlags.bundleStatusRequestDeletion
        #expect(deletionFlag.rawValue == 0x040000)
        
        let deliveryFlag = BundleControlFlags.bundleStatusRequestDelivery
        #expect(deliveryFlag.rawValue == 0x020000)
        
        let forwardFlag = BundleControlFlags.bundleStatusRequestForward
        #expect(forwardFlag.rawValue == 0x010000)
        
        let receptionFlag = BundleControlFlags.bundleStatusRequestReception
        #expect(receptionFlag.rawValue == 0x004000)
        
        let statusTimeFlag = BundleControlFlags.bundleRequestStatusTime
        #expect(statusTimeFlag.rawValue == 0x000040)
        
        let appAckFlag = BundleControlFlags.bundleRequestUserApplicationAck
        #expect(appAckFlag.rawValue == 0x000020)
        
        let noFragmentFlag = BundleControlFlags.bundleMustNotFragmented
        #expect(noFragmentFlag.rawValue == 0x000004)
        
        let adminRecordFlag = BundleControlFlags.bundleAdministrativeRecordPayload
        #expect(adminRecordFlag.rawValue == 0x000002)
        
        let isFragmentFlag = BundleControlFlags.bundleIsFragment
        #expect(isFragmentFlag.rawValue == 0x000001)
        
        // Test combined flags
        let combinedFlags: BundleControlFlags = [.bundleStatusRequestDeletion, .bundleStatusRequestDelivery]
        #expect(combinedFlags.rawValue == 0x060000)
        
        // Test contains method
        #expect(combinedFlags.contains(.bundleStatusRequestDeletion))
        #expect(combinedFlags.contains(.bundleStatusRequestDelivery))
        #expect(!combinedFlags.contains(.bundleStatusRequestForward))
    }
    
    @Test("Bundle Control Flags Validation")
    func testBundleControlFlagsValidation() {
        // Valid flags
        var validFlags: BundleControlFlagsType = 0x040000 // Status Request Deletion
        do {
            try validFlags.validate()
            // If we get here, validation succeeded as expected
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Validation should succeed for valid flags")
        }
        
        // Invalid flags with reserved bits
        let reservedBitFlags: BundleControlFlagsType = 0xE218 // Reserved bits
        do {
            try reservedBitFlags.validate()
            #expect(Bool(false), "Validation should fail for reserved bits")
        } catch {
            // Expected error
            #expect(Bool(true))
        }
        
        // Invalid flags with contradictory settings
        let contradictoryFlags: BundleControlFlagsType = 0x000005 // IsFragment + MustNotFragment
        do {
            try contradictoryFlags.validate()
            #expect(Bool(false), "Validation should fail for contradictory flags")
        } catch {
            // Expected error
            #expect(Bool(true))
        }
        
        // Invalid administrative record with status request
        let adminWithStatusFlags: BundleControlFlagsType = 0x044002 // Admin record + Status request reception
        do {
            try adminWithStatusFlags.validate()
            #expect(Bool(false), "Validation should fail for admin record with status request")
        } catch {
            // Expected error
            #expect(Bool(true))
        }
        
        // Test set method
        validFlags.set([.bundleStatusRequestDelivery, .bundleRequestStatusTime])
        #expect(validFlags == 0x020040)
    }
    
    @Test("Custom Block Validation")
    func testCustomBlockValidation() {
        // Create a custom type that implements BlockValidation
        struct TestBlock: BlockValidation {
            var flagsValue: BlockControlFlags
            
            func flags() -> BlockControlFlags {
                return flagsValue
            }
            
            mutating func set(_ flags: BlockControlFlags) {
                flagsValue = flags
            }
        }
        
        // Test with valid flags
        var validBlock = TestBlock(flagsValue: [.blockReplicate, .blockStatusReport])
        do {
            try validBlock.validate()
            // If we get here, validation succeeded as expected
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Validation should succeed for valid flags")
        }
        #expect(validBlock.contains(.blockReplicate))
        
        // Test with invalid flags
        let invalidBlock = TestBlock(flagsValue: [.blockCfReservedFields])
        do {
            try invalidBlock.validate()
            #expect(Bool(false), "Validation should fail for reserved bits")
        } catch let error as FlagsError {
            if case .blockControlFlagsError(let message) = error {
                #expect(message == "Given flag contains reserved bits")
            } else {
                #expect(Bool(false), "Unexpected error type")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }
        
        // Test set method
        validBlock.set([.blockDeleteBundle])
        #expect(validBlock.flags() == .blockDeleteBundle)
    }
    
    @Test("Custom Bundle Validation")
    func testCustomBundleValidation() {
        // Create a custom type that implements BundleValidation
        struct TestBundle: BundleValidation {
            var flagsValue: BundleControlFlags
            
            func flags() -> BundleControlFlags {
                return flagsValue
            }
            
            mutating func set(_ flags: BundleControlFlags) {
                flagsValue = flags
            }
        }
        
        // Test with valid flags
        var validBundle = TestBundle(flagsValue: [.bundleStatusRequestDeletion, .bundleRequestStatusTime])
        do {
            try validBundle.validate()
            // If we get here, validation succeeded as expected
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Validation should succeed for valid flags")
        }
        #expect(validBundle.contains(.bundleStatusRequestDeletion))
        
        // Test with invalid flags (reserved bits)
        let invalidReservedBundle = TestBundle(flagsValue: [.bundleCfReservedFields])
        do {
            try invalidReservedBundle.validate()
            #expect(Bool(false), "Validation should fail for reserved bits")
        } catch {
            // Expected error
            #expect(Bool(true))
        }
        
        // Test with invalid flags (contradictory settings)
        let contradictoryBundle = TestBundle(flagsValue: [.bundleIsFragment, .bundleMustNotFragmented])
        do {
            try contradictoryBundle.validate()
            #expect(Bool(false), "Validation should fail for contradictory flags")
        } catch {
            // Expected error
            #expect(Bool(true))
        }
        
        // Test set method
        validBundle.set([.bundleAdministrativeRecordPayload])
        #expect(validBundle.flags() == .bundleAdministrativeRecordPayload)
    }
}
