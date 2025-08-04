#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A protocol that defines the interface for routing algorithms in disruption-tolerant networks.
///
/// The `RoutingAlgorithm` protocol provides a generic interface for implementing various routing
/// strategies in DTN environments. It supports both proactive (table-driven) and reactive
/// (on-demand) routing approaches.
///
/// ## Overview
///
/// Routing algorithms conforming to this protocol must handle:
/// - Route discovery and maintenance
/// - Neighbor management
/// - Routing updates processing
/// - Cost metrics calculation
///
/// ## Topics
///
/// ### Associated Types
///
/// The protocol uses associated types to allow flexibility in implementation:
/// - ``NodeID``: The type used to identify nodes in the network
/// - ``RouteEntry``: The type representing routing table entries
/// - ``RoutingUpdate``: The type of messages exchanged between nodes
///
/// ### Conforming to RoutingAlgorithm
///
/// To conform to `RoutingAlgorithm`, implement all required methods and define the associated types:
///
/// ```swift
/// struct MyRoutingAlgorithm: RoutingAlgorithm {
///     typealias NodeID = String
///     typealias RouteEntry = MyRoute
///     typealias RoutingUpdate = MyUpdate
///     
///     init(localNode: Node<String>) {
///         // Initialize the routing algorithm
///     }
///     
///     func nextHop(to destination: String) -> String? {
///         // Return the next hop for the destination
///     }
///     // ... implement other required methods
/// }
/// ```
public protocol RoutingAlgorithm {
    /// The type of node identifier used by this routing algorithm.
    ///
    /// This type must conform to `Hashable` to allow efficient storage and lookup
    /// in routing tables and other data structures.
    associatedtype NodeID: Hashable
    
    /// The type of routing table entry used by this algorithm.
    ///
    /// Each routing algorithm can define its own route entry structure
    /// containing information such as destination, next hop, cost metrics,
    /// and algorithm-specific metadata.
    associatedtype RouteEntry
    
    /// The type of routing update message used by this algorithm.
    ///
    /// Routing updates are messages exchanged between nodes to share
    /// routing information. The structure depends on the specific
    /// routing protocol (e.g., HELLO messages, route advertisements).
    associatedtype RoutingUpdate
    
    /// Creates a new instance of the routing algorithm for a specific node.
    ///
    /// - Parameter localNode: The node that will run this routing algorithm instance.
    ///                       This becomes the local node identity for all routing decisions.
    init(localNode: Node<NodeID>)
    
    /// Returns the next hop node for routing packets to a given destination.
    ///
    /// This is the primary routing decision function. It consults the routing table
    /// to determine which neighbor should receive packets destined for the specified node.
    ///
    /// - Parameter destination: The ID of the destination node.
    /// - Returns: The ID of the next hop node, or `nil` if no route exists.
    ///
    /// - Note: If the destination is a direct neighbor, this method typically
    ///         returns the destination itself as the next hop.
    func nextHop(to destination: NodeID) -> NodeID?
    
    /// Processes a routing update message received from a neighbor.
    ///
    /// This method handles incoming routing protocol messages and updates
    /// the local routing state accordingly. The exact behavior depends on
    /// the routing algorithm implementation.
    ///
    /// - Parameters:
    ///   - update: The routing update message to process.
    ///   - from: The ID of the neighbor node that sent the update.
    ///
    /// - Important: This method may trigger route recalculation or
    ///             generation of new routing updates.
    func processUpdate(_ update: RoutingUpdate, from: NodeID)
    
    /// Generates a routing update message to broadcast to neighbors.
    ///
    /// This method creates routing update messages based on the current
    /// routing state. The frequency and triggers for calling this method
    /// depend on whether the algorithm is proactive or reactive.
    ///
    /// - Returns: A routing update message ready to be sent to neighbors.
    ///
    /// - Note: Proactive algorithms typically call this periodically,
    ///         while reactive algorithms call it in response to events.
    func generateUpdate() -> RoutingUpdate
    
    /// Handles the event of a neighbor becoming reachable.
    ///
    /// Called when a new neighbor is discovered or an existing neighbor
    /// becomes reachable again. This typically triggers route updates
    /// and may initiate protocol-specific neighbor establishment procedures.
    ///
    /// - Parameter neighbor: The ID of the neighbor that became reachable.
    ///
    /// - Important: This method should update internal neighbor tables
    ///             and may trigger route recalculation.
    func neighborUp(_ neighbor: NodeID)
    
    /// Handles the event of a neighbor becoming unreachable.
    ///
    /// Called when a neighbor is no longer reachable due to link failure,
    /// node failure, or mobility. This typically triggers removal of routes
    /// through that neighbor and may generate error messages.
    ///
    /// - Parameter neighbor: The ID of the neighbor that became unreachable.
    ///
    /// - Important: This method should remove invalid routes and may
    ///             trigger route error propagation to affected nodes.
    func neighborDown(_ neighbor: NodeID)
    
    /// Returns all routes currently known by the routing algorithm.
    ///
    /// This method provides access to the complete routing table,
    /// useful for debugging, monitoring, and administrative purposes.
    ///
    /// - Returns: An array of all routing table entries.
    ///
    /// - Note: The returned routes may include both active and inactive
    ///         routes, depending on the algorithm implementation.
    func getRoutes() -> [RouteEntry]
    
    /// Returns the cost metric to reach a destination node.
    ///
    /// The cost metric interpretation depends on the routing algorithm:
    /// - Hop count for distance vector algorithms
    /// - Link state metrics for link state algorithms
    /// - Composite metrics for QoS-aware algorithms
    ///
    /// - Parameter destination: The ID of the destination node.
    /// - Returns: The cost to reach the destination, or `nil` if unreachable.
    ///
    /// - Note: Lower values typically indicate better routes.
    func costTo(_ destination: NodeID) -> Int?
}

/// A basic routing table entry that can be used by various routing algorithms.
///
/// This structure provides common fields needed by most routing protocols.
/// Specific algorithms may extend this or define their own entry types.
///
/// ## Example
///
/// ```swift
/// let route = BasicRouteEntry(
///     destination: "node-5",
///     nextHop: "node-2",
///     cost: 3,
///     sequenceNumber: 42
/// )
/// ```
public struct BasicRouteEntry<NodeID: Hashable> {
    /// The destination node for this route.
    public let destination: NodeID
    
    /// The next hop node to reach the destination.
    ///
    /// Packets destined for `destination` should be forwarded to this node.
    public let nextHop: NodeID
    
    /// The cost metric to reach the destination.
    ///
    /// Interpretation depends on the routing algorithm (e.g., hop count, latency).
    public let cost: Int
    
    /// Optional sequence number for loop prevention.
    ///
    /// Used by algorithms like AODV to ensure route freshness and prevent loops.
    public let sequenceNumber: Int?
    
    /// Creates a new basic route entry.
    ///
    /// - Parameters:
    ///   - destination: The destination node ID.
    ///   - nextHop: The next hop node ID.
    ///   - cost: The cost to reach the destination.
    ///   - sequenceNumber: Optional sequence number for the route.
    public init(destination: NodeID, nextHop: NodeID, cost: Int, sequenceNumber: Int? = nil) {
        self.destination = destination
        self.nextHop = nextHop
        self.cost = cost
        self.sequenceNumber = sequenceNumber
    }
}