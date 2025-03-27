// Import the appropriate Foundation modules based on platform availability
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Time since the year 2k in milliseconds
public typealias DtnTime = UInt64

/// Constants for DTN time calculations
public enum DtnTimeConstants {
    /// Seconds from January 1, 1970 to January 1, 2000
    public static let SECONDS1970_TO2K: UInt64 = 946_684_800
    
    /// Milliseconds from January 1, 1970 to January 1, 2000
    public static let MS1970_TO2K: UInt64 = 946_684_800_000
    
    /// DTN time epoch (January 1, 2000)
    public static let DTN_TIME_EPOCH: DtnTime = 0
}

/// Extension to add helper methods to DtnTime
public extension DtnTime {
    /// Convert DTN time to Unix timestamp (in seconds)
    func toUnixTimestamp() -> UInt64 {
        return (self + DtnTimeConstants.MS1970_TO2K) / 1000
    }
    
    /// Convert DTN time to a human-readable RFC3339 compliant time string
    func toRFC3339String() -> String {
        let timeInterval = TimeInterval((self + DtnTimeConstants.MS1970_TO2K) / 1000)
        let date = Date(timeIntervalSince1970: timeInterval)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    /// Get current time as DtnTime timestamp
    static func now() -> DtnTime {
        let currentTimeMillis = UInt64(Date().timeIntervalSince1970 * 1000)
        return currentTimeMillis - DtnTimeConstants.MS1970_TO2K
    }
}

/// Timestamp when a bundle was created, consisting of the DtnTime and a sequence number
public struct CreationTimestamp: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// The DTN time when the bundle was created
    private let time: DtnTime
    
    /// Sequence number to distinguish bundles created at the same time
    private let sequenceNumber: UInt64
    
    /// Create a new timestamp with the given time and sequence number
    public init(time: DtnTime, sequenceNumber: UInt64) {
        self.time = time
        self.sequenceNumber = sequenceNumber
    }
    
    /// Create a new timestamp with the current time and a sequence number of 0
    public init() {
        self.time = DtnTime.now()
        self.sequenceNumber = 0
    }
    
    /// Get the DTN time component
    public func getDtnTime() -> DtnTime {
        return time
    }
    
    /// Get the sequence number component
    public func getSequenceNumber() -> UInt64 {
        return sequenceNumber
    }
    
    /// Human-readable description of the timestamp
    public var description: String {
        return "\(time.toRFC3339String()) \(sequenceNumber)"
    }
    
    // Thread-safe timestamp generators
    private static let syncSequenceGenerator = SyncSequenceGenerator()
    private static let asyncSequenceGenerator = AsyncSequenceGenerator()
    
    /// Create a new timestamp with the current time and automatic sequence counting
    public static func now() -> CreationTimestamp {
        let currentTime = DtnTime.now()
        let sequenceNumber = syncSequenceGenerator.nextSequence(for: currentTime)
        return CreationTimestamp(time: currentTime, sequenceNumber: sequenceNumber)
    }
    
    /// Asynchronous version that uses the actor for better concurrency
    public static func nowAsync() async -> CreationTimestamp {
        let currentTime = DtnTime.now()
        let sequenceNumber = await asyncSequenceGenerator.nextSequence(for: currentTime)
        return CreationTimestamp(time: currentTime, sequenceNumber: sequenceNumber)
    }
}

// MARK: - Thread-safe Sequence Generator (Synchronous version)
/// A class to generate sequence numbers in a thread-safe manner
final class SyncSequenceGenerator: @unchecked Sendable {
    // Using a dispatch queue for synchronization - works on all platforms
    private let queue = DispatchQueue(label: "com.bp7.dtntime.sequence")
    private var lastTimestamp: DtnTime = 0
    private var lastSequence: UInt64 = 0
    
    func nextSequence(for timestamp: DtnTime) -> UInt64 {
        return queue.sync {
            if timestamp != lastTimestamp {
                lastTimestamp = timestamp
                lastSequence = 0
            } else {
                lastSequence += 1
            }
            
            return lastSequence
        }
    }
}

// MARK: - Thread-safe Sequence Generator (Asynchronous version)
/// An actor to generate sequence numbers in a thread-safe manner
actor AsyncSequenceGenerator {
    private var lastTimestamp: DtnTime = 0
    private var lastSequence: UInt64 = 0
    
    func nextSequence(for timestamp: DtnTime) -> UInt64 {
        if timestamp != lastTimestamp {
            lastTimestamp = timestamp
            lastSequence = 0
        } else {
            lastSequence += 1
        }
        
        return lastSequence
    }
}

// MARK: - Codable Implementation
extension CreationTimestamp: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        time = try container.decode(DtnTime.self)
        sequenceNumber = try container.decode(UInt64.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(time)
        try container.encode(sequenceNumber)
    }
}
