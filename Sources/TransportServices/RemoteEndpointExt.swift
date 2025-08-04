#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore

/// Extension to convert RemoteEndpoint to SocketAddress
public extension RemoteEndpoint {
    /// Convert this endpoint to a NIO SocketAddress
    func toSocketAddress() throws -> SocketAddress {
        if let ipAddress = ipAddress {
            return try SocketAddress(ipAddress: ipAddress, port: Int(port ?? 0))
        } else if let hostname = hostname {
            // In a real implementation, this would do DNS resolution
            // For now, we'll use a simple approach
            return try SocketAddress.makeAddressResolvingHost(hostname, port: Int(port ?? 0))
        } else {
            throw TransportError.establishmentFailed("No valid address in endpoint")
        }
    }
}

/// Extension for LocalEndpoint too
public extension LocalEndpoint {
    /// Convert this endpoint to a NIO SocketAddress
    func toSocketAddress() throws -> SocketAddress {
        if let ipAddress = ipAddress {
            return try SocketAddress(ipAddress: ipAddress, port: Int(port ?? 0))
        } else {
            // Default to any address
            return try SocketAddress(ipAddress: "0.0.0.0", port: Int(port ?? 0))
        }
    }
}