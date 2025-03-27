#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CBOR

/// Type code for administrative records
public typealias AdministrativeRecordTypeCode = UInt32

/// Bundle status report type code
public let BUNDLE_STATUS_REPORT_TYPE_CODE: AdministrativeRecordTypeCode = 1

/// Represents an administrative record in a bundle
public enum AdministrativeRecord: Equatable, Hashable, Sendable {
    /// Bundle status report
    case bundleStatusReport(StatusReport)
    
    /// Unknown administrative record type
    case unknown(AdministrativeRecordTypeCode, [UInt8])
    
    /// Mismatched administrative record type
    case mismatched(AdministrativeRecordTypeCode, [UInt8])
    
    /// Convert the administrative record to CBOR format
    public func encode() throws -> CBOR {
        switch self {
        case .bundleStatusReport(let statusReport):
            return .array([
                .unsignedInt(UInt64(BUNDLE_STATUS_REPORT_TYPE_CODE)),
                try statusReport.encode()
            ])
        case .unknown(let code, let data), .mismatched(let code, let data):
            return .array([
                .unsignedInt(UInt64(code)),
                .byteString(data)
            ])
        }
    }
    
    /// Decode an administrative record from CBOR format
    public static func decode(from cbor: CBOR) throws -> AdministrativeRecord {
        guard case .array(let items) = cbor, items.count >= 2 else {
            throw BP7Error.invalidAdministrativeRecord
        }
        
        guard case .unsignedInt(let codeValue) = items[0] else {
            throw BP7Error.invalidAdministrativeRecord
        }
        
        let code = AdministrativeRecordTypeCode(codeValue)
        
        if code == BUNDLE_STATUS_REPORT_TYPE_CODE {
            let statusReport = try StatusReport.decode(from: items[1])
            return .bundleStatusReport(statusReport)
        } else {
            guard case .byteString(let data) = items[1] else {
                throw BP7Error.invalidAdministrativeRecord
            }
            return .unknown(code, data)
        }
    }
    
    /// Convert the administrative record to a payload block
    public func toPayload() -> CanonicalBlock {
        do {
            let data = try encode().encode()
            return CanonicalBlock(
                blockType: PAYLOAD_BLOCK,
                blockNumber: 1,
                blockControlFlags: 0,
                crc: .crcNo,
                data: .data(data)
            )
        } catch {
            // Return empty payload if encoding fails
            return CanonicalBlock(
                blockType: PAYLOAD_BLOCK,
                blockNumber: 1,
                blockControlFlags: 0,
                crc: .crcNo,
                data: .data([])
            )
        }
    }
}

/// Reason codes for bundle status reports
public typealias StatusReportReason = UInt32

/// No additional information
public let NO_INFORMATION: StatusReportReason = 0

/// Lifetime expired
public let LIFETIME_EXPIRED: StatusReportReason = 1

/// Forwarded over unidirectional link
public let FORWARD_UNIDIRECTIONAL_LINK: StatusReportReason = 2

/// Transmission canceled
public let TRANSMISSION_CANCELED: StatusReportReason = 3

/// Depleted storage
public let DEPLETED_STORAGE: StatusReportReason = 4

/// Destination endpoint ID unavailable
public let DEST_ENDPOINT_UNINTELLIGIBLE: StatusReportReason = 5

/// No known route to destination from here
public let NO_ROUTE_TO_DESTINATION: StatusReportReason = 6

/// No timely contact with next node on route
public let NO_NEXT_NODE_CONTACT: StatusReportReason = 7

/// Block unintelligible
public let BLOCK_UNINTELLIGIBLE: StatusReportReason = 8

/// Hop limit exceeded
public let HOP_LIMIT_EXCEEDED: StatusReportReason = 9

/// Traffic pared
public let TRAFFIC_PARED: StatusReportReason = 10

/// Block unsupported
public let BLOCK_UNSUPPORTED: StatusReportReason = 11

/// Bundle status item, used in the bundle status information array
public struct BundleStatusItem: Equatable, Hashable, Sendable {
    /// Whether the status is asserted
    public let asserted: Bool
    
    /// Time of the status
    public let time: DtnTime
    
    /// Whether status time was requested
    public let statusRequested: Bool
    
    /// Create a new bundle status item
    public init(asserted: Bool, time: DtnTime = 0, statusRequested: Bool = false) {
        self.asserted = asserted
        self.time = time
        self.statusRequested = statusRequested
    }
    
