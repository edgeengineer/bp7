#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix
import NIOSSL
import Crypto

/// NIO-based implementation of Transport Services Connection
actor NIOConnection {
    private let eventLoopGroup: EventLoopGroup
    private var channel: Channel?
    private let connection: Connection
    private let transportProperties: TransportProperties
    private let securityParameters: SecurityParameters
    
    /// Message queue for batching sends
    private var sendQueue: [PendingMessage] = []
    
    private struct PendingMessage {
        let data: Data
        let context: MessageContext
        let promise: EventLoopPromise<Void>
    }
    
    init(connection: Connection, eventLoopGroup: EventLoopGroup) async {
        self.connection = connection
        self.eventLoopGroup = eventLoopGroup
        self.transportProperties = await connection.transportProperties
        self.securityParameters = await connection.securityParameters
    }
    
    /// Establish connection based on transport properties
    func establish() async throws {
        let remoteEndpoints = await connection.remoteEndpoints
        guard !remoteEndpoints.isEmpty else {
            throw TransportError.establishmentFailed("No remote endpoint specified")
        }
        
        // Select appropriate protocol stacks
        let protocolStacks = ProtocolStack.select(
            for: transportProperties,
            securityRequired: securityParameters.requiresEncryption
        )
        
        guard !protocolStacks.isEmpty else {
            throw TransportError.establishmentFailed("No suitable protocol stack found")
        }
        
        // For now, use the first suitable protocol stack
        // TODO: Implement racing for multiple protocol stacks
        let selectedStack = protocolStacks.first!
        
        // Create channel based on selected protocol
        switch selectedStack.transportProtocol {
        case .tcp:
            channel = try await establishTCP()
        case .udp:
            channel = try await establishUDP()
        case .quic:
            // TODO: Implement QUIC support
            throw TransportError.establishmentFailed("QUIC not yet implemented")
        case .sctp:
            // TODO: Implement SCTP support
            throw TransportError.establishmentFailed("SCTP not yet implemented")
        }
        
        // Notify connection is ready
        await connection.triggerReady()
    }
    
    /// Establish TCP connection
    private func establishTCP() async throws -> Channel {
        let factory = TCPConnectionFactory()
        let remoteEndpoints = await connection.remoteEndpoints
        let localEndpoint = await connection.localEndpoint
        let channel = try await factory.createConnection(
            endpoints: remoteEndpoints,
            localEndpoints: localEndpoint != nil ? [localEndpoint!] : [],
            properties: transportProperties,
            security: securityParameters,
            eventLoopGroup: eventLoopGroup
        )
        
        // Configure channel pipeline
        try await configureChannel(channel: channel).get()
        
        return channel
    }
    
    /// Establish UDP connection
    private func establishUDP() async throws -> Channel {
        let factory = UDPConnectionFactory()
        let remoteEndpoints = await connection.remoteEndpoints
        let localEndpoint = await connection.localEndpoint
        let channel = try await factory.createConnection(
            endpoints: remoteEndpoints,
            localEndpoints: localEndpoint != nil ? [localEndpoint!] : [],
            properties: transportProperties,
            security: securityParameters,
            eventLoopGroup: eventLoopGroup
        )
        
        // Configure channel pipeline for UDP
        try await configureUDPChannel(channel: channel).get()
        
        return channel
    }
    
    /// Configure channel pipeline
    private func configureChannel(channel: Channel) -> EventLoopFuture<Void> {
        var handlers: [ChannelHandler] = []
        
        // Add TLS if required
        if securityParameters.requiresEncryption {
            let sslContext = try! NIOSSLContext(configuration: createTLSConfiguration())
            // We'll need to get hostname in a different way since we're in a sync context
            let sslHandler = try! NIOSSLClientHandler(context: sslContext, serverHostname: nil)
            handlers.append(sslHandler)
        }
        
        // Add message framing handler
        handlers.append(MessageFramingHandler(connection: connection))
        
        // Add the main connection handler
        handlers.append(ConnectionChannelHandler(connection: connection))
        
        return channel.pipeline.addHandlers(handlers)
    }
    
    /// Configure UDP channel pipeline
    private func configureUDPChannel(channel: Channel) -> EventLoopFuture<Void> {
        var handlers: [ChannelHandler] = []
        
        // Add DTLS if required for UDP
        if securityParameters.requiresEncryption {
            // TODO: Implement DTLS support
            // For now, UDP without encryption
        }
        
        // Add UDP-specific handlers
        handlers.append(UDPMessageHandler(connection: connection))
        
        return channel.pipeline.addHandlers(handlers)
    }
    
    /// Create TLS configuration from security parameters
    private func createTLSConfiguration() -> TLSConfiguration {
        var config = TLSConfiguration.makeClientConfiguration()
        
        // Configure allowed protocols
        if let minTLSVersion = securityParameters.minTLSVersion {
            config.minimumTLSVersion = minTLSVersion
        }
        
        // Configure cipher suites if specified
        // TODO: Convert string cipher suites to proper NIO cipher suite types
        
        // Configure certificate verification
        if let trustRoots = securityParameters.trustRoots {
            config.trustRoots = trustRoots
        }
        
        // Configure ALPN
        if let alpnProtocols = securityParameters.alpnProtocols {
            config.applicationProtocols = alpnProtocols
        }
        
        return config
    }
    
    /// Send data over the connection
    func send(data: Data, context: MessageContext) async throws {
        guard let channel = channel, channel.isActive else {
            throw TransportError.connectionClosed
        }
        
        let buffer = channel.allocator.buffer(bytes: data)
        let promise = channel.eventLoop.makePromise(of: Void.self)
        
        // Check if we should batch this message
        var mutableContext = context
        let allowBatching = mutableContext.allowBatching
        let isFinal = mutableContext.isFinal
        if allowBatching && !isFinal {
            sendQueue.append(PendingMessage(data: data, context: context, promise: promise))
            
            // Schedule batch send if not already scheduled
            scheduleBatchSend()
        } else {
            // Send immediately
            let message = TransportMessage(buffer: buffer, context: context)
            channel.writeAndFlush(message, promise: promise)
        }
        
        try await promise.futureResult.get()
    }
    
    /// Schedule batch send of queued messages
    private func scheduleBatchSend() {
        guard let channel = channel else { return }
        
        channel.eventLoop.scheduleTask(in: .milliseconds(10)) { [weak self] in
            Task {
                await self?.flushBatchedMessages()
            }
        }
    }
    
    /// Flush all batched messages
    private func flushBatchedMessages() {
        guard let channel = channel else { return }
        
        let messages = sendQueue
        sendQueue.removeAll()
        
        guard !messages.isEmpty else { return }
        
        // Write all messages
        for message in messages {
            let buffer = channel.allocator.buffer(bytes: message.data)
            let transportMessage = TransportMessage(buffer: buffer, context: message.context)
            channel.write(transportMessage, promise: message.promise)
        }
        
        // Flush once
        channel.flush()
    }
    
    /// Close the connection
    func close() async throws {
        try await channel?.close().get()
    }
    
    /// Clone the connection
    func clone() async throws -> NIOConnection {
        let newConnection = await connection.clone()
        let cloned = await NIOConnection(connection: newConnection, eventLoopGroup: eventLoopGroup)
        
        // If original connection is established, establish the clone
        if channel != nil {
            try await cloned.establish()
        }
        
        return cloned
    }
}

