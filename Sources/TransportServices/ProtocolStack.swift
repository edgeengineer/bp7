#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix

/// Represents a protocol stack configuration
public struct ProtocolStack {
    public enum TransportProtocol: String, CaseIterable {
        case tcp = "TCP"
        case udp = "UDP"
        case quic = "QUIC"
        case sctp = "SCTP"
        
        /// Check if protocol matches transport properties
        func matches(properties: TransportProperties) -> Bool {
            let reliability: Preference = properties.get("reliability") ?? .require
            let preserveOrder: Preference = properties.get("preserveOrder") ?? .require
            let preserveBoundaries: Preference = properties.get("preserveMessageBoundaries") ?? .noPreference
            let multistreaming: Preference = properties.get("multistreaming") ?? .noPreference
            
            switch self {
            case .tcp:
                return reliability == .require &&
                       preserveOrder == .require &&
                       preserveBoundaries != .require
            case .udp:
                return reliability != .require ||
                       preserveBoundaries == .require
            case .quic:
                return multistreaming == .prefer ||
                       multistreaming == .require
            case .sctp:
                return preserveBoundaries == .require &&
                       reliability == .require
            }
        }
        
        /// Priority for racing/fallback
        var racingPriority: Int {
            switch self {
            case .quic: return 0  // Highest priority
            case .tcp: return 1
            case .sctp: return 2
            case .udp: return 3   // Lowest priority
            }
        }
    }
    
    public let transportProtocol: TransportProtocol
    public let securityProtocol: SecurityProtocol?
    
    public enum SecurityProtocol: String {
        case tls = "TLS"
        case dtls = "DTLS"
        case quicTLS = "QUIC-TLS"
    }
    
    init(transportProtocol: TransportProtocol, securityProtocol: SecurityProtocol? = nil) {
        self.transportProtocol = transportProtocol
        self.securityProtocol = securityProtocol
    }
    
    /// Select appropriate protocol stacks based on transport properties
    public static func select(for properties: TransportProperties, securityRequired: Bool) -> [ProtocolStack] {
        var candidates: [ProtocolStack] = []
        
        // Check each available protocol
        for proto in TransportProtocol.allCases {
            if proto.matches(properties: properties) {
                let security: SecurityProtocol? = securityRequired ? securityProtocol(for: proto) : nil
                candidates.append(ProtocolStack(transportProtocol: proto, securityProtocol: security))
            }
        }
        
        // Sort by priority
        candidates.sort { $0.transportProtocol.racingPriority < $1.transportProtocol.racingPriority }
        
        return candidates
    }
    
    private static func securityProtocol(for transport: TransportProtocol) -> SecurityProtocol {
        switch transport {
        case .tcp, .sctp:
            return .tls
        case .udp:
            return .dtls
        case .quic:
            return .quicTLS
        }
    }
}

/// Protocol-specific connection factory
protocol ProtocolConnectionFactory {
    func createConnection(
        endpoints: [RemoteEndpoint],
        localEndpoints: [LocalEndpoint]?,
        properties: TransportProperties,
        security: SecurityParameters,
        eventLoopGroup: EventLoopGroup
    ) async throws -> Channel
}

/// TCP connection factory
struct TCPConnectionFactory: ProtocolConnectionFactory {
    func createConnection(
        endpoints: [RemoteEndpoint],
        localEndpoints: [LocalEndpoint]?,
        properties: TransportProperties,
        security: SecurityParameters,
        eventLoopGroup: EventLoopGroup
    ) async throws -> Channel {
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        // Configure TCP options
        if let tcpNoDelay: Bool = properties.get("tcpNoDelay") {
            _ = bootstrap.channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: tcpNoDelay ? 1 : 0)
        }
        
        if let keepAlive: Bool = properties.get("keepAlive") {
            _ = bootstrap.channelOption(ChannelOptions.socket(SOL_SOCKET, SO_KEEPALIVE), value: keepAlive ? 1 : 0)
        }
        
        // Configure local endpoint if specified
        if let _ = localEndpoints?.first {
            // Interface binding requires platform-specific handling
            // For now, we'll skip this
        }
        
        // TODO: Implement Happy Eyeballs for multiple endpoints
        guard let endpoint = endpoints.first else {
            throw TransportError.establishmentFailed("No remote endpoint")
        }
        
        return try await bootstrap.connect(to: endpoint.toSocketAddress()).get()
    }
}

/// UDP connection factory
struct UDPConnectionFactory: ProtocolConnectionFactory {
    func createConnection(
        endpoints: [RemoteEndpoint],
        localEndpoints: [LocalEndpoint]?,
        properties: TransportProperties,
        security: SecurityParameters,
        eventLoopGroup: EventLoopGroup
    ) async throws -> Channel {
        let bootstrap = DatagramBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        // Configure local endpoint for binding
        let localAddress: SocketAddress
        if let localEndpoint = localEndpoints?.first {
            localAddress = try localEndpoint.toSocketAddress()
        } else {
            localAddress = try SocketAddress(ipAddress: "0.0.0.0", port: 0)
        }
        
        // Create UDP channel
        let channel = try await bootstrap.bind(to: localAddress).get()
        
        // For UDP, we need to "connect" to establish the default remote
        if let remoteEndpoint = endpoints.first {
            try await channel.connect(to: remoteEndpoint.toSocketAddress()).get()
        }
        
        return channel
    }
}