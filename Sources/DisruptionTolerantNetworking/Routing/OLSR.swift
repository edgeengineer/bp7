#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An implementation of the Optimized Link State Routing (OLSR) protocol.
///
/// OLSR is a proactive, table-driven routing protocol designed for mobile ad hoc networks.
/// It uses a link state algorithm and employs Multipoint Relays (MPRs) to efficiently
/// disseminate topology information throughout the network.
///
/// ## Overview
///
/// Key features of this OLSR implementation:
/// - **Proactive routing**: Maintains routes to all destinations at all times
/// - **MPR optimization**: Reduces flooding overhead by selecting subset of neighbors
/// - **Periodic updates**: Exchanges HELLO and Topology Control (TC) messages
/// - **Fast convergence**: Quickly adapts to topology changes
///
/// ## Topics
///
/// ### Initialization
///
/// Create an OLSR instance for a node:
/// ```swift
/// let node = Node(id: "node1")
/// let olsr = OLSR(localNode: node)
/// ```
///
/// ### Message Types
///
/// OLSR uses two main message types:
/// - **HELLO messages**: Discover and maintain neighbor relationships
/// - **TC messages**: Disseminate topology information through MPRs
///
/// ### Multipoint Relays (MPRs)
///
/// MPRs are selected neighbors that forward broadcast messages, reducing network overhead
/// while ensuring all nodes receive topology updates.
///
/// ## Implementation Details
///
/// This implementation maintains several data structures:
/// - Neighbor set: Direct neighbors
/// - 2-hop neighbor set: Nodes reachable through neighbors
/// - MPR set: Selected multipoint relays
/// - Topology set: Network-wide topology information
/// - Routing table: Computed shortest paths to all destinations
public final class OLSR<NodeID: Hashable>: RoutingAlgorithm {
    internal let localNode: Node<NodeID>
    private var routingTable: [NodeID: OLSRRoute<NodeID>] = [:]
    private var linkSet: Set<Link<NodeID>> = []
    internal var neighborSet: Set<NodeID> = []
    private var twoHopNeighborSet: Set<TwoHopNeighbor<NodeID>> = []
    internal var mprSet: Set<NodeID> = []
    private var mprSelectorSet: Set<NodeID> = []
    internal var topologySet: Set<TopologyTuple<NodeID>> = []
    
    public typealias RouteEntry = OLSRRoute<NodeID>
    public typealias RoutingUpdate = OLSRMessage<NodeID>
    
    public init(localNode: Node<NodeID>) {
        self.localNode = localNode
    }
    
    public func nextHop(to destination: NodeID) -> NodeID? {
        return routingTable[destination]?.nextHop
    }
    
    public func processUpdate(_ update: OLSRMessage<NodeID>, from: NodeID) {
        switch update {
        case .hello(let helloMessage):
            processHelloMessage(helloMessage, from: from)
        case .tc(let tcMessage):
            processTopologyControlMessage(tcMessage, from: from)
        }
        
        calculateRoutingTable()
    }
    
    public func generateUpdate() -> OLSRMessage<NodeID> {
        let neighbors = neighborSet.map { nodeID in
            NeighborInfo(nodeID: nodeID, linkType: .symmetric)
        }
        
        let helloMessage = OLSRHelloMessage(
            originatorAddress: localNode.id,
            neighbors: neighbors,
            sequenceNumber: generateSequenceNumber()
        )
        
        return .hello(helloMessage)
    }
    
    public func neighborUp(_ neighbor: NodeID) {
        neighborSet.insert(neighbor)
        linkSet.insert(Link(local: localNode.id, remote: neighbor))
        selectMPRs()
        calculateRoutingTable()
    }
    
