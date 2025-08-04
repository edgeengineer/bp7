#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOSSL

/// Encapsulates security parameters for a connection.
public struct SecurityParameters: Sendable {
    public typealias Certificate = Any
    public typealias PrivateKey = Any
    public typealias PreSharedKey = Any
    public typealias TrustVerificationCallback = @Sendable (Certificate) -> Bool
    public typealias IdentityChallengeCallback = @Sendable () -> Void

    private var parameters: [String: AnySendable] = [:]

    public init() {}

    public static func newDisabled() -> SecurityParameters {
        var params = SecurityParameters()
        params.set(protocol: nil)
        return params
    }
    
    /// Check if encryption is required
    public var requiresEncryption: Bool {
        // If no allowed protocols, encryption is disabled
        guard let protocols = parameters["allowedSecurityProtocols"]?.value as? [String] else {
            return true // Default to requiring encryption
        }
        return !protocols.isEmpty
    }
    
    /// Minimum TLS version
    public var minTLSVersion: TLSVersion? {
        return parameters["minTLSVersion"]?.value as? TLSVersion
    }
    
    /// Cipher suites
    public var cipherSuites: [String]? {
        return parameters["cipherSuites"]?.value as? [String]
    }
    
    /// Trust roots
    public var trustRoots: NIOSSLTrustRoots? {
        return parameters["trustRoots"]?.value as? NIOSSLTrustRoots
    }
    
    /// ALPN protocols
    public var alpnProtocols: [String]? {
        return parameters["alpnProtocols"]?.value as? [String]
    }

    public static func newOpportunistic() -> SecurityParameters {
        return SecurityParameters()
    }

    public mutating func set(_ key: String, value: AnySendable) {
        parameters[key] = value
    }

    public mutating func set(allowedProtocols: [String]) {
        set("allowedSecurityProtocols", value: AnySendable(allowedProtocols))
    }

    public mutating func set(protocol: String?) {
        if let proto = `protocol` {
            set("allowedSecurityProtocols", value: AnySendable([proto]))
        } else {
            parameters.removeValue(forKey: "allowedSecurityProtocols")
        }
    }

    public mutating func set(serverCertificate: Certificate) {
        // Certificates are tricky. For this example, we assume they are not Sendable
        // and would need a different handling mechanism in a real app, like a handle or ID.
    }

    public mutating func set(trustVerificationCallback: @escaping TrustVerificationCallback) {
        // Storing non-Sendable closures requires careful handling.
        // In a real app, you might use a manager or actor to handle these.
    }
}