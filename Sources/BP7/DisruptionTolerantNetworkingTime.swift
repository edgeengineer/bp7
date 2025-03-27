// Import the appropriate Foundation modules based on platform availability
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Import Dispatch conditionally
#if canImport(Dispatch)
import Dispatch
#endif

// Import system libraries based on platform
#if os(Linux)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

/// Time since the year 2k in milliseconds
public typealias DisruptionTolerantNetworkingTime = UInt64

/// Constants for DTN time calculations
public enum DisruptionTolerantNetworkingTimeConstants {
    /// Seconds from January 1, 1970 to January 1, 2000
    public static let SECONDS1970_TO2K: UInt64 = 946_684_800
    
    /// Milliseconds from January 1, 1970 to January 1, 2000
    public static let MS1970_TO2K: UInt64 = 946_684_800_000
    
    /// DTN time epoch (January 1, 2000)
    public static let DTN_TIME_EPOCH: DisruptionTolerantNetworkingTime = 0
}

/// Extension to add helper methods to DisruptionTolerantNetworkingTime
public extension DisruptionTolerantNetworkingTime {
    /// Convert DTN time to Unix timestamp (in seconds)
    func toUnixTimestamp() -> UInt64 {
        return (self + DisruptionTolerantNetworkingTimeConstants.MS1970_TO2K) / 1000
    }
    
    /// Convert DTN time to a human-readable RFC3339 compliant time string
    func toRFC3339String() -> String {
        let timeInterval = TimeInterval((self + DisruptionTolerantNetworkingTimeConstants.MS1970_TO2K) / 1000)
        let date = Date(timeIntervalSince1970: timeInterval)
        
        #if os(Linux)
        // Simple ISO8601 formatter for Linux - manual implementation
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let milliseconds = (components.nanosecond ?? 0) / 1_000_000
        
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", 
                     year, month, day, hour, minute, second, milliseconds)
        #elseif os(Windows)
        // Simple ISO8601 formatter for Windows - manual implementation
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let milliseconds = (components.nanosecond ?? 0) / 1_000_000
        
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", 
                     year, month, day, hour, minute, second, milliseconds)
        #else
        // Use ISO8601DateFormatter on Apple platforms
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
        #endif
    }
    
    /// Convert DTN time to a Swift Date object
    func toDate() -> Date {
        let timeInterval = TimeInterval((self + DisruptionTolerantNetworkingTimeConstants.MS1970_TO2K) / 1000)
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    /// Get current time as DisruptionTolerantNetworkingTime timestamp
    static func now() -> DisruptionTolerantNetworkingTime {
        let currentTimeMillis = UInt64(Date().timeIntervalSince1970 * 1000)
        return currentTimeMillis - DisruptionTolerantNetworkingTimeConstants.MS1970_TO2K
    }
    
    /// Create a DisruptionTolerantNetworkingTime from a Swift Date object
    static func from(date: Date) -> DisruptionTolerantNetworkingTime {
        let millisSince1970 = UInt64(date.timeIntervalSince1970 * 1000)
        return millisSince1970 - DisruptionTolerantNetworkingTimeConstants.MS1970_TO2K
    }
}

/// Timestamp when a bundle was created, consisting of the DisruptionTolerantNetworkingTime and a sequence number
public struct CreationTimestamp: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// The DTN time when the bundle was created
    private let time: DisruptionTolerantNetworkingTime
    
    /// Sequence number to distinguish bundles created at the same time
    private let sequenceNumber: UInt64
    
    /// Create a new timestamp with the given time and sequence number
    public init(time: DisruptionTolerantNetworkingTime, sequenceNumber: UInt64) {
        self.time = time
        self.sequenceNumber = sequenceNumber
    }
    
    /// Create a new timestamp with the current time and a sequence number of 0
    public init() {
        self.time = DisruptionTolerantNetworkingTime.now()
        self.sequenceNumber = 0
    }
    
    /// Get the DTN time component
    public func getDtnTime() -> DisruptionTolerantNetworkingTime {
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
    
    /// Convert the timestamp to a Date object (using only the time component)
    public func toDate() -> Date {
        return time.toDate()
    }
    
    /// Create a timestamp from a Date object with a specified sequence number
    public static func from(date: Date, sequenceNumber: UInt64 = 0) -> CreationTimestamp {
        let dtnTime = DisruptionTolerantNetworkingTime.from(date: date)
        return CreationTimestamp(time: dtnTime, sequenceNumber: sequenceNumber)
    }
    
    // Thread-safe timestamp generators
    private static let syncSequenceGenerator = SyncSequenceGenerator()
    private static let asyncSequenceGenerator = AsyncSequenceGenerator()
    
    /// Create a new timestamp with the current time and automatic sequence counting
    public static func now() -> CreationTimestamp {
        let currentTime = DisruptionTolerantNetworkingTime.now()
        let sequenceNumber = syncSequenceGenerator.nextSequence(for: currentTime)
        return CreationTimestamp(time: currentTime, sequenceNumber: sequenceNumber)
    }
    
    /// Asynchronous version that uses the actor for better concurrency
    public static func nowAsync() async -> CreationTimestamp {
        let currentTime = DisruptionTolerantNetworkingTime.now()
        let sequenceNumber = await asyncSequenceGenerator.nextSequence(for: currentTime)
        return CreationTimestamp(time: currentTime, sequenceNumber: sequenceNumber)
    }
}

