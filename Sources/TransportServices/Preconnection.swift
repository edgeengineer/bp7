#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOPosix

/// Represents a potential connection that has not yet been established.
/// It holds all the configuration required to create a Connection, Listener, or Rendezvous session.
public struct Preconnection: Sendable {
    public var localEndpoints: [LocalEndpoint]
    public var remoteEndpoints: [RemoteEndpoint]
    public var transportProperties: TransportProperties
    public var securityParameters: SecurityParameters
    public var framer: Framer?
    public var group: ConnectionGroup?

    public init(localEndpoints: [LocalEndpoint] = [],
                remoteEndpoints: [RemoteEndpoint] = [],
                transportProperties: TransportProperties = TransportProperties(),
                securityParameters: SecurityParameters = SecurityParameters(),
                framer: Framer? = nil,
                group: ConnectionGroup? = nil) {
        self.localEndpoints = localEndpoints
        self.remoteEndpoints = remoteEndpoints
        self.transportProperties = transportProperties
        self.securityParameters = securityParameters
        self.framer = framer
        self.group = group
    }

    public func initiate() -> Connection {
        print("Initiating connection...")
        let connection = Connection(preconnection: self, group: self.group)
        
        // Start establishment in the background
        Task {
            do {
                try await connection.establish()
            } catch {
                await connection.triggerEstablishmentError(error)
            }
        }
        
        return connection
    }
    
    public func initiateWithSend(data: Data, context: MessageContext = MessageContext()) -> Connection {
        print("Initiating connection with send...")
        let connection = Connection(preconnection: self, group: self.group)
        
        // Queue the initial data to be sent once connected
        Task {
            // For 0-RTT, check if supported
            let zeroRttPref: Preference? = transportProperties.get(SelectionProperties.zeroRttMsg)
            if zeroRttPref == .require || zeroRttPref == .prefer {
                // TODO: Implement 0-RTT data transmission
                // For now, establish connection first
                do {
                    try await connection.establish()
                } catch {
                    await connection.triggerEstablishmentError(error)
                    return
                }
            } else {
                // Wait for connection to be ready
                do {
                    try await connection.establish()
                } catch {
                    await connection.triggerEstablishmentError(error)
                    return
                }
            }
            
            // Send the initial data
            await connection.send(data: data, context: context)
        }
        
        return connection
    }

    public func listen() -> Listener {
        print("Listening for incoming connections...")
        return Listener(preconnection: self)
    }

    public func rendezvous() -> (Connection, Listener) {
        print("Attempting rendezvous...")
        let connection = Connection(preconnection: self, group: self.group)
        let listener = Listener(preconnection: self)
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await connection.triggerReady()
        }
        return (connection, listener)
    }

    public func resolve() async {
        print("Resolving endpoints...")
    }
    
    public mutating func addRemote(endpoint: RemoteEndpoint) {
        self.remoteEndpoints.append(endpoint)
    }
}