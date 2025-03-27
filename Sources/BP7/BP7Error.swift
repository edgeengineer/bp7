#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Errors that can occur in the Bundle Protocol Version 7 implementation.
public enum BP7Error: Error, Equatable, CustomStringConvertible {
    /// Errors related to endpoint identifiers.
    case endpointID(EndpointIDError)
    
    /// The bundle is invalid.
    case invalidBundle
    
    /// The block is invalid.
    case invalidBlock
    
    /// The CRC is invalid.
    case invalidCRC
    
    /// The provided data is invalid.
    case invalidData
    
    /// The provided value is invalid.
    case invalidValue
    
    /// The provided time is invalid.
    case invalidTime
    
    /// The provided creation timestamp is invalid.
    case invalidCreationTimestamp
    
    /// The provided version is invalid.
    case invalidVersion(String)
    
    /// The provided lifetime is invalid.
    case invalidLifetime
    
    /// The provided sequence number is invalid.
    case invalidSequenceNumber
    
    /// The provided fragment offset is invalid.
    case invalidFragmentOffset
    
    /// The provided total application data unit length is invalid.
    case invalidTotalADULength
    
    /// The provided block type is invalid.
    case invalidBlockType
    
    /// The provided block number is invalid.
    case invalidBlockNumber
    
    /// The provided block processing control flags are invalid.
    case invalidBlockProcessingControlFlags
    
    /// The provided block data length is invalid.
    case invalidBlockDataLength
    
    /// The provided extension block data is invalid.
    case invalidExtensionBlockData
    
    /// The provided administrative record type is invalid.
    case invalidAdministrativeRecordType
    
    /// The provided administrative record content is invalid.
    case invalidAdministrativeRecordContent
    
    /// The provided status report reason code is invalid.
    case invalidStatusReportReasonCode
    
    /// The provided custody signal reason code is invalid.
    case invalidCustodySignalReasonCode
    
    /// The provided custody ID is invalid.
    case invalidCustodyID
    
    /// The provided custody signal is invalid.
    case invalidCustodySignal
    
    /// The administrative record is invalid.
    case invalidAdministrativeRecord
    
    /// The bundle status item is invalid.
    case invalidBundleStatusItem
    
    /// The status report is invalid.
    case invalidStatusReport
    
    /// The canonical block is invalid.
    case invalidCanonicalBlock
    
    /// Duplicate block number in a bundle.
    case duplicateBlockNumber
    
    /// Missing payload block in a bundle.
    case missingPayloadBlock
    
    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .endpointID(let error):
            return "EndpointID error: \(error)"
        case .invalidBundle:
            return "Invalid bundle"
        case .invalidBlock:
            return "Invalid block"
        case .invalidCRC:
            return "Invalid CRC"
        case .invalidData:
            return "Invalid data"
        case .invalidValue:
            return "Invalid value"
        case .invalidTime:
            return "Invalid time"
        case .invalidCreationTimestamp:
            return "Invalid creation timestamp"
        case .invalidVersion(let version):
            return "Invalid version: \(version)"
        case .invalidLifetime:
            return "Invalid lifetime"
        case .invalidSequenceNumber:
            return "Invalid sequence number"
        case .invalidFragmentOffset:
            return "Invalid fragment offset"
        case .invalidTotalADULength:
            return "Invalid total application data unit length"
        case .invalidBlockType:
            return "Invalid block type"
        case .invalidBlockNumber:
            return "Invalid block number"
        case .invalidBlockProcessingControlFlags:
            return "Invalid block processing control flags"
        case .invalidBlockDataLength:
            return "Invalid block data length"
        case .invalidExtensionBlockData:
            return "Invalid extension block data"
        case .invalidAdministrativeRecordType:
            return "Invalid administrative record type"
        case .invalidAdministrativeRecordContent:
            return "Invalid administrative record content"
        case .invalidStatusReportReasonCode:
            return "Invalid status report reason code"
        case .invalidCustodySignalReasonCode:
            return "Invalid custody signal reason code"
        case .invalidCustodyID:
            return "Invalid custody ID"
        case .invalidCustodySignal:
            return "Invalid custody signal"
        case .invalidAdministrativeRecord:
            return "Invalid administrative record"
        case .invalidBundleStatusItem:
            return "Invalid bundle status item"
        case .invalidStatusReport:
            return "Invalid status report"
        case .invalidCanonicalBlock:
            return "Invalid canonical block"
        case .duplicateBlockNumber:
            return "Duplicate block number in a bundle"
        case .missingPayloadBlock:
            return "Missing payload block in a bundle"
        }
    }
}

/// Errors related to endpoint identifiers.
public enum EndpointIDError: Error, Equatable, CustomStringConvertible {
    /// The scheme is missing.
    case schemeMissing
    
    /// The scheme does not match the expected scheme.
    case schemeMismatch(found: UInt8, expected: UInt8)
    
    /// The node number is invalid.
    case invalidNodeNumber
    
    /// The service number is invalid.
    case invalidServiceNumber
    
    /// The SSP is invalid.
    case invalidSSP
    
    /// Could not parse the number from the string.
    case couldNotParseNumber(String)
    
    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .schemeMissing:
            return "Scheme is missing"
        case .schemeMismatch(let found, let expected):
            return "Scheme mismatch: found \(found), expected \(expected)"
        case .invalidNodeNumber:
            return "Invalid node number"
        case .invalidServiceNumber:
            return "Invalid service number"
        case .invalidSSP:
            return "Invalid SSP"
        case .couldNotParseNumber(let string):
            return "Could not parse number from string: \(string)"
        }
    }
}
