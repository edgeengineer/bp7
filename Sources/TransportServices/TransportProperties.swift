#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Represents the preference level for a given transport property.
public enum Preference: Sendable {
    case require
    case prefer
    case noPreference
    case avoid
    case prohibit
}

/// A collection of properties that specify application requirements and preferences for transport protocols and paths.
public struct TransportProperties: Sendable {
    private var properties: [String: AnySendable] = [:]

    public init() {
        // Set default values as per RFC 9622
        self.set(SelectionProperties.reliability, value: AnySendable(Preference.require))
        self.set(SelectionProperties.preserveOrder, value: AnySendable(Preference.require))
        self.set(SelectionProperties.preserveMsgBoundaries, value: AnySendable(Preference.noPreference))
        self.set(SelectionProperties.perMsgReliability, value: AnySendable(Preference.noPreference))
        self.set(SelectionProperties.zeroRttMsg, value: AnySendable(Preference.noPreference))
        self.set(SelectionProperties.multistreaming, value: AnySendable(Preference.prefer))
        self.set(SelectionProperties.fullChecksumSend, value: AnySendable(Preference.require))
        self.set(SelectionProperties.fullChecksumRecv, value: AnySendable(Preference.require))
        self.set(SelectionProperties.congestionControl, value: AnySendable(Preference.require))
        self.set(SelectionProperties.keepAlive, value: AnySendable(Preference.noPreference))
        self.set(SelectionProperties.useTemporaryLocalAddress, value: AnySendable(Preference.prefer))
        self.set(SelectionProperties.multipath, value: AnySendable(Multipath.disabled))
        self.set(SelectionProperties.advertisesAltaddr, value: AnySendable(false))
        self.set(SelectionProperties.direction, value: AnySendable(Direction.bidirectional))
        self.set(SelectionProperties.softErrorNotify, value: AnySendable(Preference.noPreference))
        self.set(SelectionProperties.activeReadBeforeSend, value: AnySendable(Preference.noPreference))
    }

    public mutating func set(_ key: String, value: AnySendable) {
        properties[key] = value
    }

    public func get<T>(_ key: String) -> T? {
        return properties[key]?.value as? T
    }

    public mutating func require(_ key: String) {
        set(key, value: AnySendable(Preference.require))
    }

    public mutating func prefer(_ key: String) {
        set(key, value: AnySendable(Preference.prefer))
    }

    public mutating func avoid(_ key: String) {
        set(key, value: AnySendable(Preference.avoid))
    }

    public mutating func prohibit(_ key: String) {
        set(key, value: AnySendable(Preference.prohibit))
    }
}

/// Defines the names for Selection Properties as specified in RFC 9622.
public struct SelectionProperties {
    public static let reliability = "reliability"
    public static let preserveMsgBoundaries = "preserveMsgBoundaries"
    public static let perMsgReliability = "perMsgReliability"
    public static let preserveOrder = "preserveOrder"
    public static let zeroRttMsg = "zeroRttMsg"
    public static let multistreaming = "multistreaming"
    public static let fullChecksumSend = "fullChecksumSend"
    public static let fullChecksumRecv = "fullChecksumRecv"
    public static let congestionControl = "congestionControl"
    public static let keepAlive = "keepAlive"
    public static let interface = "interface"
    public static let pvd = "pvd"
    public static let useTemporaryLocalAddress = "useTemporaryLocalAddress"
    public static let multipath = "multipath"
    public static let advertisesAltaddr = "advertisesAltaddr"
    public static let direction = "direction"
    public static let softErrorNotify = "softErrorNotify"
    public static let activeReadBeforeSend = "activeReadBeforeSend"
}

public enum Multipath: Sendable {
    case disabled
    case active
    case passive
}

public enum Direction: Sendable {
    case bidirectional
    case unidirectionalSend
    case unidirectionalReceive
}