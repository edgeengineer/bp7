
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix

public actor Connection {
    public private(set) var transportProperties: TransportProperties
    public let securityParameters: SecurityParameters
    public let localEndpoint: LocalEndpoint?
    public let remoteEndpoint: RemoteEndpoint?
    public let remoteEndpoints: [RemoteEndpoint]
    public let framer: Framer?
    public let group: ConnectionGroup?

    private var isReady: Bool = false
    private var isClosed: Bool = false
    
    // NIO implementation
    private var nioConnection: NIOConnection?
    private let eventLoopGroup: EventLoopGroup

    // Event Handlers
    private var readyHandler: (@Sendable () -> Void)?
    private var establishmentErrorHandler: (@Sendable (Error) -> Void)?
    private var receiveHandler: (@Sendable (Data, MessageContext) -> Void)?
    private var sendCompletionHandler: (@Sendable (Error?) -> Void)?
    private var closeHandler: (@Sendable () -> Void)?
    private var pathChangeHandler: (@Sendable (Connection) -> Void)?
    private var softErrorHandler: (@Sendable (Error) -> Void)?

    init(preconnection: Preconnection, group: ConnectionGroup? = nil, eventLoopGroup: EventLoopGroup? = nil) {
        self.transportProperties = preconnection.transportProperties
        self.securityParameters = preconnection.securityParameters
        self.localEndpoint = preconnection.localEndpoints.first
        self.remoteEndpoint = preconnection.remoteEndpoints.first
        self.remoteEndpoints = preconnection.remoteEndpoints
        self.framer = preconnection.framer
        self.group = group
        self.eventLoopGroup = eventLoopGroup ?? MultiThreadedEventLoopGroup.singleton
        
        Task {
            await self.group?.add(connection: self)
            await self.framer?.start(connection: self)
        }
    }

    // Handler Configuration
    public func onReady(handler: @escaping @Sendable () -> Void) { self.readyHandler = handler }
    public func onEstablishmentError(handler: @escaping @Sendable (Error) -> Void) { self.establishmentErrorHandler = handler }
    public func onReceive(handler: @escaping @Sendable (Data, MessageContext) -> Void) { self.receiveHandler = handler }
    public func onSendCompleted(handler: @escaping @Sendable (Error?) -> Void) { self.sendCompletionHandler = handler }
    public func onClose(handler: @escaping @Sendable () -> Void) { self.closeHandler = handler }
    public func onPathChange(handler: @escaping @Sendable (Connection) -> Void) { self.pathChangeHandler = handler }
    public func onSoftError(handler: @escaping @Sendable (Error) -> Void) { self.softErrorHandler = handler }

    // Connection Properties
    public func set<T: Sendable>(_ key: String, value: T) {
        var newProps = self.transportProperties
        newProps.set(key, value: AnySendable(value))
        self.transportProperties = newProps
        print("Set property \(key) to \(value)")
    }

    public func get<T>(_ key: String) -> T? {
        return self.transportProperties.get(key)
    }

    // Actions
    public func send(data: Data, context: MessageContext = MessageContext()) async {
        var mutableContext = context
        guard !isClosed else {
            sendCompletionHandler?(TransportError.connectionClosed)
            return
        }
        
        // Apply framing if configured
        let dataToSend = framer?.frame(message: data, context: mutableContext) ?? data
        
        do {
            // Use NIO connection if available
            if let nioConnection = nioConnection {
                try await nioConnection.send(data: dataToSend, context: mutableContext)
            } else {
                // Fallback for testing
                print("Sending data... (\(dataToSend.count) bytes)")
            }
            sendCompletionHandler?(nil)
        } catch {
            sendCompletionHandler?(error)
        }

        if mutableContext.isFinal {
            await self.close()
        }
    }

    public func receive() async {
        guard !isClosed else { return }
        
        // For NIO connections, receiving is handled via the channel handler
        // which calls deliverMessage directly
        if nioConnection == nil {
            // Fallback for testing
            print("Waiting to receive data...")
            try? await Task.sleep(nanoseconds: 500_000_000)
            let mockData = "Hello from the other side!".data(using: .utf8)!
            if let framer = self.framer {
                await framer.handleInput(data: mockData)
            } else {
                var mockContext = MessageContext()
                mockContext.isFinal = true
                receiveHandler?(mockData, mockContext)
                if mockContext.isFinal {
                    await self.close()
                }
            }
        }
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        
        // Close NIO connection if available
        if let nioConnection = nioConnection {
            try? await nioConnection.close()
        }
        
        await group?.remove(connection: self)
        closeHandler?()
    }
    
    /// Establish the connection
    public func establish() async throws {
        guard !isReady else { return }
        
        // Create and establish NIO connection
        nioConnection = await NIOConnection(connection: self, eventLoopGroup: eventLoopGroup)
        
        do {
            try await nioConnection?.establish()
        } catch {
            triggerEstablishmentError(error)
            throw error
        }
    }

    public func clone() -> Connection {
        let newPreconnection = Preconnection(
            localEndpoints: self.localEndpoint != nil ? [self.localEndpoint!] : [],
            remoteEndpoints: self.remoteEndpoint != nil ? [self.remoteEndpoint!] : [],
            transportProperties: self.transportProperties,
            securityParameters: self.securityParameters,
            framer: self.framer,
            group: self.group
        )
        return Connection(preconnection: newPreconnection, group: self.group, eventLoopGroup: self.eventLoopGroup)
    }
    
    public func addRemote(_ endpoint: RemoteEndpoint) {
        print("Adding remote endpoint: \(endpoint)")
        pathChangeHandler?(self)
    }

    public func addLocal(_ endpoint: LocalEndpoint) {
        print("Adding local endpoint: \(endpoint)")
        pathChangeHandler?(self)
    }

    // Internal Triggers
    func triggerReady() { isReady = true; readyHandler?() }
    func triggerEstablishmentError(_ error: Error) { establishmentErrorHandler?(error) }
    func triggerSoftError(_ error: Error) { softErrorHandler?(error) }
    public func deliverMessage(data: Data, context: MessageContext) {
        var mutableContext = context
        receiveHandler?(data, mutableContext)
        if mutableContext.isFinal {
            Task { await self.close() }
        }
    }
}

public enum TransportError: Error {
    case connectionClosed
    case establishmentFailed(String)
    case softError(String)
}
