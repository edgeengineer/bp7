import Foundation
import CBOR
import CryptoKit

/// Parameter for SHA variant
public struct ShaVariantParameter: Codable, Sendable {
    public var id: UInt8
    public var variant: ShaVariantType
    
    public init(id: UInt8, variant: ShaVariantType) {
        self.id = id
        self.variant = variant
    }
}

/// Parameter for wrapped key
public struct WrappedKeyParameter: Codable, Sendable {
    public var id: UInt8
    public var key: [UInt8]
    
    public init(id: UInt8, key: [UInt8]) {
        self.id = id
        self.key = key
    }
}

/// Parameter for integrity scope flags
public struct IntegrityScopeFlagsParameter: Codable, Sendable {
    public var id: UInt8
    public var flags: IntegrityScopeFlagsType
    
    public init(id: UInt8, flags: IntegrityScopeFlagsType) {
        self.id = id
        self.flags = flags
    }
}

/// BIB Security Context Parameters as defined in RFC 9173
public struct BibSecurityContextParameter: Sendable, Codable {
    public var shaVariant: ShaVariantParameter?
    public var wrappedKey: WrappedKeyParameter?
    public var integrityScopeFlags: IntegrityScopeFlagsParameter?
    
    /// Create a new BibSecurityContextParameter with specified values
    public init(
        shaVariant: ShaVariantParameter? = nil,
        wrappedKey: WrappedKeyParameter? = nil,
        integrityScopeFlags: IntegrityScopeFlagsParameter? = nil
    ) {
        self.shaVariant = shaVariant
        self.wrappedKey = wrappedKey
        self.integrityScopeFlags = integrityScopeFlags
    }
    
    /// Create a default BibSecurityContextParameter
    public static func defaultParameter() -> BibSecurityContextParameter {
        return BibSecurityContextParameter(
            shaVariant: ShaVariantParameter(id: 1, variant: HMAC_SHA_384),
            wrappedKey: nil,
            integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: 0x0007)
        )
    }
}

/// Integrity Block as defined in RFC 9172
public struct IntegrityBlock: Sendable {
    public var securityTargets: [UInt64]
    public var securityContextId: SecurityContextId
    public var securityContextFlags: SecurityContextFlag
    public var securitySource: EndpointID
    public var securityContextParameters: BibSecurityContextParameter?
    public var securityResults: [[(UInt64, [UInt8])]]
    
    /// Create a new IntegrityBlock with default values
    public init() {
        self.securityTargets = []
        self.securityContextId = BIB_HMAC_SHA2_ID
        self.securityContextFlags = SEC_CONTEXT_ABSENT
        self.securitySource = EndpointID.none()
        self.securityContextParameters = nil
        self.securityResults = []
    }
    
    /// Create a new IntegrityBlock with specified values
    public init(
        securityTargets: [UInt64],
        securityContextId: SecurityContextId,
        securityContextFlags: SecurityContextFlag,
        securitySource: EndpointID,
        securityContextParameters: BibSecurityContextParameter?,
        securityResults: [[(UInt64, [UInt8])]]
    ) {
        self.securityTargets = securityTargets
        self.securityContextId = securityContextId
        self.securityContextFlags = securityContextFlags
        self.securitySource = securitySource
        self.securityContextParameters = securityContextParameters
        self.securityResults = securityResults
    }
    
    /// Compute HMAC-SHA256 for the given key and payload
    private func hmacSha256Compute(keyBytes: [UInt8], payload: [UInt8]) -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Compute HMAC-SHA384 for the given key and payload
    private func hmacSha384Compute(keyBytes: [UInt8], payload: [UInt8]) -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA384>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Compute HMAC-SHA512 for the given key and payload
    private func hmacSha512Compute(keyBytes: [UInt8], payload: [UInt8]) -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA512>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Compute HMAC for the given key and IPPT list
    public mutating func computeHmac(keyBytes: [UInt8], ipptList: [(UInt64, [UInt8])]) throws {
        // Reset security results
        self.securityResults = []
        
        // Ensure we have security context parameters
        guard let parameters = self.securityContextParameters,
              let shaVariant = parameters.shaVariant else {
            throw SecurityError.invalidSecurityContextParameter
        }
        
        for ippt in ipptList {
            if self.securityTargets.contains(ippt.0) {
                let resultValue: [UInt8]
                
                // Choose the appropriate HMAC algorithm based on the SHA variant
                switch shaVariant.variant {
                case HMAC_SHA_256:
                    resultValue = hmacSha256Compute(keyBytes: keyBytes, payload: ippt.1)
                case HMAC_SHA_384:
                    resultValue = hmacSha384Compute(keyBytes: keyBytes, payload: ippt.1)
                case HMAC_SHA_512:
                    resultValue = hmacSha512Compute(keyBytes: keyBytes, payload: ippt.1)
                default:
                    throw SecurityError.invalidShaVariant
                }
                
                // Integrity Security Context BIB-HMAC-SHA2 has only one result field
                // that means for every target there will be only one vector entry
                // with the result id set to 1 and the result value being the
                // outcome of the security operation (-> the MAC)
                self.securityResults.append([(ippt.0, resultValue)])
            } else {
                print("Security Target and IPPT mismatch. Make sure there is an IPPT for each target.")
            }
        }
    }
    