// MARK: - Thread-safe Sequence Generator (Synchronous version)
/// A class to generate sequence numbers in a thread-safe manner
final class SyncSequenceGenerator: @unchecked Sendable {
    #if canImport(Dispatch) && !os(Linux) && !os(Windows)
    // Using a dispatch queue for synchronization on Apple platforms
    private let queue = DispatchQueue(label: "com.bp7.dtntime.sequence")
    private var lastTimestamp: DisruptionTolerantNetworkingTime = 0
    private var lastSequence: UInt64 = 0
    
    func nextSequence(for timestamp: DisruptionTolerantNetworkingTime) -> UInt64 {
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
    #elseif os(Linux)
    // Thread-safe implementation for Linux using a simple mutex
    private var mutex = pthread_mutex_t()
    private var lastTimestamp: DisruptionTolerantNetworkingTime = 0
    private var lastSequence: UInt64 = 0
    
    init() {
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func nextSequence(for timestamp: DisruptionTolerantNetworkingTime) -> UInt64 {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        if timestamp != lastTimestamp {
            lastTimestamp = timestamp
            lastSequence = 0
        } else {
            lastSequence += 1
        }
        
        return lastSequence
    }
    #elseif os(Windows)
    // Thread-safe implementation for Windows using SRWLOCK
    private var lock = SRWLOCK()
    private var lastTimestamp: DisruptionTolerantNetworkingTime = 0
    private var lastSequence: UInt64 = 0
    
    init() {
        InitializeSRWLock(&lock)
    }
    
    func nextSequence(for timestamp: DisruptionTolerantNetworkingTime) -> UInt64 {
        AcquireSRWLockExclusive(&lock)
        defer { ReleaseSRWLockExclusive(&lock) }
        
        if timestamp != lastTimestamp {
            lastTimestamp = timestamp
            lastSequence = 0
        } else {
            lastSequence += 1
        }
        
        return lastSequence
    }
    #endif
}

// MARK: - Thread-safe Sequence Generator (Asynchronous version)
/// An actor to generate sequence numbers in a thread-safe manner
actor AsyncSequenceGenerator {
    private var lastTimestamp: DisruptionTolerantNetworkingTime = 0
    private var lastSequence: UInt64 = 0
    
    func nextSequence(for timestamp: DisruptionTolerantNetworkingTime) -> UInt64 {
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
    /// Implements `Decodable` protocol to deserialize a `CreationTimestamp` from encoded data.
    ///
    /// - Parameter decoder: The decoder to read data from.
    ///
    /// - Throws: `DecodingError` if reading fails due to missing or invalid data.
    ///
    /// - Discussion: This implementation uses an unkeyed container because `CreationTimestamp` 
    /// is serialized as an ordered array of values rather than a keyed dictionary.
    /// This format is consistent with the Bundle Protocol 7 (BP7) specification,
    /// which requires timestamps to be encoded as a compact array of [time, sequenceNumber]
    /// for efficient transmission in constrained networking environments.
    ///
    /// The unkeyed container approach allows for:
    /// - Smaller encoded size compared to keyed encoding
    /// - Compatibility with CBOR and other compact binary formats
    /// - Interoperability with other BP7 implementations
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        time = try container.decode(DisruptionTolerantNetworkingTime.self)
        sequenceNumber = try container.decode(UInt64.self)
    }
    
    /// Implements `Encodable` protocol to serialize a `CreationTimestamp` to encoded data.
    ///
    /// - Parameter encoder: The encoder to write data to.
    ///
    /// - Throws: `EncodingError` if encoding fails for any reason.
    ///
    /// - Discussion: This implementation encodes the timestamp as an ordered array
    /// of [time, sequenceNumber] without keys, resulting in a compact representation
    /// suitable for DTN networks where bandwidth may be limited.
    ///
    /// The encoding format aligns with the BP7 specification's requirement for
    /// efficient binary representation of bundle metadata. When encoded to CBOR
    /// (Concise Binary Object Representation), this produces a minimal byte sequence
    /// that can be efficiently transmitted and processed by DTN nodes.
    ///
    /// This approach is particularly important for:
    /// - Minimizing overhead in delay-tolerant networks
    /// - Ensuring compatibility with other BP7 implementations
    /// - Supporting efficient processing on resource-constrained devices
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(time)
        try container.encode(sequenceNumber)
    }
}