/// Message wrapper for channel pipeline
struct TransportMessage {
    let buffer: ByteBuffer
    let context: MessageContext
}

/// Channel handler for Transport Services connections
final class ConnectionChannelHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = TransportMessage
    typealias OutboundOut = ByteBuffer
    
    private let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        let data = Data(buffer.readableBytesView)
        
        // Create message context
        let messageContext = MessageContext()
        
        // Deliver to connection
        Task {
            await connection.deliverMessage(data: data, context: messageContext)
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = unwrapOutboundIn(data)
        context.write(wrapOutboundOut(message.buffer), promise: promise)
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        Task {
            await connection.close()
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Task {
            await connection.triggerSoftError(error)
        }
        context.close(promise: nil)
    }
}

/// Message framing handler
final class MessageFramingHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = TransportMessage
    typealias OutboundOut = TransportMessage
    
    private let connection: Connection
    private var receiveBuffer = ByteBuffer()
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        receiveBuffer.writeBuffer(&buffer)
        
        // For now, just pass through - framing will be handled in a future version
        context.fireChannelRead(wrapInboundOut(receiveBuffer))
        receiveBuffer.clear()
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = unwrapOutboundIn(data)
        
        // For now, just pass through - framing will be handled in a future version
        context.write(wrapOutboundOut(message), promise: promise)
    }
}

/// UDP message handler
final class UDPMessageHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = TransportMessage
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    private let connection: Connection
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let envelope = unwrapInboundIn(data)
        let data = Data(envelope.data.readableBytesView)
        
        // Create message context
        let messageContext = MessageContext()
        
        // Deliver to connection
        Task {
            await connection.deliverMessage(data: data, context: messageContext)
        }
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let _ = unwrapOutboundIn(data)
        
        // For UDP, we need the remote address - this should be set during channel creation
        // For now, we'll fail if we can't determine it
        promise?.fail(TransportError.establishmentFailed("UDP remote address not configured"))
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Task {
            await connection.triggerSoftError(error)
        }
        // UDP doesn't necessarily close on errors
    }
}