    /// Convert the IntegrityBlock to CBOR format
    public func toCbor() throws -> [UInt8] {
        var cborFormat = [UInt8]()
        
        // Encode security targets as array
        let targetsArray = securityTargets.map { CBOR.unsignedInt(UInt64($0)) }
        let securityTargetsArray = CBOR.array(targetsArray)
        cborFormat += securityTargetsArray.encode()
        
        // Encode security context ID - use Int64 for negative values
        let negativeId = Int64(-Int64(self.securityContextId) - 1)
        let securityContextIdValue = CBOR.negativeInt(negativeId)
        cborFormat += securityContextIdValue.encode()
        
        // Encode security context flags
        let securityContextFlagsValue = CBOR.unsignedInt(UInt64(self.securityContextFlags))
        cborFormat += securityContextFlagsValue.encode()
        
        // Encode security source using its encode method
        let securitySourceCbor = try self.securitySource.encode()
        cborFormat += securitySourceCbor.encode()
        
        // Encode security context parameters
        if let parameters = self.securityContextParameters {
            // Convert parameters to a CBOR map
            var mapPairs: [CBORMapPair] = []
            
            if let shaVariant = parameters.shaVariant {
                let key = CBOR.unsignedInt(UInt64(shaVariant.id))
                let value = CBOR.unsignedInt(UInt64(shaVariant.variant))
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            if let wrappedKey = parameters.wrappedKey {
                let key = CBOR.unsignedInt(UInt64(wrappedKey.id))
                let value = CBOR.byteString(wrappedKey.key)
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            if let scopeFlags = parameters.integrityScopeFlags {
                let key = CBOR.unsignedInt(UInt64(scopeFlags.id))
                let value = CBOR.unsignedInt(UInt64(scopeFlags.flags))
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            let paramsCbor = CBOR.map(mapPairs)
            cborFormat += paramsCbor.encode()
        } else {
            cborFormat += CBOR.null.encode()
        }
        
        // Format security results for CBOR encoding
        var resultItems: [CBOR] = []
        
        for result in self.securityResults {
            var resultEntries: [CBOR] = []
            
            for (target, value) in result {
                let entry = CBOR.array([
                    CBOR.unsignedInt(UInt64(target)),
                    CBOR.byteString(value)
                ])
                resultEntries.append(entry)
            }
            
            resultItems.append(CBOR.array(resultEntries))
        }
        
        let resultsArray = CBOR.array(resultItems)
        cborFormat += resultsArray.encode()
        
        return cborFormat
    }
}

/// Builder for IntegrityBlock
public struct IntegrityBlockBuilder: Sendable {
    private var securityTargets: [UInt64]?
    private var securityContextId: SecurityContextId
    private var securityContextFlags: SecurityContextFlag
    private var securitySource: EndpointID
    private var securityContextParameters: BibSecurityContextParameter?
    private var securityResults: [[(UInt64, [UInt8])]]
    
    /// Create a new IntegrityBlockBuilder with default values
    public init() {
        self.securityTargets = nil
        self.securityContextId = BIB_HMAC_SHA2_ID
        self.securityContextFlags = SEC_CONTEXT_ABSENT
        self.securitySource = EndpointID.none()
        self.securityContextParameters = nil
        self.securityResults = []
    }
    
    /// Set the security targets
    public func securityTargets(_ securityTargets: [UInt64]) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityTargets = securityTargets
        return builder
    }
    
    /// Set the security context flags
    public func securityContextFlags(_ securityContextFlags: SecurityContextFlag) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityContextFlags = securityContextFlags
        return builder
    }
    
    /// Set the security source
    public func securitySource(_ securitySource: EndpointID) -> IntegrityBlockBuilder {
        var builder = self
        builder.securitySource = securitySource
        return builder
    }
    
    /// Set the security context parameters
    public func securityContextParameters(_ securityContextParameters: BibSecurityContextParameter) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityContextParameters = securityContextParameters
        return builder
    }
    
    /// Set the security results
    public func securityResults(_ securityResults: [[(UInt64, [UInt8])]]) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityResults = securityResults
        return builder
    }
    
    /// Build the IntegrityBlock
    public func build() throws -> IntegrityBlock {
        guard let securityTargets = self.securityTargets else {
            throw SecurityError.missingSecurityTargets
        }
        
        if self.securityContextFlags == SEC_CONTEXT_PRESENT && self.securityContextParameters == nil {
            throw SecurityError.flagSetButNoParameter
        }
        
        return IntegrityBlock(
            securityTargets: securityTargets,
            securityContextId: self.securityContextId,
            securityContextFlags: self.securityContextFlags,
            securitySource: self.securitySource,
            securityContextParameters: self.securityContextParameters,
            securityResults: self.securityResults
        )
    }
}

/// Create a new integrity block
/// - Parameters:
///   - blockNumber: The block number
///   - bcf: The block control flags
///   - securityBlock: The security block data
/// - Returns: A canonical block containing the integrity block
public func newIntegrityBlock(
    blockNumber: UInt64,
    bcf: BlockControlFlags,
    securityBlock: [UInt8]
) throws -> CanonicalBlock {
    return try CanonicalBlockBuilder()
        .blockType(INTEGRITY_BLOCK)
        .blockNumber(blockNumber)
        .blockControlFlags(bcf.rawValue)
        .data(.unknown(securityBlock))
        .build()
}
