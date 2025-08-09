#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix
import NIOSSL

/// NIO-based implementation of Transport Services Listener
actor NIOListener {
    private let listener: Listener
    private let eventLoopGroup: EventLoopGroup
    private var channel: Channel?
    private let transportProperties: TransportProperties
    private let securityParameters: SecurityParameters
    
    init(listener: Listener, preconnection: Preconnection, eventLoopGroup: EventLoopGroup) async {
        self.listener = listener
        self.eventLoopGroup = eventLoopGroup
        self.transportProperties = preconnection.transportProperties
        self.securityParameters = preconnection.securityParameters
    }
    
    /// Start listening based on transport properties
    func listen() async throws {
        let localEndpoint = await listener.preconnection.localEndpoints.first
        let localAddress: SocketAddress
        
        if let endpoint = localEndpoint {
            localAddress = try endpoint.toSocketAddress()
        } else {
            // Default to any address on a random port
            localAddress = try SocketAddress(ipAddress: "0.0.0.0", port: 0)
        }
        
        // Select appropriate protocol
        let protocolStacks = ProtocolStack.select(
            for: transportProperties,
            securityRequired: securityParameters.requiresEncryption
        )
        
        guard let selectedStack = protocolStacks.first else {
            throw TransportError.establishmentFailed("No suitable protocol stack found")
        }
        
        // Create channel based on selected protocol
        switch selectedStack.transportProtocol {
        case .tcp:
            channel = try await listenTCP(on: localAddress)
        case .udp:
            channel = try await listenUDP(on: localAddress)
        case .quic:
            throw TransportError.establishmentFailed("QUIC listening not yet implemented")
        case .sctp:
            throw TransportError.establishmentFailed("SCTP listening not yet implemented")
        }
    }
    
    /// Listen for TCP connections
    private func listenTCP(on address: SocketAddress) async throws -> Channel {
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                self.configureChildChannel(channel: channel)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        return try await bootstrap.bind(to: address).get()
    }
    
    /// Listen for UDP datagrams
    private func listenUDP(on address: SocketAddress) async throws -> Channel {
        let bootstrap = DatagramBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                self.configureUDPChannel(channel: channel)
            }
        
        return try await bootstrap.bind(to: address).get()
    }
    
    /// Configure child channel for accepted TCP connections
    nonisolated private func configureChildChannel(channel: Channel) -> EventLoopFuture<Void> {
        // Create a new connection for the accepted channel
        Task {
            let preconn = await listener.preconnection
            let connection = Connection(preconnection: preconn, group: preconn.group)
            
            // Notify listener of new connection
            await listener.connectionReceivedHandler?(connection)
            
            // Configure channel pipeline
            var handlers: [any ChannelHandler] = []
            
            // Add TLS if required
            if self.securityParameters.requiresEncryption {
                let sslContext = try! NIOSSLContext(configuration: self.createTLSConfiguration())
                let sslHandler = try! NIOSSLServerHandler(context: sslContext)
                handlers.append(sslHandler)
            }
            
            // Add handlers that need the connection
            handlers.append(MessageFramingHandler(connection: connection))
            handlers.append(ConnectionChannelHandler(connection: connection))
            
            do {
                try await channel.pipeline.addHandlers(handlers, position: .last).get()
                await connection.triggerReady()
            } catch {
                print("Failed to configure channel: \(error)")
            }
        }
        
        return channel.eventLoop.makeSucceededFuture(())
    }
    
    /// Configure UDP channel
    nonisolated private func configureUDPChannel(channel: Channel) -> EventLoopFuture<Void> {
        // For UDP, we need to handle each datagram as a potential new connection
        // This is more complex and would need proper connection tracking
        // For now, just add a basic handler
        return channel.pipeline.addHandler(UDPListenerHandler(listener: listener))
    }
    
    /// Create TLS configuration from security parameters
    nonisolated private func createTLSConfiguration() -> TLSConfiguration {
        var config = TLSConfiguration.makeServerConfiguration(
            certificateChain: [], // TODO: Add certificates
            privateKey: .privateKey(try! NIOSSLPrivateKey(bytes: [], format: .pem)) // TODO: Add private key
        )
        
        // Configure minimum TLS version
        if let minTLSVersion = securityParameters.minTLSVersion {
            config.minimumTLSVersion = minTLSVersion
        }
        
        // Configure cipher suites if specified
        if let _ = securityParameters.cipherSuites {
            // TODO: Convert string cipher suites to proper types
        }
        
        // Configure ALPN
        if let alpnProtocols = securityParameters.alpnProtocols {
            config.applicationProtocols = alpnProtocols
        }
        
        return config
    }
    
    /// Stop listening
    func stop() async throws {
        try await channel?.close().get()
    }
}

/// UDP listener handler
final class UDPListenerHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    
    private let listener: Listener
    
    init(listener: Listener) {
        self.listener = listener
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        // For UDP, each datagram could be from a new "connection"
        // In a real implementation, we'd need to track connections by remote address
        // For now, we'll treat each datagram as a separate message
        
        Task {
            // Create a new connection-less endpoint
            let remoteEndpoint = RemoteEndpoint()
                .withIPAddress(envelope.remoteAddress.ipAddress ?? "")
                .withPort(UInt16(envelope.remoteAddress.port ?? 0))
            
            var preconn = await listener.preconnection
            preconn.remoteEndpoints = [remoteEndpoint]
            
            let connection = Connection(preconnection: preconn)
            await listener.connectionReceivedHandler?(connection)
            
            // Deliver the datagram as a message
            let data = Data(envelope.data.readableBytesView)
            let messageContext = MessageContext()
            await connection.deliverMessage(data: data, context: messageContext)
        }
    }
}

