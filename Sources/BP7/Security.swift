#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Crypto

// MARK: - Security Constants
/// Security-related constants for Bundle Protocol Security (BPSec)
public enum Security {
    
    // MARK: - Block Types
    /// Block types for security blocks as defined in RFC 9172
    public enum BlockType {
        /// Block type for Bundle Integrity Block (BIB)
        public static let integrity: CanonicalBlockType = 11
        /// Block type for Bundle Confidentiality Block (BCB)
        public static let confidentiality: CanonicalBlockType = 12
    }
    
    // MARK: - Security Context
    /// Security Context related constants
    public enum Context {
        /// Security Context Identifiers as defined in RFC 9172
        public enum ID: Int16, Codable, Sendable {
            /// BIB-HMAC-SHA2 security context identifier
            case bibHmacSha2 = 1
            /// BCB-AES-GCM security context identifier
            case bcbAesGcm = 2
        }
        
        /// Security Context Flags
        public enum Flag: UInt8, Codable, Sendable, Equatable {
            /// Security context parameters should be empty
            case absent = 0
            /// Security context parameters are defined
            case present = 1
        }
    }
    
    // MARK: - Cryptographic Algorithms
    /// Cryptographic algorithm constants
    public enum Crypto {
        /// SHA Variants as defined in RFC 9173
        public enum ShaVariant: UInt16, Codable, Sendable {
            /// HMAC with SHA-256
            case sha256 = 5
            /// HMAC with SHA-384 (default)
            case sha384 = 6
            /// HMAC with SHA-512
            case sha512 = 7
        }
        
        /// AES Variants as defined in RFC 9173
        public enum AesVariant: UInt16, Codable, Sendable {
            /// AES-128 in GCM mode
            case aes128Gcm = 1
            /// AES-256 in GCM mode (default)
            case aes256Gcm = 3
        }
    }
}

// MARK: - Type Aliases
/// Security Context Identifier type
public typealias SecurityContextId = Int16
/// Security Context Flag type
public typealias SecurityContextFlag = UInt8
/// SHA Variant Parameter type
public typealias ShaVariantType = UInt16
/// AES Variant Parameter type
public typealias AesVariantType = UInt16
/// Security Block Header type (block type, block number, flags)
public typealias SecurityBlockHeader = (CanonicalBlockType, UInt64, BlockControlFlagsType)
/// Integrity Scope Flags type
public typealias IntegrityScopeFlagsType = UInt16

// MARK: - Error Types
/// Errors that can occur during security operations
public enum IntegrityBlockError: Error {
    case invalidSecurityContextParameters
    case invalidSecurityResults
    case invalidSecurityTargets
}

/// Security-related errors
public enum SecurityError: Error, Sendable {
    case invalidSecurityContextParameter
    case missingSecurityTargets
    case flagSetButNoParameter
    case invalidShaVariant
    case hmacComputationFailed
    case missingParameters
    case missingShaVariant
    case invalidPayloadData
}

// MARK: - Integrity Scope Flags
/// Integrity Scope Flags as defined in RFC 9173
public struct IntegrityScopeFlags: OptionSet, Sendable, Codable {
    public let rawValue: IntegrityScopeFlagsType
    
    public init(rawValue: IntegrityScopeFlagsType) {
        self.rawValue = rawValue
    }
    
    /// Include the primary block in the integrity scope
    public static let integrityPrimaryHeader = IntegrityScopeFlags(rawValue: 0x0001)
    
    /// Include the payload header in the integrity scope
    public static let integrityPayloadHeader = IntegrityScopeFlags(rawValue: 0x0002)
    
    /// Include the security header in the integrity scope
    public static let integritySecurityHeader = IntegrityScopeFlags(rawValue: 0x0004)
    
    /// Include all headers in the integrity scope
    public static let all: IntegrityScopeFlags = [.integrityPrimaryHeader, .integrityPayloadHeader, .integritySecurityHeader]
}

// MARK: - Scope Validation Protocol
/// Protocol for validating integrity scope flags
public protocol ScopeValidation {
    /// Validate the integrity scope flags
    func validateScope(flags: IntegrityScopeFlags) -> Bool
}
