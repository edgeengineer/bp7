#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CBOR
import Testing
@testable import BP7

@Suite("Security Tests")
struct SecurityTests {
    
    @Test("Integrity Scope Flags")
    func testIntegrityScopeFlags() {
        // Test individual flags
        let primaryFlag = IntegrityScopeFlags.integrityPrimaryHeader
        let payloadFlag = IntegrityScopeFlags.integrityPayloadHeader
        let securityFlag = IntegrityScopeFlags.integritySecurityHeader
        
        #expect(primaryFlag.rawValue == 0x0001)
        #expect(payloadFlag.rawValue == 0x0002)
        #expect(securityFlag.rawValue == 0x0004)
        
        // Test combined flags
        let allFlags = IntegrityScopeFlags.all
        #expect(allFlags.rawValue == 0x0007)
        #expect(allFlags.contains(primaryFlag))
        #expect(allFlags.contains(payloadFlag))
        #expect(allFlags.contains(securityFlag))
        
        // Test flag validation
        let flagsValue: IntegrityScopeFlags = [.integrityPrimaryHeader, .integrityPayloadHeader]
        #expect(flagsValue.contains(.integrityPrimaryHeader))
        #expect(flagsValue.contains(.integrityPayloadHeader))
        #expect(!flagsValue.contains(.integritySecurityHeader))
    }
    
    @Test("BIB Security Context Parameter")
    func testBibSecurityContextParameter() {
        // Create a default parameter
        let defaultParam = BibSecurityContextParameter.defaultParameter()
        #expect(defaultParam.shaVariant?.variant == Security.Crypto.ShaVariant.sha384)
        #expect(defaultParam.wrappedKey == nil)
        #expect(defaultParam.integrityScopeFlags?.flags == IntegrityScopeFlags.all)
        
        // Create a custom parameter
        let customParam = BibSecurityContextParameter(
            shaVariant: ShaVariantParameter(id: 1, variant: Security.Crypto.ShaVariant.sha256),
            wrappedKey: WrappedKeyParameter(id: 2, key: [0x01, 0x02, 0x03, 0x04]),
            integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: IntegrityScopeFlags([.integrityPrimaryHeader, .integrityPayloadHeader]))
        )
        
        #expect(customParam.shaVariant?.variant == Security.Crypto.ShaVariant.sha256)
        #expect(customParam.wrappedKey?.key == [0x01, 0x02, 0x03, 0x04])
        #expect(customParam.integrityScopeFlags?.flags == IntegrityScopeFlags([.integrityPrimaryHeader, .integrityPayloadHeader]))
        
        // Test CBOR encoding and decoding
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(customParam)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(BibSecurityContextParameter.self, from: data)
            
