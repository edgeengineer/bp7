import Crypto
import CBOR

/// Parameter for SHA variant
public struct ShaVariantParameter: Codable, Sendable {
    public var id: UInt8
    public var variant: Security.Crypto.ShaVariant
    
    public init(id: UInt8, variant: Security.Crypto.ShaVariant) {
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
    public var flags: IntegrityScopeFlags
    
    public init(id: UInt8, flags: IntegrityScopeFlags) {
        self.id = id
        self.flags = flags
    }
}

/// BIB Security Context Parameter as defined in RFC 9173
public struct BibSecurityContextParameter: Codable, Sendable {
    public var shaVariant: ShaVariantParameter?
    public var wrappedKey: WrappedKeyParameter?
    public var integrityScopeFlags: IntegrityScopeFlagsParameter?
    
    public init(
        shaVariant: ShaVariantParameter?,
        wrappedKey: WrappedKeyParameter?,
        integrityScopeFlags: IntegrityScopeFlagsParameter?
    ) {
        self.shaVariant = shaVariant
        self.wrappedKey = wrappedKey
        self.integrityScopeFlags = integrityScopeFlags
    }
    
    /// Create a default security context parameter
    public static func defaultParameter() -> BibSecurityContextParameter {
        return BibSecurityContextParameter(
            shaVariant: ShaVariantParameter(id: 1, variant: Security.Crypto.ShaVariant.sha384),
            wrappedKey: nil,
            integrityScopeFlags: IntegrityScopeFlagsParameter(id: 3, flags: IntegrityScopeFlags.all)
        )
    }
}

/// Integrity Block as defined in RFC 9172
public struct IntegrityBlock: Sendable {
    public var securityTargets: [UInt64]
    public var securityContextId: Security.Context.ID
    public var securityContextFlags: Security.Context.Flag
    public var securitySource: EndpointID
    public var securityContextParameters: BibSecurityContextParameter?
    public var securityResults: [[(UInt64, [UInt8])]]
    
    /// Create a new IntegrityBlock with default values
    public init() {
        self.securityTargets = []
        self.securityContextId = .bibHmacSha2
        self.securityContextFlags = .absent
        self.securitySource = EndpointID.none()
        self.securityContextParameters = nil
        self.securityResults = []
    }
    