    public func neighborDown(_ neighbor: NodeID) {
        neighborSet.remove(neighbor)
        linkSet.remove(Link(local: localNode.id, remote: neighbor))
        mprSet.remove(neighbor)
        mprSelectorSet.remove(neighbor)
        
        // Remove two-hop neighbors reached only through this neighbor
        twoHopNeighborSet = twoHopNeighborSet.filter { $0.neighbor != neighbor }
        
        selectMPRs()
        calculateRoutingTable()
    }
    
    public func getRoutes() -> [OLSRRoute<NodeID>] {
        return Array(routingTable.values)
    }
    
    public func costTo(_ destination: NodeID) -> Int? {
        return routingTable[destination]?.hopCount
    }
    
    // MARK: - Private Methods
    
    private func processHelloMessage(_ message: OLSRHelloMessage<NodeID>, from: NodeID) {
        // Update neighbor information
        for neighborInfo in message.neighbors {
            if neighborInfo.nodeID == localNode.id {
                // This neighbor sees us
                if neighborInfo.linkType == .symmetric {
                    neighborSet.insert(from)
                }
            } else {
                // Two-hop neighbor
                let twoHop = TwoHopNeighbor(neighbor: from, twoHopNeighbor: neighborInfo.nodeID)
                twoHopNeighborSet.insert(twoHop)
            }
        }
        
        selectMPRs()
    }
    
    private func processTopologyControlMessage(_ message: TopologyControlMessage<NodeID>, from: NodeID) {
        // Update topology information
        for advertisedNeighbor in message.advertisedNeighborSet {
            let tuple = TopologyTuple(
                destinationAddress: advertisedNeighbor,
                lastHopAddress: message.originatorAddress,
                sequenceNumber: message.ansn
            )
            topologySet.insert(tuple)
        }
    }
    
    private func selectMPRs() {
        mprSet.removeAll()
        
        // Simple MPR selection: select neighbors that cover all two-hop neighbors
        var uncoveredTwoHopNeighbors = Set(twoHopNeighborSet.map { $0.twoHopNeighbor })
        
        while !uncoveredTwoHopNeighbors.isEmpty {
            var bestNeighbor: NodeID?
            var bestCoverage = 0
            
            for neighbor in neighborSet {
                let coverage = twoHopNeighborSet
                    .filter { $0.neighbor == neighbor && uncoveredTwoHopNeighbors.contains($0.twoHopNeighbor) }
                    .count
                
                if coverage > bestCoverage {
                    bestCoverage = coverage
                    bestNeighbor = neighbor
                }
            }
            
            if let selected = bestNeighbor {
                mprSet.insert(selected)
                // Remove covered two-hop neighbors
                for twoHop in twoHopNeighborSet where twoHop.neighbor == selected {
                    uncoveredTwoHopNeighbors.remove(twoHop.twoHopNeighbor)
                }
            } else {
                break
            }
        }
    }
    
    private func calculateRoutingTable() {
        routingTable.removeAll()
        
        // Add direct neighbors
        for neighbor in neighborSet {
            routingTable[neighbor] = OLSRRoute(
                destination: neighbor,
                nextHop: neighbor,
                hopCount: 1,
                sequenceNumber: 0
            )
        }
        
        // Calculate routes using Dijkstra's algorithm
        var distances: [NodeID: Int] = [localNode.id: 0]
        var nextHops: [NodeID: NodeID] = [:]
        var visited: Set<NodeID> = []
        
        // Initialize with neighbors
        for neighbor in neighborSet {
            distances[neighbor] = 1
            nextHops[neighbor] = neighbor
        }
        
        while visited.count < distances.count {
            // Find unvisited node with minimum distance
            let current = distances
                .filter { !visited.contains($0.key) }
                .min { $0.value < $1.value }?.key
            
            guard let currentNode = current else { break }
            visited.insert(currentNode)
            
            // Update distances through topology information
            for topology in topologySet where topology.lastHopAddress == currentNode {
                let newDistance = (distances[currentNode] ?? Int.max) + 1
                if newDistance < (distances[topology.destinationAddress] ?? Int.max) {
                    distances[topology.destinationAddress] = newDistance
                    nextHops[topology.destinationAddress] = nextHops[currentNode] ?? currentNode
                }
            }
        }
        
        // Build routing table
        for (destination, distance) in distances where destination != localNode.id {
            if let nextHop = nextHops[destination] {
                routingTable[destination] = OLSRRoute(
                    destination: destination,
                    nextHop: nextHop,
                    hopCount: distance,
                    sequenceNumber: 0
                )
            }
        }
    }
    
