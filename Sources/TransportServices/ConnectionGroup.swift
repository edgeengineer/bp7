
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Manages a set of connections that share common properties and state.
public actor ConnectionGroup {
    private var connections: [Connection]
    
    // The transport properties shared by all connections in the group.
    // Changes to these properties will be propagated.
    private var sharedTransportProperties: TransportProperties

    public init(template: Preconnection) {
        self.connections = []
        self.sharedTransportProperties = template.transportProperties
        print("ConnectionGroup created.")
    }

    /// Adds a connection to the group.
    func add(connection: Connection) {
        connections.append(connection)
        print("Connection added to group. Group size: \(connections.count)")
    }

    /// Removes a connection from the group.
    func remove(connection: Connection) async {
        connections.removeAll { $0 === connection }
        print("Connection removed from group. Group size: \(connections.count)")
    }

    /// Sets a transport property for the entire group, which will be applied to all connections.
    public func set<T: Sendable>(_ key: String, value: T) async {
        sharedTransportProperties.set(key, value: AnySendable(value))
        print("Group property \(key) set to \(value)")
        // Propagate the change to all connections in the group
        for connection in connections {
            await connection.set(key, value: value)
        }
    }
    
    /// Closes all connections in the group.
    public func close() async {
        print("Closing all connections in the group.")
        for connection in connections {
            await connection.close()
        }
    }
}