    /// Create a new IntegrityBlock with specified values
    public init(
        securityTargets: [UInt64],
        securityContextId: Security.Context.ID,
        securityContextFlags: Security.Context.Flag,
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
    
    /// Compute HMAC-SHA256 for the given data
    private func hmacSha256Compute(keyBytes: [UInt8], payload: [UInt8]) throws -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Compute HMAC-SHA384 for the given data
    private func hmacSha384Compute(keyBytes: [UInt8], payload: [UInt8]) throws -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA384>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Compute HMAC-SHA512 for the given data
    private func hmacSha512Compute(keyBytes: [UInt8], payload: [UInt8]) throws -> [UInt8] {
        let key = SymmetricKey(data: keyBytes)
        let hmac = HMAC<SHA512>.authenticationCode(for: payload, using: key)
        return Array(hmac)
    }
    
    /// Generate security results for the integrity block
    public mutating func generateResults(ippts: [(UInt64, [UInt8])], keyBytes: [UInt8]) throws {
        var results: [[(UInt64, [UInt8])]] = []
        
        // Check if we have security context parameters
        guard let parameters = self.securityContextParameters else {
            throw SecurityError.missingParameters
        }
        
        // Check if we have SHA variant
        guard let shaVariant = parameters.shaVariant else {
            throw SecurityError.missingShaVariant
        }
        
        // For each target, compute the HMAC
        for ippt in ippts {
            var targetResults: [(UInt64, [UInt8])] = []
            var resultValue: [UInt8]
            
            do {
                // Choose the appropriate HMAC algorithm based on the SHA variant
                switch shaVariant.variant {
                case .sha256:
                    resultValue = try hmacSha256Compute(keyBytes: keyBytes, payload: ippt.1)
                case .sha384:
                    resultValue = try hmacSha384Compute(keyBytes: keyBytes, payload: ippt.1)
                case .sha512:
                    resultValue = try hmacSha512Compute(keyBytes: keyBytes, payload: ippt.1)
                }
                
                targetResults.append((ippt.0, resultValue))
            } catch {
                throw SecurityError.hmacComputationFailed
            }
            
            results.append(targetResults)
        }
        
        self.securityResults = results
    }
    
    /// Convert the integrity block to CBOR format
    public func toCbor() throws -> [UInt8] {
        var cborFormat: [UInt8] = []
        
        // Encode security targets as an array
        let securityTargetsArray = CBOR.array(self.securityTargets.map { CBOR.unsignedInt(UInt64($0)) })
        cborFormat += securityTargetsArray.encode()
        
        // Encode security context ID - use Int64 for negative values
        let negativeId = Int64(-Int64(self.securityContextId.rawValue) - 1)
        let securityContextIdValue = CBOR.negativeInt(negativeId)
        cborFormat += securityContextIdValue.encode()
        
        // Encode security context flags
        let securityContextFlagsValue = CBOR.unsignedInt(UInt64(self.securityContextFlags.rawValue))
        cborFormat += securityContextFlagsValue.encode()
        
        // Encode security source using its encode method
        let securitySourceCbor = self.securitySource.encode()
        cborFormat += securitySourceCbor.encode()
        
        // Encode security context parameters if present
        if let parameters = self.securityContextParameters {
            var mapPairs: [CBORMapPair] = []
            
            if let shaVariant = parameters.shaVariant {
                let key = CBOR.unsignedInt(UInt64(shaVariant.id))
                let value = CBOR.unsignedInt(UInt64(shaVariant.variant.rawValue))
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            if let wrappedKey = parameters.wrappedKey {
                let key = CBOR.unsignedInt(UInt64(wrappedKey.id))
                let value = CBOR.byteString(ArraySlice(wrappedKey.key))
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            if let scopeFlags = parameters.integrityScopeFlags {
                let key = CBOR.unsignedInt(UInt64(scopeFlags.id))
                let value = CBOR.unsignedInt(UInt64(scopeFlags.flags.rawValue))
                mapPairs.append(CBORMapPair(key: key, value: value))
            }
            
            let parametersMap = CBOR.map(mapPairs)
            cborFormat += parametersMap.encode()
        } else {
            // Encode null if no parameters
            cborFormat += CBOR.null.encode()
        }
        
        // Encode security results if present
        if !self.securityResults.isEmpty {
            var resultsArray: [CBOR] = []
            
            for targetResults in self.securityResults {
                var targetResultsArray: [CBOR] = []
                
                for (targetNum, resultValue) in targetResults {
                    let resultPair = CBOR.array([CBOR.unsignedInt(UInt64(targetNum)), CBOR.byteString(ArraySlice(resultValue))])
                    targetResultsArray.append(resultPair)
                }
                
                resultsArray.append(CBOR.array(targetResultsArray))
            }
            
            let securityResultsValue = CBOR.array(resultsArray)
            cborFormat += securityResultsValue.encode()
        } else {
            // Encode null if no results
            cborFormat += CBOR.null.encode()
        }
        
        return cborFormat
    }
    
    /// Validate the integrity block
    public func validate() throws {
        // Validate security context flags
        if self.securityContextFlags == .present && self.securityContextParameters == nil {
            throw IntegrityBlockError.invalidSecurityContextParameters
        }
        
        // Additional validation can be added here
    }
    
    /// Create a new integrity block as a canonical block
    /// - Parameters:
    ///   - blockNumber: The block number to assign
    ///   - bcf: Block control flags
    ///   - securityBlock: The security block data
    /// - Returns: A canonical block containing the integrity block
    public static func asCanonicalBlock(
        blockNumber: UInt64,
        bcf: BlockControlFlags,
        securityBlock: [UInt8]
    ) throws -> CanonicalBlock {
        return try CanonicalBlockBuilder()
            .blockType(Security.BlockType.integrity)
            .blockNumber(blockNumber)
            .blockControlFlags(bcf.rawValue)
            .data(.unknown(securityBlock))
            .build()
    }
}

/// Builder for IntegrityBlock
public struct IntegrityBlockBuilder {
    private var securityTargets: [UInt64]
    private var securityContextId: Security.Context.ID
    private var securityContextFlags: Security.Context.Flag
    private var securitySource: EndpointID
    private var securityContextParameters: BibSecurityContextParameter?
    private var securityResults: [[(UInt64, [UInt8])]]
    
    /// Create a new IntegrityBlockBuilder with default values
    public init(securityTargets: [UInt64] = []) {
        self.securityTargets = securityTargets
        self.securityContextId = .bibHmacSha2
        self.securityContextFlags = .absent
        self.securitySource = EndpointID.none()
        self.securityContextParameters = nil
        self.securityResults = []
    }
    
    /// Set the security targets 
    /// - Parameter securityTargets: The security targets
    /// - Returns: The builder
    public func securityTargets(_ securityTargets: [UInt64]) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityTargets = securityTargets
        return builder
    }
    
    /// Set the security context flags
    /// - Parameter securityContextFlags: The security context flags
    /// - Returns: The builder
    public func securityContextFlags(_ securityContextFlags: Security.Context.Flag) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityContextFlags = securityContextFlags
        return builder
    }
    
    /// Set the security source
    /// - Parameter securitySource: The security source
    /// - Returns: The builder
    public func securitySource(_ securitySource: EndpointID) -> IntegrityBlockBuilder {
        var builder = self
        builder.securitySource = securitySource
        return builder
    }
    
    /// Set the security context parameters
    /// - Parameter securityContextParameters: The security context parameters
    /// - Returns: The builder
    public func securityContextParameters(_ securityContextParameters: BibSecurityContextParameter) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityContextParameters = securityContextParameters
        return builder
    }
    
    /// Set the security results
    /// - Parameter securityResults: The security results
    /// - Returns: The builder
    public func securityResults(_ securityResults: [[(UInt64, [UInt8])]]) -> IntegrityBlockBuilder {
        var builder = self
        builder.securityResults = securityResults
        return builder
    }
    
    /// Build the integrity block
    /// - Returns: The integrity block
    /// - Throws: SecurityError
    public func build() throws -> IntegrityBlock {
        // Validate required fields
        guard !self.securityTargets.isEmpty else {
            throw SecurityError.missingSecurityTargets
        }
        
        if self.securityContextFlags == .present && self.securityContextParameters == nil {
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
