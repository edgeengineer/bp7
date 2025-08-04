#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An implementation of the Ad hoc On-Demand Distance Vector (AODV) routing protocol.
///
/// AODV is a reactive routing protocol that creates routes only when desired by source nodes.
/// It uses destination sequence numbers to ensure loop freedom and route freshness.
///
/// ## Overview
///
/// Key features of this AODV implementation:
/// - **On-demand routing**: Routes discovered only when needed
/// - **Sequence numbers**: Prevent routing loops and ensure fresh routes
/// - **Route maintenance**: Monitors active routes and repairs breaks
/// - **Local connectivity**: Uses HELLO messages for neighbor detection
///
/// ## Topics
///
/// ### Route Discovery
///
/// When a node needs a route to a destination:
/// 1. Broadcasts a Route Request (RREQ)
/// 2. Intermediate nodes forward RREQ and create reverse routes
/// 3. Destination or node with fresh route responds with Route Reply (RREP)
/// 4. RREP follows reverse path, establishing forward routes
///
/// ### Message Types
///
/// AODV uses four message types:
/// - **RREQ**: Route Request for discovering paths
/// - **RREP**: Route Reply containing route information
/// - **RERR**: Route Error for broken link notification
/// - **HELLO**: Local connectivity maintenance
///
/// ### Example Usage
///
/// ```swift
/// let node = Node(id: "node1")
/// let aodv = AODV(localNode: node)
/// 
/// // When a neighbor is detected
/// aodv.neighborUp("node2")
/// 
/// // To find next hop for a destination
/// if let nextHop = aodv.nextHop(to: "node5") {
///     // Forward packet to nextHop
/// } else {
///     // Route discovery will be initiated
/// }
/// ```
///
/// ## Implementation Details
///
/// This implementation maintains:
/// - Routing table with route lifetimes
/// - Sequence numbers for loop prevention
/// - RREQ ID cache to avoid duplicate processing
/// - Neighbor set for local connectivity
public final class AODV<NodeID: Hashable>: RoutingAlgorithm {
    internal let localNode: Node<NodeID>
    private var routingTable: [NodeID: AODVRoute<NodeID>] = [:]
    private var sequenceNumber: Int = 0
    private var routeRequestID: Int = 0
    private var seenRREQs: Set<RREQIdentifier<NodeID>> = []
    private var pendingRouteRequests: [NodeID: PendingRequest<NodeID>] = [:]
    internal var neighbors: Set<NodeID> = []
    
    public typealias RouteEntry = AODVRoute<NodeID>
    public typealias RoutingUpdate = AODVMessage<NodeID>
    
    public init(localNode: Node<NodeID>) {
        self.localNode = localNode
    }
    
    public func nextHop(to destination: NodeID) -> NodeID? {
        if let route = routingTable[destination], route.isValid {
            return route.nextHop
        }
        
        // Initiate route discovery if no valid route exists
        initiateRouteDiscovery(to: destination)
        return nil
    }
    
    public func processUpdate(_ update: AODVMessage<NodeID>, from: NodeID) {
        switch update {
        case .rreq(let rreq):
            processRouteRequest(rreq, from: from)
        case .rrep(let rrep):
            processRouteReply(rrep, from: from)
        case .rerr(let rerr):
            processRouteError(rerr, from: from)
        case .hello(let hello):
            processHello(hello, from: from)
        }
    }
    
    public func generateUpdate() -> AODVMessage<NodeID> {
        // Generate periodic HELLO message
        incrementSequenceNumber()
        return .hello(AODVHelloMessage(
            source: localNode.id,
            sequenceNumber: sequenceNumber
        ))
    }
    
    public func neighborUp(_ neighbor: NodeID) {
        neighbors.insert(neighbor)
        
        // Add direct route to neighbor
        routingTable[neighbor] = AODVRoute(
            destination: neighbor,
            nextHop: neighbor,
            hopCount: 1,
            sequenceNumber: 0,
            lifetime: Date().addingTimeInterval(300), // 5 minutes
            precursors: []
        )
    }
    
    public func neighborDown(_ neighbor: NodeID) {
        neighbors.remove(neighbor)
        
        // Find all routes using this neighbor as next hop
        var unreachableDestinations: Set<NodeID> = []
        
        for (destination, route) in routingTable {
            if route.nextHop == neighbor {
                unreachableDestinations.insert(destination)
                routingTable.removeValue(forKey: destination)
            }
        }
        
        // Send route error for unreachable destinations
        if !unreachableDestinations.isEmpty {
            broadcastRouteError(unreachableDestinations: unreachableDestinations)
        }
    }
    
    public func getRoutes() -> [AODVRoute<NodeID>] {
        return routingTable.values.filter { $0.isValid }
    }
    
    public func costTo(_ destination: NodeID) -> Int? {
        return routingTable[destination]?.hopCount
    }
    
