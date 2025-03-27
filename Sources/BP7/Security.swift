import Foundation
import CryptoKit

// MARK: - Security Block Types
/// Block types for security blocks as defined in RFC 9172
public let INTEGRITY_BLOCK: CanonicalBlockType = 11
public let CONFIDENTIALITY_BLOCK: CanonicalBlockType = 12

// MARK: - SHA Variants
/// SHA Variants as defined in RFC 9173
public typealias ShaVariantType = UInt16
public let HMAC_SHA_256: ShaVariantType = 5
public let HMAC_SHA_384: ShaVariantType = 6 // default
public let HMAC_SHA_512: ShaVariantType = 7

// MARK: - Security Context Identifiers
/// Security Context Identifiers as defined in RFC 9172
public typealias SecurityContextId = Int16
public let BIB_HMAC_SHA2_ID: SecurityContextId = 1 // BIB-HMAC-SHA2
public let BCB_AES_GCM_ID: SecurityContextId = 2 // BCB-AES-GCM

// MARK: - Security Context Flags
/// Security Context Flags
public typealias SecurityContextFlag = UInt8
public let SEC_CONTEXT_ABSENT: SecurityContextFlag = 0 // Security context parameters should be empty
public let SEC_CONTEXT_PRESENT: SecurityContextFlag = 1 // Security context parameters are defined

// MARK: - AES Variants
/// AES Variants as defined in RFC 9173
public typealias AesVariantType = UInt16
public let AES_128_GCM: AesVariantType = 1
public let AES_256_GCM: AesVariantType = 3 // default

/// Security Block Header type
public typealias SecurityBlockHeader = (CanonicalBlockType, UInt64, BlockControlFlagsType)

// MARK: - Integrity Scope Flags
/// Integrity Scope Flags as defined in RFC 9173
public typealias IntegrityScopeFlagsType = UInt16

/// Integrity Scope Flags
public struct IntegrityScopeFlags: OptionSet, Sendable {
    public let rawValue: IntegrityScopeFlagsType
    
    public init(rawValue: IntegrityScopeFlagsType) {
        self.rawValue = rawValue
    }
    
    /// Include primary block flag
    public static let integrityPrimaryHeader = IntegrityScopeFlags(rawValue: 0x0001)
    /// Include target header flag
    public static let integrityPayloadHeader = IntegrityScopeFlags(rawValue: 0x0002)
    /// Include security header flag
    public static let integritySecurityHeader = IntegrityScopeFlags(rawValue: 0x0004)
    
    /// Default value with all flags set
    public static let all: IntegrityScopeFlags = [.integrityPrimaryHeader, .integrityPayloadHeader, .integritySecurityHeader]
}

// MARK: - Security Errors
/// Errors related to security operations
public enum SecurityError: Error, Sendable {
    case missingSecurityTargets
    case flagSetButNoParameter
    case invalidShaVariant
    case hmacComputationFailed
    case invalidSecurityContextParameter
}

// MARK: - Scope Validation Protocol
/// Protocol for validating integrity scope flags
public protocol ScopeValidation {
    func flags() -> IntegrityScopeFlags
    func contains(_ flags: IntegrityScopeFlags) -> Bool
}

extension IntegrityScopeFlagsType: ScopeValidation {
    public func flags() -> IntegrityScopeFlags {
        return IntegrityScopeFlags(rawValue: self)
    }
    
    public func contains(_ flags: IntegrityScopeFlags) -> Bool {
        return self.flags().contains(flags)
    }
}
