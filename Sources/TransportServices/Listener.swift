#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix

public actor Listener {
    let internalPreconnection: Preconnection
    private var isStopped: Bool = false
    
    // NIO implementation
    private var nioListener: NIOListener?
    private let eventLoopGroup: EventLoopGroup

    private var internalConnectionReceivedHandler: (@Sendable (Connection) -> Void)?
    private var stopHandler: (@Sendable () -> Void)?

    init(preconnection: Preconnection, eventLoopGroup: EventLoopGroup? = nil) {
        self.internalPreconnection = preconnection
        self.eventLoopGroup = eventLoopGroup ?? MultiThreadedEventLoopGroup.singleton
        print("Listener created for \(preconnection.localEndpoints.first?.port ?? 0)")
        
        // Start listening
        Task {
            await self.startListening(preconnection: preconnection)
        }
    }
    
    private func startListening(preconnection: Preconnection) async {
        do {
            nioListener = await NIOListener(listener: self, preconnection: preconnection, eventLoopGroup: self.eventLoopGroup)
            try await nioListener?.listen()
        } catch {
            print("Failed to start listener: \(error)")
        }
    }
    
    public func onConnectionReceived(handler: @escaping @Sendable (Connection) -> Void) {
        self.internalConnectionReceivedHandler = handler
    }

    public func onStop(handler: @escaping @Sendable () -> Void) {
        self.stopHandler = handler
    }

    public func stop() async {
        guard !isStopped else { return }
        isStopped = true
        
        // Stop NIO listener
        try? await nioListener?.stop()
        
        print("Stopping listener.")
        stopHandler?()
    }
    
    // Computed properties for NIOListener compatibility
    public var preconnection: Preconnection {
        internalPreconnection
    }
    
    public var connectionReceivedHandler: (@Sendable (Connection) -> Void)? {
        internalConnectionReceivedHandler
    }
}