    // MARK: - Private Methods
    
    private func initiateRouteDiscovery(to destination: NodeID) {
        guard pendingRouteRequests[destination] == nil else { return }
        
        routeRequestID += 1
        incrementSequenceNumber()
        
        let rreq = RouteRequest(
            source: localNode.id,
            sourceSequenceNumber: sequenceNumber,
            broadcastID: routeRequestID,
            destination: destination,
            destinationSequenceNumber: routingTable[destination]?.sequenceNumber ?? 0,
            hopCount: 0
        )
        
        pendingRouteRequests[destination] = PendingRequest(
            request: rreq,
            timestamp: Date()
        )
        
        // Broadcast RREQ to neighbors
        // In real implementation, this would be sent through network layer
    }
    
    private func processRouteRequest(_ rreq: RouteRequest<NodeID>, from: NodeID) {
        let rreqID = RREQIdentifier(source: rreq.source, broadcastID: rreq.broadcastID)
        
        // Check if we've seen this RREQ before
        guard !seenRREQs.contains(rreqID) else { return }
        seenRREQs.insert(rreqID)
        
        // Update reverse route to source
        updateRoute(
            to: rreq.source,
            nextHop: from,
            hopCount: rreq.hopCount + 1,
            sequenceNumber: rreq.sourceSequenceNumber
        )
        
        // Check if we are the destination
        if rreq.destination == localNode.id {
            // Send RREP back to source
            incrementSequenceNumber()
            _ = RouteReply(
                source: rreq.source,
                destination: localNode.id,
                destinationSequenceNumber: sequenceNumber,
                hopCount: 0,
                lifetime: Date().addingTimeInterval(300)
            )
            // Send RREP to 'from' node
            return
        }
        
        // Check if we have a fresh enough route to destination
        if let route = routingTable[rreq.destination],
           route.isValid && route.sequenceNumber >= rreq.destinationSequenceNumber {
            // Send RREP on behalf of destination
            _ = RouteReply(
                source: rreq.source,
                destination: rreq.destination,
                destinationSequenceNumber: route.sequenceNumber,
                hopCount: route.hopCount,
                lifetime: route.lifetime
            )
            // Send RREP to 'from' node
            return
        }
        
        // Forward the RREQ
        var updatedRREQ = rreq
        updatedRREQ.hopCount += 1
        // Broadcast updated RREQ to neighbors except 'from'
    }
    
    private func processRouteReply(_ rrep: RouteReply<NodeID>, from: NodeID) {
        // Update forward route to destination
        updateRoute(
            to: rrep.destination,
            nextHop: from,
            hopCount: rrep.hopCount + 1,
            sequenceNumber: rrep.destinationSequenceNumber,
            lifetime: rrep.lifetime
        )
        
        // Forward RREP if we're not the source
        if rrep.source != localNode.id {
            if routingTable[rrep.source] != nil {
                // Forward RREP to next hop toward source
                var updatedRREP = rrep
                updatedRREP.hopCount += 1
                // Send to route.nextHop
            }
        } else {
            // We are the source, route discovery complete
            pendingRouteRequests.removeValue(forKey: rrep.destination)
        }
    }
    
    private func processRouteError(_ rerr: RouteError<NodeID>, from: NodeID) {
        var affectedPrecursors: Set<NodeID> = []
        
        for destination in rerr.unreachableDestinations {
            if let route = routingTable[destination], route.nextHop == from {
                // Mark route as invalid
                routingTable.removeValue(forKey: destination)
                affectedPrecursors.formUnion(route.precursors)
            }
        }
        
        // Forward RERR to affected precursors
        if !affectedPrecursors.isEmpty {
            // Send RERR to precursors
        }
    }
    
    private func processHello(_ hello: AODVHelloMessage<NodeID>, from: NodeID) {
        // Update neighbor lifetime
        updateRoute(
            to: from,
            nextHop: from,
            hopCount: 1,
            sequenceNumber: hello.sequenceNumber
        )
    }
    
    private func updateRoute(to destination: NodeID, nextHop: NodeID, hopCount: Int, sequenceNumber: Int, lifetime: Date? = nil) {
        let routeLifetime = lifetime ?? Date().addingTimeInterval(300)
        
        if let existingRoute = routingTable[destination] {
            // Update only if sequence number is newer or same sequence with better hop count
            if sequenceNumber > existingRoute.sequenceNumber ||
               (sequenceNumber == existingRoute.sequenceNumber && hopCount < existingRoute.hopCount) {
                routingTable[destination] = AODVRoute(
                    destination: destination,
                    nextHop: nextHop,
                    hopCount: hopCount,
                    sequenceNumber: sequenceNumber,
                    lifetime: routeLifetime,
                    precursors: existingRoute.precursors
                )
            }
        } else {
            routingTable[destination] = AODVRoute(
                destination: destination,
                nextHop: nextHop,
                hopCount: hopCount,
                sequenceNumber: sequenceNumber,
                lifetime: routeLifetime,
                precursors: []
            )
        }
    }
    
