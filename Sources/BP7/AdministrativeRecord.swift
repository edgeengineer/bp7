import CBOR

/// Type code for administrative records
public typealias AdministrativeRecordTypeCode = UInt32

/// Represents an administrative record in a bundle
public enum AdministrativeRecord: Equatable, Hashable, Sendable {
    /// Bundle status report type code
    public static let BUNDLE_STATUS_REPORT_TYPE_CODE: AdministrativeRecordTypeCode = 1
    
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
                .unsignedInt(UInt64(AdministrativeRecord.BUNDLE_STATUS_REPORT_TYPE_CODE)),
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
        
        if code == AdministrativeRecord.BUNDLE_STATUS_REPORT_TYPE_CODE {
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
                blockType: BlockType.payload.rawValue,
                blockNumber: 1,
                blockControlFlags: 0,
                crc: .crcNo,
                data: .data(data)
            )
        } catch {
            // Return empty payload if encoding fails
            return CanonicalBlock(
                blockType: BlockType.payload.rawValue,
                blockNumber: 1,
                blockControlFlags: 0,
                crc: .crcNo,
                data: .data([])
            )
        }
    }
}

/// Reason codes for bundle status reports
public typealias StatusReportReasonCode = UInt32

/// Reason codes for bundle status reports
public enum StatusReportReason: Equatable, Hashable, Sendable, RawRepresentable {
    /// No additional information
    case noInformation
    
    /// Lifetime expired
    case lifetimeExpired
    
    /// Forwarded over unidirectional link
    case forwardUnidirectionalLink
    
    /// Transmission canceled
    case transmissionCanceled
    
    /// Depleted storage
    case depletedStorage
    
    /// Destination endpoint ID unavailable
    case destEndpointUnintelligible
    
    /// No known route to destination from here
    case noRouteToDestination
    
    /// No timely contact with next node on route
    case noNextNodeContact
    
    /// Block unintelligible
    case blockUnintelligible
    
    /// Hop limit exceeded
    case hopLimitExceeded
    
    /// Traffic pared
    case trafficPared
    
    /// Block unsupported
    case blockUnsupported
    
    /// Custom reason code
    case custom(StatusReportReasonCode)
    
    /// The raw type that can be used to represent all values of the conforming
    /// type.
    public typealias RawValue = StatusReportReasonCode
    
    /// Creates a new instance with the specified raw value.
    ///
    /// - Parameter rawValue: The raw value to use for the new instance.
    public init?(rawValue: StatusReportReasonCode) {
        switch rawValue {
        case 0: self = .noInformation
        case 1: self = .lifetimeExpired
        case 2: self = .forwardUnidirectionalLink
        case 3: self = .transmissionCanceled
        case 4: self = .depletedStorage
        case 5: self = .destEndpointUnintelligible
        case 6: self = .noRouteToDestination
        case 7: self = .noNextNodeContact
        case 8: self = .blockUnintelligible
        case 9: self = .hopLimitExceeded
        case 10: self = .trafficPared
        case 11: self = .blockUnsupported
        default: self = .custom(rawValue)
        }
    }
    
    /// The corresponding value of the raw type.
    public var rawValue: StatusReportReasonCode {
        switch self {
        case .noInformation: return 0
        case .lifetimeExpired: return 1
        case .forwardUnidirectionalLink: return 2
        case .transmissionCanceled: return 3
        case .depletedStorage: return 4
        case .destEndpointUnintelligible: return 5
        case .noRouteToDestination: return 6
        case .noNextNodeContact: return 7
        case .blockUnintelligible: return 8
        case .hopLimitExceeded: return 9
        case .trafficPared: return 10
        case .blockUnsupported: return 11
        case .custom(let code): return code
        }
    }
}

/// Bundle status item, used in the bundle status information array
public struct BundleStatusItem: Equatable, Hashable, Sendable {
    /// Whether the status is asserted
    public let asserted: Bool
    
    /// Time of the status
    public let time: DisruptionTolerantNetworkingTime
    
    /// Whether status time was requested
    public let statusRequested: Bool
    
    /// Create a new bundle status item
    public init(asserted: Bool, time: DisruptionTolerantNetworkingTime = 0, statusRequested: Bool = false) {
        self.asserted = asserted
        self.time = time
        self.statusRequested = statusRequested
    }
    
    /// Convenience initializer for a new bundle status item with the given assertion status
    public init(asserted: Bool) {
        self.init(asserted: asserted, time: 0, statusRequested: false)
    }
    
    /// Convenience initializer for a new time reporting bundle status item
    public init(timeReporting time: DisruptionTolerantNetworkingTime) {
        self.init(asserted: true, time: time, statusRequested: true)
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
        var time: DisruptionTolerantNetworkingTime = 0
        
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

/// Status information position in a status report
public typealias StatusInformationPosCode = UInt32

/// Status information position in a status report
public enum StatusInformationPos: StatusInformationPosCode, Equatable, Hashable, Sendable, CaseIterable {
    /// Maximum number of status information positions
    public static let maxPositions: StatusInformationPosCode = 4
    
    /// Indicating the reporting node received this bundle
    case receivedBundle = 0
    
    /// Indicating the reporting node forwarded this bundle
    case forwardedBundle = 1
    
    /// Indicating the reporting node delivered this bundle
    case deliveredBundle = 2
    
    /// Indicating the reporting node deleted this bundle
    case deletedBundle = 3
    
    /// All possible cases
    public static var allCases: [StatusInformationPos] {
        return [.receivedBundle, .forwardedBundle, .deliveredBundle, .deletedBundle]
    }
}

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
    
    /// Fragment length (if bundle is fragmented)
    public let fragLen: UInt64
    
    /// Create a status report with the given parameters
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
    
    /// Create a new status report for the given bundle
    public init(
        bundle: Bundle,
        statusItem: StatusInformationPos,
        reason: StatusReportReason
    ) {
        var statusInformation: [BundleStatusItem] = []
        
        // Create status information array
        for i in 0..<StatusInformationPos.maxPositions {
            if i == statusItem.rawValue && bundle.primary.bundleControlFlags.contains(.bundleRequestStatusTime) {
                statusInformation.append(BundleStatusItem(timeReporting: DisruptionTolerantNetworkingTime.now()))
            } else if i == statusItem.rawValue {
                statusInformation.append(BundleStatusItem(asserted: true))
            } else {
                statusInformation.append(BundleStatusItem(asserted: false))
            }
        }
        
        // Set basic properties
        self.statusInformation = statusInformation
        self.reportReason = reason
        self.sourceNode = bundle.primary.source
        self.timestamp = bundle.primary.creationTimestamp
        
        // Add fragmentation information if present
        if bundle.primary.hasFragmentation {
            self.fragOffset = bundle.primary.fragmentationOffset
            self.fragLen = bundle.primary.totalDataLength
        } else {
            self.fragOffset = 0
            self.fragLen = 0
        }
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
        items.append(.unsignedInt(UInt64(reportReason.rawValue)))
        
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
        let reasonCode = StatusReportReasonCode(reasonValue)
        let reportReason = StatusReportReason(rawValue: reasonCode) ?? .custom(reasonCode)
        
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
    
    /// Create a new bundle containing a status report
    public static func newBundle(
        origBundle: Bundle,
        source: EndpointID,
        crcType: CrcValue,
        status: StatusInformationPos,
        reason: StatusReportReason
    ) -> Bundle {
        // Create status report
        let statusReport = StatusReport(
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
}