    /// Convert the bundle status item to CBOR format
    public func encode() -> CBOR {
        if asserted && statusRequested {
            return .array([.bool(asserted), .unsignedInt(time)])
        } else {
            return .array([.bool(asserted)])
        }
    }
    
    /// Decode a bundle status item from CBOR format
    public static func decode(from cbor: CBOR) throws -> BundleStatusItem {
        guard case .array(let items) = cbor, !items.isEmpty else {
            throw BP7Error.invalidBundleStatusItem
        }
        
        guard case .bool(let asserted) = items[0] else {
            throw BP7Error.invalidBundleStatusItem
        }
        
        var statusRequested = false
        var time: DtnTime = 0
        
        if items.count > 1 && asserted {
            statusRequested = true
            guard case .unsignedInt(let timeValue) = items[1] else {
                throw BP7Error.invalidBundleStatusItem
            }
            time = timeValue
        }
        
        return BundleStatusItem(
            asserted: asserted,
            time: time,
            statusRequested: statusRequested
        )
    }
}

/// Create a new bundle status item with the given assertion status
public func newBundleStatusItem(asserted: Bool) -> BundleStatusItem {
    return BundleStatusItem(asserted: asserted)
}

/// Create a new time reporting bundle status item
public func newTimeReportingBundleStatusItem(time: DtnTime) -> BundleStatusItem {
    return BundleStatusItem(asserted: true, time: time, statusRequested: true)
}

/// Status information position in a status report
public typealias StatusInformationPos = UInt32

/// Maximum number of status information positions
public let MAX_STATUS_INFORMATION_POS: UInt32 = 4

/// Indicating the reporting node received this bundle
public let RECEIVED_BUNDLE: StatusInformationPos = 0

/// Indicating the reporting node forwarded this bundle
public let FORWARDED_BUNDLE: StatusInformationPos = 1

/// Indicating the reporting node delivered this bundle
public let DELIVERED_BUNDLE: StatusInformationPos = 2

/// Indicating the reporting node deleted this bundle
public let DELETED_BUNDLE: StatusInformationPos = 3

/// Bundle status report
public struct StatusReport: Equatable, Hashable, Sendable {
    /// Status information array
    public let statusInformation: [BundleStatusItem]
    
    /// Reason for the status report
    public let reportReason: StatusReportReason
    
    /// Source node of the original bundle
    public let sourceNode: EndpointID
    
    /// Timestamp of the original bundle
    public let timestamp: CreationTimestamp
    
    /// Fragmentation offset (if bundle is fragmented)
    public let fragOffset: UInt64
    
    /// Fragmentation length (if bundle is fragmented)
    public let fragLen: UInt64
    
    /// Create a new status report
    public init(
        statusInformation: [BundleStatusItem],
        reportReason: StatusReportReason,
        sourceNode: EndpointID,
        timestamp: CreationTimestamp,
        fragOffset: UInt64 = 0,
        fragLen: UInt64 = 0
    ) {
        self.statusInformation = statusInformation
        self.reportReason = reportReason
        self.sourceNode = sourceNode
        self.timestamp = timestamp
        self.fragOffset = fragOffset
        self.fragLen = fragLen
    }
    
    /// Get a reference string for the bundle
    public func refBundle() -> String {
        var id = "\(sourceNode)-\(timestamp.getDtnTime())-\(timestamp.getSequenceNumber())"
        if fragLen > 0 {
            id = "\(id)-\(fragOffset)"
        }
        return id
    }
    
    /// Convert the status report to CBOR format
    public func encode() throws -> CBOR {
        var items: [CBOR] = []
        
        // Add status information array
        let statusItems = statusInformation.map { $0.encode() }
        items.append(.array(statusItems))
        
        // Add report reason
        items.append(.unsignedInt(UInt64(reportReason)))
        
        // Add source node
        items.append(try sourceNode.encode())
        
        // Add timestamp
        items.append(.array([
            .unsignedInt(timestamp.getDtnTime()),
            .unsignedInt(timestamp.getSequenceNumber())
        ]))
        
        // Add fragmentation information if present
        if fragLen != 0 {
            items.append(.unsignedInt(fragOffset))
            items.append(.unsignedInt(fragLen))
        }
        
        return .array(items)
    }
    