    private var sequenceCounter: Int = 0
    private func generateSequenceNumber() -> Int {
        sequenceCounter += 1
        return sequenceCounter
    }
}

// MARK: - OLSR Data Structures

/// A route entry in the OLSR routing table.
///
/// Contains the essential information needed to forward packets to a destination.
public struct OLSRRoute<NodeID: Hashable> {
    /// The destination node for this route.
    public let destination: NodeID
    
    /// The next hop node to reach the destination.
    public let nextHop: NodeID
    
    /// The number of hops to reach the destination.
    public let hopCount: Int
    
    /// Sequence number for route versioning.
    public let sequenceNumber: Int
}

/// Messages exchanged in the OLSR protocol.
///
/// OLSR uses two primary message types for topology discovery and maintenance.
public enum OLSRMessage<NodeID: Hashable> {
    /// HELLO message for neighbor discovery and link sensing.
    case hello(OLSRHelloMessage<NodeID>)
    
    /// Topology Control message for disseminating link state information.
    case tc(TopologyControlMessage<NodeID>)
}

/// HELLO message used for neighbor discovery in OLSR.
///
/// HELLO messages serve multiple purposes:
/// - Neighbor discovery
/// - Link bidirectionality check
/// - MPR selector detection
/// - Link quality sensing
public struct OLSRHelloMessage<NodeID: Hashable> {
    /// The node originating this HELLO message.
    public let originatorAddress: NodeID
    
    /// List of neighbors known to the originator.
    ///
    /// Includes link type information for each neighbor.
    public let neighbors: [NeighborInfo<NodeID>]
    
    /// Sequence number to track message freshness.
    public let sequenceNumber: Int
}

/// Information about a neighbor in HELLO messages.
public struct NeighborInfo<NodeID: Hashable> {
    /// The neighbor node's identifier.
    public let nodeID: NodeID
    
    /// The type of link to this neighbor.
    public let linkType: LinkType
}

/// Types of links between OLSR nodes.
///
/// Link types are used to track the status of neighbor relationships.
public enum LinkType {
    /// Link heard from neighbor but bidirectionality not confirmed.
    case asymmetric
    
    /// Bidirectional link confirmed through HELLO exchange.
    case symmetric
    
    /// Neighbor selected as Multipoint Relay.
    case mpr
    
    /// Previously known link that is now lost.
    case lost
}

/// Topology Control (TC) message for link state dissemination.
///
/// TC messages are generated by nodes that have been selected as MPRs
/// and contain information about their MPR selectors.
public struct TopologyControlMessage<NodeID: Hashable> {
    /// The node originating this TC message.
    public let originatorAddress: NodeID
    
    /// Advertised Neighbor Sequence Number.
    ///
    /// Used to track the freshness of topology information.
    public let ansn: Int
    
    /// Set of nodes that have selected the originator as their MPR.
    ///
    /// These are the nodes for which the originator will forward traffic.
    public let advertisedNeighborSet: Set<NodeID>
}

struct Link<NodeID: Hashable>: Hashable {
    let local: NodeID
    let remote: NodeID
}

struct TwoHopNeighbor<NodeID: Hashable>: Hashable {
    let neighbor: NodeID
    let twoHopNeighbor: NodeID
}

struct TopologyTuple<NodeID: Hashable>: Hashable {
    let destinationAddress: NodeID
    let lastHopAddress: NodeID
    let sequenceNumber: Int
}