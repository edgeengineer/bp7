#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Encapsulates properties and metadata associated with a single message, either for sending or receiving.
public struct MessageContext: Sendable {
    private var properties: [String: AnySendable]

    public init() {
        self.properties = [:]
    }

    /// Sets a generic message property.
    public mutating func set(_ key: String, value: AnySendable) {
        properties[key] = value
    }

    /// Retrieves the value for a given property key.
    public func get<T>(_ key: String) -> T? {
        return properties[key]?.value as? T
    }

    /// A convenience property for accessing the message's lifetime.
    public var lifetime: TimeInterval? {
        mutating get {
            get(MessageProperties.lifetime)
        }
        set {
            set(MessageProperties.lifetime, value: AnySendable(newValue))
        }
    }

    /// A convenience property to mark a message as final.
    public var isFinal: Bool {
        mutating get {
            get(MessageProperties.isFinal) ?? false
        }
        set {
            set(MessageProperties.isFinal, value: AnySendable(newValue))
        }
    }
    
    /// A convenience property to allow batching of messages.
    public var allowBatching: Bool {
        mutating get {
            get(MessageProperties.allowBatching) ?? true
        }
        set {
            set(MessageProperties.allowBatching, value: AnySendable(newValue))
        }
    }
}

/// A type-erased wrapper to allow storing `Sendable` values of any type in a dictionary.
public struct AnySendable: Sendable {
    public let value: any Sendable
    public init(_ value: (any Sendable)?) {
        self.value = value ?? ()
    }
}

/// Defines the names for Message Properties.
public struct MessageProperties {
    public static let lifetime = "msgLifetime"
    public static let priority = "msgPriority"
    public static let isFinal = "isFinal"
    public static let isIdempotent = "isIdempotent"
    public static let allowBatching = "allowBatching"
}