            #expect(decoded.shaVariant?.variant == customParam.shaVariant?.variant)
            #expect(decoded.wrappedKey?.key == customParam.wrappedKey?.key)
            #expect(decoded.integrityScopeFlags?.flags == customParam.integrityScopeFlags?.flags)
        } catch {
            #expect(Bool(false), "JSON encoding/decoding failed: \(error)")
        }
    }
    
    @Test("Integrity Protected Plaintext")
    func testIntegrityProtectedPlaintext() {
        // Create a primary block
        let primaryBlock = try! PrimaryBlockBuilder()
            .destination(EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")))
            .source(EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")))
            .reportTo(EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")))
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .build()
        
        // Create a payload block
        let payloadBlock = try! CanonicalBlockBuilder()
            .blockType(BlockType.payload.rawValue)
            .blockNumber(1)
            .blockControlFlags(0)
            .data(.data([0x01, 0x02, 0x03, 0x04]))
            .build()
        
        // Create a security header
        let securityHeader: SecurityBlockHeader = (Security.BlockType.integrity, 2, 0)
        
        // Create an IPPT using the builder
        let ippt = IpptBuilder()
            .scopeFlags(IntegrityScopeFlags.all.rawValue)
            .primaryBlock(primaryBlock)
            .securityHeader(securityHeader)
            .build()
        
        // Create the IPPT data
        do {
            var ipptInstance = ippt
            let ipptData = try ipptInstance.create(payloadBlock: payloadBlock)
            
            #expect(!ipptData.isEmpty)
            
            // Verify the IPPT contains the scope flags
            let scopeFlagsValue = CBOR.unsignedInt(UInt64(IntegrityScopeFlags.all.rawValue))
            let scopeFlags = scopeFlagsValue.encode()
            #expect(Array(ipptData.prefix(scopeFlags.count)) == scopeFlags)
            
        } catch {
            #expect(Bool(false), "IPPT creation failed: \(error)")
        }
    }
    
    @Test("Integrity Block")
    func testIntegrityBlock() {
        // Create security targets
        let securityTargets: [UInt64] = [1]
        
        // Create security source
        let securitySource = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//security-source/"))
        
        // Create security context parameters
        let securityContextParameters = BibSecurityContextParameter(
            shaVariant: ShaVariantParameter(id: 1, variant: Security.Crypto.ShaVariant.sha384),
            wrappedKey: nil,
            integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: IntegrityScopeFlags.all)
        )
        
        // Create an integrity block using the builder
        do {
            let integrityBlock = try IntegrityBlockBuilder()
                .securityTargets(securityTargets)
                .securityContextFlags(Security.Context.Flag.present)
                .securitySource(securitySource)
                .securityContextParameters(securityContextParameters)
                .build()
            
            // Verify the integrity block properties
            #expect(integrityBlock.securityTargets == securityTargets)
            #expect(integrityBlock.securityContextId == Security.Context.ID.bibHmacSha2)
            #expect(integrityBlock.securityContextFlags == Security.Context.Flag.present)
            #expect(integrityBlock.securitySource == securitySource)
            #expect(integrityBlock.securityContextParameters?.shaVariant?.variant == Security.Crypto.ShaVariant.sha384)
            #expect(integrityBlock.securityContextParameters?.integrityScopeFlags?.flags == IntegrityScopeFlags.all)
            
            // Test CBOR encoding
            let cborData = try integrityBlock.toCbor()
            #expect(!cborData.isEmpty)
            
        } catch {
            #expect(Bool(false), "Integrity block creation failed: \(error)")
        }
    }
    
    @Test("Integrity Block with SHA-256")
    func testIntegrityBlockWithSha256() {
        // Create security targets
        let securityTargets: [UInt64] = [1]
        
        // Create security source
        let securitySource = try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//security-source/"))
        
        // Create security context parameters with SHA-256
        let securityContextParameters = BibSecurityContextParameter(
            shaVariant: ShaVariantParameter(id: 1, variant: Security.Crypto.ShaVariant.sha256),
            wrappedKey: nil,
            integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: IntegrityScopeFlags.all)
        )
        
        // Create an integrity block using the builder
        do {
            let integrityBlock = try IntegrityBlockBuilder()
                .securityTargets(securityTargets)
                .securityContextFlags(Security.Context.Flag.present)
                .securitySource(securitySource)
                .securityContextParameters(securityContextParameters)
                .build()
            
            // Verify the integrity block properties
            #expect(integrityBlock.securityTargets == securityTargets)
            #expect(integrityBlock.securityContextId == Security.Context.ID.bibHmacSha2)
            #expect(integrityBlock.securityContextFlags == Security.Context.Flag.present)
            #expect(integrityBlock.securitySource == securitySource)
            #expect(integrityBlock.securityContextParameters?.shaVariant?.variant == Security.Crypto.ShaVariant.sha256)
            #expect(integrityBlock.securityContextParameters?.integrityScopeFlags?.flags == IntegrityScopeFlags.all)
            
            // Test CBOR encoding
            let cborData = try integrityBlock.toCbor()
            #expect(!cborData.isEmpty)
            
        } catch {
            #expect(Bool(false), "Integrity block creation failed: \(error)")
        }
    }
    
    @Test("New Integrity Block")
    func testNewIntegrityBlock() {
        // Create security block data
        let securityBlockData: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        
        // Create block control flags
        let bcf = BlockControlFlags.blockReplicate
        
        // Create a new integrity block
        do {
            let block = try IntegrityBlock.asCanonicalBlock(
                blockNumber: 2,
                bcf: bcf,
                securityBlock: securityBlockData
            )
            
            // Verify the block properties
            #expect(block.blockType == Security.BlockType.integrity)
            #expect(block.blockNumber == 2)
            #expect(block.blockControlFlags == bcf.rawValue)
            
            // Verify the block data
            if case let .unknown(data) = block.getData() {
                #expect(data == securityBlockData)
            } else {
                #expect(Bool(false), "Block data type mismatch")
            }
            
        } catch {
            #expect(Bool(false), "New integrity block creation failed: \(error)")
        }
    }
}
