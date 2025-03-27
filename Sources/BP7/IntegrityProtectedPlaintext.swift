import Foundation
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
    public var scopeFlags: IntegrityScopeFlagsType
    public var primaryBlock: PrimaryBlock?
    public var securityHeader: SecurityBlockHeader?
    public var securityTargetContents: [UInt8]
    
    /// Create a new IntegrityProtectedPlaintext with default values
    public init() {
        self.scopeFlags = 0x0007 // default value with all flags set
        self.primaryBlock = nil
        self.securityHeader = nil
        self.securityTargetContents = []
    }
    
    /// Create a new IntegrityProtectedPlaintext with specified values
    public init(scopeFlags: IntegrityScopeFlagsType, primaryBlock: PrimaryBlock? = nil, 
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
                let primaryData = try pb.toCbor()
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
        
        // Create canonical form of the security target contents
        if case let .data(data) = payloadBlock.getData() {
            securityTargetContents = data
        } else {
            // For other types, use the raw data or serialize it
            securityTargetContents = try serializeCanonicalData(payloadBlock.getData())
        }
        
        // Create the final IPPT data
        var ippt = [UInt8]()
        
        // Encode the scope flags as a CBOR unsigned integer
        let scopeFlagsValue = CBOR.unsignedInt(UInt64(scopeFlags))
        let scopeFlagsCbor = scopeFlagsValue.encode()
        ippt += scopeFlagsCbor
        ippt += optionalIpptData
        ippt += securityTargetContents
        
        return ippt
    }
    
    /// Serialize canonical data to CBOR
    private func serializeCanonicalData(_ data: CanonicalData) throws -> [UInt8] {
        switch data {
        case .data(let bytes):
            return bytes
        case .unknown(let bytes):
            return bytes
        default:
            // For other types, create a simple representation
            let stringValue = CBOR.textString(String(describing: data))
            return stringValue.encode()
        }
    }
    
    /// Construct the payload header in canonical form
    /// - Parameter payloadBlock: The canonical block whose header is being included
    /// - Returns: The byte buffer containing the payload header
    private func constructPayloadHeader(payloadBlock: CanonicalBlock) throws -> [UInt8]? {
        var header = [UInt8]()
        
        // Encode block type as CBOR unsigned integer
        let blockTypeValue = CBOR.unsignedInt(UInt64(payloadBlock.blockType))
        let blockTypeCbor = blockTypeValue.encode()
        header += blockTypeCbor
        
        // Encode block number as CBOR unsigned integer
        let blockNumberValue = CBOR.unsignedInt(payloadBlock.blockNumber)
        let blockNumberCbor = blockNumberValue.encode()
        header += blockNumberCbor
        
        // Encode block control flags as CBOR unsigned integer
        let blockControlFlagsValue = CBOR.unsignedInt(UInt64(payloadBlock.blockControlFlags))
        let blockControlFlagsCbor = blockControlFlagsValue.encode()
        header += blockControlFlagsCbor
        
        return header
    }
    
    /// Construct the security header in canonical form
    /// - Parameter securityHeader: The security block header tuple
    /// - Returns: The byte buffer containing the security header
    private func constructSecurityHeader(securityHeader: SecurityBlockHeader) throws -> [UInt8]? {
        var header = [UInt8]()
        
        // Encode block type as CBOR unsigned integer
        let blockTypeValue = CBOR.unsignedInt(UInt64(securityHeader.0))
        let blockTypeCbor = blockTypeValue.encode()
        header += blockTypeCbor
        
        // Encode block number as CBOR unsigned integer
        let blockNumberValue = CBOR.unsignedInt(securityHeader.1)
        let blockNumberCbor = blockNumberValue.encode()
        header += blockNumberCbor
        
        // Encode block control flags as CBOR unsigned integer
        let blockControlFlagsValue = CBOR.unsignedInt(UInt64(securityHeader.2))
        let blockControlFlagsCbor = blockControlFlagsValue.encode()
        header += blockControlFlagsCbor
        
        return header
    }
}

/// Builder for IntegrityProtectedPlaintext
public struct IpptBuilder: Sendable {
    private var scopeFlags: IntegrityScopeFlagsType
    private var primaryBlock: PrimaryBlock?
    private var securityHeader: SecurityBlockHeader?
    private var securityTargetContents: [UInt8]
    
    /// Create a new IpptBuilder with default values
    public init() {
        self.scopeFlags = 0x0007 // default value with all flags set
        self.primaryBlock = nil
        self.securityHeader = nil
        self.securityTargetContents = []
    }
    
    /// Set the scope flags
    public func scopeFlags(_ scopeFlags: IntegrityScopeFlagsType) -> IpptBuilder {
        var builder = self
        builder.scopeFlags = scopeFlags
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
