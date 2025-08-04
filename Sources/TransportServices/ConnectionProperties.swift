
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Defines the names for Connection Properties as specified in RFC 9622, Section 8.1.
public struct ConnectionProperties {
    /// The minimum coverage for corruption protection for receiving data.
    public static let requiredMinReceiverChecksumCoverage = "requiredMinReceiverChecksumCoverage"
    
    /// The priority of the connection within a Connection Group.
    public static let priority = "priority"
    
    /// The timeout for aborting the connection due to inactivity.
    public static let timeoutForAbort = "timeoutForAbort"
    
    /// The timeout for sending keep-alive packets.
    public static let timeoutForKeepAlive = "timeoutForKeepAlive"
    
    /// The scheduler for a Connection Group.
    public static let groupScheduler = "groupScheduler"
    
    /// The capacity profile for the connection.
    public static let capacityProfile = "capacityProfile"
    
    /// The policy for using multipath transports.
    public static let multipathPolicy = "multipathPolicy"
    
    /// The bounds on the send or receive rate.
    public static let boundsOnSendReceiveRate = "boundsOnSendReceiveRate"
    
    /// The limit on the number of connections in a group.
    public static let groupConnectionLimit = "groupConnectionLimit"
    
    /// Whether to isolate the session from caches.
    public static let isolateSession = "isolateSession"
}

// Enums for Connection Properties

public enum CapacityProfile: Sendable {
    case defaultProfile
    case lowLatency
    case lowPower
    case highThroughput
}

public enum MultipathPolicy: Sendable {
    case handover
    case interactive
    case aggregate
}
