#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CBOR

/// Structure to hold the Integrity Protected Plaintext. The content
/// of the IPPT is constructed as the concatenation of information
/// whose integrity is being preserved. Can optionally protect the integrity of
/// the primary block, the payload block header, the security block header.
/// The payload of the security target itself is always protected.
///
/// To function correctly the scope_flags have to be set accordingly.
/// The default value is 0x0007, which means all flags are set.
///
/// Bit 0 (the low-order bit, 0x0001): Include primary block flag
/// Bit 1 (0x0002): Include target header flag
/// Bit 2 (0x0004): Include security header flag
/// Bits 3-15: Unassigned.
public struct IntegrityProtectedPlaintext: Sendable {
    public var scopeFlags: IntegrityScopeFlags
    public var primaryBlock: PrimaryBlock?
    public var securityHeader: SecurityBlockHeader?
    public var securityTargetContents: [UInt8]
    
    /// Create a new IntegrityProtectedPlaintext with default values
    public init() {
        self.scopeFlags = IntegrityScopeFlags.all // default value with all flags set
        self.primaryBlock = nil
        self.securityHeader = nil
        self.securityTargetContents = []
    }
    
    /// Create a new IntegrityProtectedPlaintext with specified values
    public init(scopeFlags: IntegrityScopeFlags, primaryBlock: PrimaryBlock? = nil, 
                securityHeader: SecurityBlockHeader? = nil, securityTargetContents: [UInt8] = []) {
        self.scopeFlags = scopeFlags
        self.primaryBlock = primaryBlock
        self.securityHeader = securityHeader
        self.securityTargetContents = securityTargetContents
    }
    
    /// Create the IPPT data for integrity protection
    /// - Parameter payloadBlock: The canonical block whose data is being protected
    /// - Returns: The byte buffer containing the IPPT data
    public mutating func create(payloadBlock: CanonicalBlock) throws -> [UInt8] {
        // If header data is not nil and corresponding flag is set, include in MAC
        var optionalIpptData = [UInt8]()
        
        // Include primary block if flag is set and primary block is available
        if scopeFlags.contains(.integrityPrimaryHeader) {
            if let pb = primaryBlock {
                let primaryData = pb.toCbor()
                optionalIpptData += primaryData
            } else {
                print("Primary header flag set but no primary header given!")
            }
        }
        
        // Include payload header if flag is set
        if scopeFlags.contains(.integrityPayloadHeader) {
            if let headerData = try constructPayloadHeader(payloadBlock: payloadBlock) {
                optionalIpptData += headerData
            }
        }
        
        // Include security header if flag is set and security header is available
        if scopeFlags.contains(.integritySecurityHeader) {
            if let sh = securityHeader {
                if let headerData = try constructSecurityHeader(securityHeader: sh) {
                    optionalIpptData += headerData
                }
            } else {
                print("Security header flag set but no security header given!")
            }
        }
        
        // Encode the scope flags as CBOR
        let scopeFlagsValue = CBOR.unsignedInt(UInt64(scopeFlags.rawValue))
        var ipptData = scopeFlagsValue.encode()
        
        // Add optional data
        ipptData += optionalIpptData
        
        // Add the payload data
        if case let .data(payloadData) = payloadBlock.getData() {
            ipptData += payloadData
        } else if case let .unknown(unknownData) = payloadBlock.getData() {
            ipptData += unknownData
        } else {
            throw SecurityError.invalidPayloadData
        }
        
        return ipptData
    }
    
    /// Construct the payload header for the IPPT
    /// - Parameter payloadBlock: The canonical block whose header is being protected
    /// - Returns: The byte buffer containing the payload header
    private func constructPayloadHeader(payloadBlock: CanonicalBlock) throws -> [UInt8]? {
        var header = [UInt8]()
        
        // Encode block type
        let blockTypeValue = CBOR.unsignedInt(UInt64(payloadBlock.blockType))
        header += blockTypeValue.encode()
        
        // Encode block number
        let blockNumberValue = CBOR.unsignedInt(UInt64(payloadBlock.blockNumber))
        header += blockNumberValue.encode()
        
        // Encode block control flags
        let blockControlFlagsValue = CBOR.unsignedInt(UInt64(payloadBlock.blockControlFlags))
        header += blockControlFlagsValue.encode()
        
        return header
    }
    
    /// Construct the security header for the IPPT
    /// - Parameter securityHeader: The security block header tuple
    /// - Returns: The byte buffer containing the security header
    private func constructSecurityHeader(securityHeader: SecurityBlockHeader) throws -> [UInt8]? {
        var header = [UInt8]()
        
        // Encode block type
        let blockTypeValue = CBOR.unsignedInt(UInt64(securityHeader.0))
        header += blockTypeValue.encode()
        
        // Encode block number
        let blockNumberValue = CBOR.unsignedInt(UInt64(securityHeader.1))
        header += blockNumberValue.encode()
        
        // Encode block control flags
        let blockControlFlagsValue = CBOR.unsignedInt(UInt64(securityHeader.2))
        header += blockControlFlagsValue.encode()
        
        return header
    }
}

/// Builder for IntegrityProtectedPlaintext
public struct IpptBuilder: Sendable {
    private var scopeFlags: IntegrityScopeFlags
    private var primaryBlock: PrimaryBlock?
    private var securityHeader: SecurityBlockHeader?
    private var securityTargetContents: [UInt8]
    
    /// Create a new IpptBuilder with default values
    public init() {
        self.scopeFlags = IntegrityScopeFlags.all
        self.primaryBlock = nil
        self.securityHeader = nil
        self.securityTargetContents = []
    }
    
    /// Set the scope flags
    public func scopeFlags(_ scopeFlags: IntegrityScopeFlagsType) -> IpptBuilder {
        var builder = self
        builder.scopeFlags = IntegrityScopeFlags(rawValue: scopeFlags)
        return builder
    }
    
    /// Set the primary block
    public func primaryBlock(_ primaryBlock: PrimaryBlock) -> IpptBuilder {
        var builder = self
        builder.primaryBlock = primaryBlock
        return builder
    }
    
    /// Set the security header
    public func securityHeader(_ securityHeader: SecurityBlockHeader) -> IpptBuilder {
        var builder = self
        builder.securityHeader = securityHeader
        return builder
    }
    
    /// Set the security target contents
    public func securityTargetContents(_ securityTargetContents: [UInt8]) -> IpptBuilder {
        var builder = self
        builder.securityTargetContents = securityTargetContents
        return builder
    }
    
    /// Build the IntegrityProtectedPlaintext
    public func build() -> IntegrityProtectedPlaintext {
        return IntegrityProtectedPlaintext(
            scopeFlags: scopeFlags,
            primaryBlock: primaryBlock,
            securityHeader: securityHeader,
            securityTargetContents: securityTargetContents
        )
    }
}