    /// Decode a status report from CBOR format
    public static func decode(from cbor: CBOR) throws -> StatusReport {
        guard case .array(let items) = cbor, items.count >= 4 else {
            throw BP7Error.invalidStatusReport
        }
        
        // Decode status information
        guard case .array(let statusItems) = items[0] else {
            throw BP7Error.invalidStatusReport
        }
        
        let statusInformation = try statusItems.map { try BundleStatusItem.decode(from: $0) }
        
        // Decode report reason
        guard case .unsignedInt(let reasonValue) = items[1] else {
            throw BP7Error.invalidStatusReport
        }
        let reportReason = StatusReportReason(reasonValue)
        
        // Decode source node
        let sourceNode = try EndpointID(from: items[2])
        
        // Decode timestamp
        guard case .array(let timestampArray) = items[3],
              timestampArray.count == 2,
              case .unsignedInt(let dtnTime) = timestampArray[0],
              case .unsignedInt(let seqNo) = timestampArray[1] else {
            throw BP7Error.invalidStatusReport
        }
        
        let timestamp = CreationTimestamp(time: dtnTime, sequenceNumber: seqNo)
        
        // Decode fragmentation information if present
        var fragOffset: UInt64 = 0
        var fragLen: UInt64 = 0
        
        if items.count > 4 {
            guard items.count >= 6,
                  case .unsignedInt(let offset) = items[4],
                  case .unsignedInt(let length) = items[5] else {
                throw BP7Error.invalidStatusReport
            }
            fragOffset = offset
            fragLen = length
        }
        
        return StatusReport(
            statusInformation: statusInformation,
            reportReason: reportReason,
            sourceNode: sourceNode,
            timestamp: timestamp,
            fragOffset: fragOffset,
            fragLen: fragLen
        )
    }
}

/// Create a new status report for the given bundle
public func newStatusReport(
    bundle: Bundle,
    statusItem: StatusInformationPos,
    reason: StatusReportReason
) -> StatusReport {
    var statusInformation: [BundleStatusItem] = []
    
    // Create status information array
    for i in 0..<MAX_STATUS_INFORMATION_POS {
        if i == statusItem && bundle.primary.bundleControlFlags.contains(.bundleRequestStatusTime) {
            statusInformation.append(newTimeReportingBundleStatusItem(time: DtnTime.now()))
        } else if i == statusItem {
            statusInformation.append(newBundleStatusItem(asserted: true))
        } else {
            statusInformation.append(newBundleStatusItem(asserted: false))
        }
    }
    
    // Create status report
    var sr = StatusReport(
        statusInformation: statusInformation,
        reportReason: reason,
        sourceNode: bundle.primary.source,
        timestamp: bundle.primary.creationTimestamp,
        fragOffset: 0,
        fragLen: 0
    )
    
    // Add fragmentation information if present
    if bundle.primary.hasFragmentation {
        // TODO: Add fragmentation support
        // For now, we'll just use the values from the primary block
        sr = StatusReport(
            statusInformation: statusInformation,
            reportReason: reason,
            sourceNode: bundle.primary.source,
            timestamp: bundle.primary.creationTimestamp,
            fragOffset: bundle.primary.fragmentationOffset,
            fragLen: bundle.primary.totalDataLength
        )
    }
    
    return sr
}

/// Create a new bundle containing a status report
public func newStatusReportBundle(
    origBundle: Bundle,
    source: EndpointID,
    crcType: CrcValue,
    status: StatusInformationPos,
    reason: StatusReportReason
) -> Bundle {
    // Create status report
    let statusReport = newStatusReport(
        bundle: origBundle,
        statusItem: status,
        reason: reason
    )
    
    // Create administrative record
    let admRecord = AdministrativeRecord.bundleStatusReport(statusReport)
    
    // Create primary block
    let primaryBlock = try! PrimaryBlockBuilder()
        .destination(origBundle.primary.reportTo)
        .source(source)
        .reportTo(source)
        .bundleControlFlags([.bundleAdministrativeRecordPayload])
        .creationTimestamp(CreationTimestamp())
        .lifetime(origBundle.primary.lifetime)
        .crc(crcType)
        .build()
    
    // Create bundle
    var bundle = Bundle(
        primary: primaryBlock,
        canonicals: [admRecord.toPayload()]
    )
    
    // Set CRC if needed
    if crcType != .crcNo {
        bundle.setCrc(crcType)
    }
    
    return bundle
}
