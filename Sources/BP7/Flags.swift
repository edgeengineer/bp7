#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/******************************
 *
 * Block Control Flags
 *
 ******************************/

/// Type for block control flags
public typealias BlockControlFlagsType = UInt8

/// Block control flags for Bundle Protocol 7
public struct BlockControlFlags: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: BlockControlFlagsType
    
    public init(rawValue: BlockControlFlagsType) {
        self.rawValue = rawValue
    }
    
    /// This block must be replicated in every fragment.
    public static let blockReplicate = BlockControlFlags(rawValue: 0x01)
    
    /// Transmit status report if block can't be processed.
    public static let blockStatusReport = BlockControlFlags(rawValue: 0x02)
    
    /// Delete bundle if block can't be processed.
    public static let blockDeleteBundle = BlockControlFlags(rawValue: 0x04)
    
    /// Discard block if it can't be processed.
    public static let blockRemove = BlockControlFlags(rawValue: 0x10)
    
    /// Reserved fields mask
    public static let blockCfReservedFields = BlockControlFlags(rawValue: 0xF0)
}

/// Protocol for block validation
public protocol BlockValidation {
    /// Get the block control flags
    func flags() -> BlockControlFlags
    
    /// Set the block control flags
    mutating func set(_ flags: BlockControlFlags)
    
    /// Validate the block control flags
    func validate() throws
    
    /// Check if the block control flags contain specific flags
    func contains(_ flags: BlockControlFlags) -> Bool
}

extension BlockValidation {
    /// Default implementation of validate
    public func validate() throws {
        if flags().contains(.blockCfReservedFields) {
            throw FlagsError.blockControlFlagsError("Given flag contains reserved bits")
        }
    }
    
    /// Default implementation of contains
    public func contains(_ flags: BlockControlFlags) -> Bool {
        return self.flags().contains(flags)
    }
}

extension BlockControlFlagsType: BlockValidation {
    public func flags() -> BlockControlFlags {
        return BlockControlFlags(rawValue: self)
    }
    
    public mutating func set(_ flags: BlockControlFlags) {
        self = flags.rawValue
    }
}

/******************************
 *
 * Bundle Control Flags
 *
 ******************************/

/// Type for bundle control flags
public typealias BundleControlFlagsType = UInt64

/// Bundle control flags for Bundle Protocol 7
public struct BundleControlFlags: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: BundleControlFlagsType
    
    public init(rawValue: BundleControlFlagsType) {
        self.rawValue = rawValue
    }
    
    /// Request reporting of bundle deletion.
    public static let bundleStatusRequestDeletion = BundleControlFlags(rawValue: 0x040000)
    
    /// Request reporting of bundle delivery.
    public static let bundleStatusRequestDelivery = BundleControlFlags(rawValue: 0x020000)
    
    /// Request reporting of bundle forwarding.
    public static let bundleStatusRequestForward = BundleControlFlags(rawValue: 0x010000)
    
    /// Request reporting of bundle reception.
    public static let bundleStatusRequestReception = BundleControlFlags(rawValue: 0x004000)
    
    /// Status time requested in reports.
    public static let bundleRequestStatusTime = BundleControlFlags(rawValue: 0x000040)
    
    /// Acknowledgment by application is requested.
    public static let bundleRequestUserApplicationAck = BundleControlFlags(rawValue: 0x000020)
    
    /// Bundle must not be fragmented.
    public static let bundleMustNotFragmented = BundleControlFlags(rawValue: 0x000004)
    
    /// ADU is an administrative record.
    public static let bundleAdministrativeRecordPayload = BundleControlFlags(rawValue: 0x000002)
    
    /// The bundle is a fragment.
    public static let bundleIsFragment = BundleControlFlags(rawValue: 0x000001)
    
    /// Reserved fields mask
    public static let bundleCfReservedFields = BundleControlFlags(rawValue: 0xE218)
    
    /// Empty flags (convenience)
    public static let empty: BundleControlFlags = []
}

/// Protocol for bundle validation
public protocol BundleValidation {
    /// Get the bundle control flags
    func flags() -> BundleControlFlags
    
    /// Set the bundle control flags
    mutating func set(_ flags: BundleControlFlags)
    
    /// Validate the bundle control flags
    func validate() throws
    
    /// Check if the bundle control flags contain specific flags
    func contains(_ flags: BundleControlFlags) -> Bool
}

extension BundleValidation {
    /// Default implementation of validate
    public func validate() throws {
        var errors: [Error] = []
        
        let flags = self.flags()
        
        if flags.contains(.bundleCfReservedFields) {
            errors.append(FlagsError.bundleControlFlagsError("Given flag contains reserved bits"))
        }
        
        if flags.contains(.bundleIsFragment) && flags.contains(.bundleMustNotFragmented) {
            errors.append(FlagsError.bundleControlFlagsError("Both 'bundle is a fragment' and 'bundle must not be fragmented' flags are set"))
        }
        
        let adminRecCheck = !flags.contains(.bundleAdministrativeRecordPayload) ||
            (!flags.contains(.bundleStatusRequestReception) &&
             !flags.contains(.bundleStatusRequestForward) &&
             !flags.contains(.bundleStatusRequestDelivery) &&
             !flags.contains(.bundleStatusRequestDeletion))
        
        if !adminRecCheck {
            errors.append(FlagsError.bundleControlFlagsError("\"payload is administrative record => no status report request flags\" failed"))
        }
        
        if !errors.isEmpty {
            throw FlagsError.multipleErrors(errors)
        }
    }
    
    /// Default implementation of contains
    public func contains(_ flags: BundleControlFlags) -> Bool {
        return self.flags().contains(flags)
    }
}

extension BundleControlFlagsType: BundleValidation {
    public func flags() -> BundleControlFlags {
        return BundleControlFlags(rawValue: self)
    }
    
    public mutating func set(_ flags: BundleControlFlags) {
        self = flags.rawValue
    }
}

/// Errors related to flags
public enum FlagsError: Error, Equatable, Sendable {
    case blockControlFlagsError(String)
    case bundleControlFlagsError(String)
    case multipleErrors([Error])
    
    public static func == (lhs: FlagsError, rhs: FlagsError) -> Bool {
        switch (lhs, rhs) {
        case (.blockControlFlagsError(let lhsMsg), .blockControlFlagsError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.bundleControlFlagsError(let lhsMsg), .bundleControlFlagsError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.multipleErrors(let lhsErrors), .multipleErrors(let rhsErrors)):
            // This is a simplified comparison that might not work for all Error types
            return lhsErrors.count == rhsErrors.count
        default:
            return false
        }
    }
}