    private func broadcastRouteError(unreachableDestinations: Set<NodeID>) {
        _ = RouteError(unreachableDestinations: unreachableDestinations)
        // Broadcast RERR to neighbors
    }
    
    private func incrementSequenceNumber() {
        sequenceNumber += 1
    }
}

// MARK: - AODV Data Structures

/// A route entry in the AODV routing table.
///
/// AODV routes include lifetime information and precursor lists
/// for route maintenance and error reporting.
public struct AODVRoute<NodeID: Hashable> {
    /// The destination node for this route.
    public let destination: NodeID
    
    /// The next hop node to reach the destination.
    public let nextHop: NodeID
    
    /// The number of hops to reach the destination.
    public let hopCount: Int
    
    /// Destination sequence number for route freshness.
    ///
    /// Higher sequence numbers indicate more recent route information.
    public let sequenceNumber: Int
    
    /// Expiration time for this route.
    ///
    /// Routes are considered invalid after this time and should be purged.
    public let lifetime: Date
    
    /// Set of nodes that use this node as next hop to the destination.
    ///
    /// Used for sending RERR messages when the route breaks.
    public var precursors: Set<NodeID>
    
    /// Indicates whether the route is still valid based on its lifetime.
    ///
    /// - Returns: `true` if the route hasn't expired, `false` otherwise.
    public var isValid: Bool {
        return Date() < lifetime
    }
}

/// Messages exchanged in the AODV protocol.
///
/// AODV uses different message types for route discovery,
/// maintenance, and error handling.
public enum AODVMessage<NodeID: Hashable> {
    /// Route Request message for discovering new routes.
    case rreq(RouteRequest<NodeID>)
    
    /// Route Reply message containing route information.
    case rrep(RouteReply<NodeID>)
    
    /// Route Error message for reporting broken links.
    case rerr(RouteError<NodeID>)
    
    /// HELLO message for local connectivity maintenance.
    case hello(AODVHelloMessage<NodeID>)
}

/// Route Request (RREQ) message for route discovery.
///
/// RREQ messages are broadcast to discover routes to destinations.
/// They create reverse routes as they propagate through the network.
public struct RouteRequest<NodeID: Hashable> {
    /// The node originating the route request.
    public let source: NodeID
    
    /// Source sequence number to ensure route freshness.
    public let sourceSequenceNumber: Int
    
    /// Unique identifier for this RREQ to detect duplicates.
    ///
    /// Combined with source address to uniquely identify each RREQ.
    public let broadcastID: Int
    
    /// The destination node being sought.
    public let destination: NodeID
    
    /// Last known sequence number for the destination.
    ///
    /// Used to ensure replies contain fresh route information.
    public let destinationSequenceNumber: Int
    
    /// Number of hops from the source.
    ///
    /// Incremented by each forwarding node.
    public var hopCount: Int
}

/// Route Reply (RREP) message containing route information.
///
/// RREP messages are unicast back along the reverse path established
/// by the RREQ, creating forward routes as they travel.
public struct RouteReply<NodeID: Hashable> {
    /// The source node that initiated route discovery.
    public let source: NodeID
    
    /// The destination node for which route is provided.
    public let destination: NodeID
    
    /// Destination sequence number ensuring route freshness.
    public let destinationSequenceNumber: Int
    
    /// Number of hops to the destination.
    ///
    /// Incremented by each forwarding node.
    public var hopCount: Int
    
    /// Lifetime of the route being advertised.
    ///
    /// Nodes should mark routes invalid after this time.
    public let lifetime: Date
}

/// Route Error (RERR) message for reporting broken links.
///
/// RERR messages inform nodes about unreachable destinations
/// due to link breaks or node failures.
public struct RouteError<NodeID: Hashable> {
    /// Set of destinations that have become unreachable.
    ///
    /// Nodes receiving RERR should invalidate routes to these destinations.
    public let unreachableDestinations: Set<NodeID>
}

/// HELLO message for local connectivity maintenance.
///
/// Periodic HELLO messages detect link breaks to neighbors
/// in the absence of other traffic.
public struct AODVHelloMessage<NodeID: Hashable> {
    /// The node sending this HELLO message.
    public let source: NodeID
    
    /// Sequence number of the sending node.
    ///
    /// Allows neighbors to track node restarts and route freshness.
    public let sequenceNumber: Int
}

struct RREQIdentifier<NodeID: Hashable>: Hashable {
    let source: NodeID
    let broadcastID: Int
}

struct PendingRequest<NodeID: Hashable> {
    let request: RouteRequest<NodeID>
    let timestamp: Date
}