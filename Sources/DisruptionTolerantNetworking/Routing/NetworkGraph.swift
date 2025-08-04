#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A graph representation of the network topology for visualization purposes.
///
/// This structure captures the nodes and edges in a network as seen by a routing algorithm,
/// making it suitable for visualization tools and network analysis.
///
/// ## Overview
///
/// The `NetworkGraph` provides a unified way to extract topology information from
/// different routing algorithms. It represents the network as nodes (vertices) and
/// edges (links between nodes).
///
/// ## Example Usage
///
/// ```swift
/// let olsr = OLSR(localNode: Node(id: "A"))
/// // ... routing operations ...
/// let graph = olsr.networkGraph()
/// 
/// print("Nodes: \(graph.nodes)")
/// print("Edges: \(graph.edges.count)")
/// ```
public struct NetworkGraph<NodeID: Hashable> {
    /// Set of all nodes in the network.
    public let nodes: Set<NodeID>
    
    /// Set of edges representing links between nodes.
    public let edges: Set<Edge<NodeID>>
    
    /// Additional metadata for nodes (e.g., position, label, color).
    public let nodeMetadata: [NodeID: NodeMetadata]
    
    /// Additional metadata for edges (e.g., weight, type, color).
    public let edgeMetadata: [Edge<NodeID>: EdgeMetadata]
    
    /// Creates a new network graph.
    ///
    /// - Parameters:
    ///   - nodes: Set of node identifiers.
    ///   - edges: Set of edges between nodes.
    ///   - nodeMetadata: Optional metadata for nodes.
    ///   - edgeMetadata: Optional metadata for edges.
    public init(
        nodes: Set<NodeID>,
        edges: Set<Edge<NodeID>>,
        nodeMetadata: [NodeID: NodeMetadata] = [:],
        edgeMetadata: [Edge<NodeID>: EdgeMetadata] = [:]
    ) {
        self.nodes = nodes
        self.edges = edges
        self.nodeMetadata = nodeMetadata
        self.edgeMetadata = edgeMetadata
    }
}

/// An edge in the network graph.
///
/// Represents a directed link from source to destination.
/// For undirected graphs, create two edges (one in each direction).
public struct Edge<NodeID: Hashable>: Hashable {
    /// The source node of the edge.
    public let source: NodeID
    
    /// The destination node of the edge.
    public let destination: NodeID
    
    /// Creates a new edge.
    ///
    /// - Parameters:
    ///   - source: The source node.
    ///   - destination: The destination node.
    public init(source: NodeID, destination: NodeID) {
        self.source = source
        self.destination = destination
    }
}

/// Metadata associated with a node in the graph.
///
/// Use this to store visualization-specific information.
public struct NodeMetadata {
    /// Display label for the node.
    public let label: String?
    
    /// Node type or role (e.g., "router", "endpoint", "mpr").
    public let type: String?
    
    /// Whether this is the local node.
    public let isLocal: Bool
    
    /// Custom attributes for visualization.
    public let attributes: [String: String]
    
    /// Creates node metadata.
    ///
    /// - Parameters:
    ///   - label: Optional display label.
    ///   - type: Optional node type.
    ///   - isLocal: Whether this is the local node.
    ///   - attributes: Additional custom attributes.
    public init(
        label: String? = nil,
        type: String? = nil,
        isLocal: Bool = false,
        attributes: [String: String] = [:]
    ) {
        self.label = label
        self.type = type
        self.isLocal = isLocal
        self.attributes = attributes
    }
}

/// Metadata associated with an edge in the graph.
///
/// Use this to store link-specific information for visualization.
public struct EdgeMetadata {
    /// The cost or weight of the edge.
    public let weight: Int?
    
    /// The type of edge (e.g., "direct", "multihop", "mpr").
    public let type: String?
    
    /// Whether this edge is currently active.
    public let isActive: Bool
    
    /// Custom attributes for visualization.
    public let attributes: [String: String]
    
    /// Creates edge metadata.
    ///
    /// - Parameters:
    ///   - weight: Optional edge weight or cost.
    ///   - type: Optional edge type.
    ///   - isActive: Whether the edge is active.
    ///   - attributes: Additional custom attributes.
    public init(
        weight: Int? = nil,
        type: String? = nil,
        isActive: Bool = true,
        attributes: [String: String] = [:]
    ) {
        self.weight = weight
        self.type = type
        self.isActive = isActive
        self.attributes = attributes
    }
}

// MARK: - Graph Extraction Protocol

/// Protocol for routing algorithms that can provide network graph visualization.
public protocol NetworkGraphProvider {
    /// The type of node identifier.
    associatedtype NodeID: Hashable
    
    /// Extracts the current network topology as a graph.
    ///
    /// - Returns: A `NetworkGraph` representing the current network state.
    func networkGraph() -> NetworkGraph<NodeID>
}

// MARK: - OLSR Graph Extraction

extension OLSR: NetworkGraphProvider {
    /// Extracts the network topology from OLSR's perspective.
    ///
    /// The graph includes:
    /// - All known nodes (local, neighbors, and remote nodes)
    /// - Direct neighbor links
    /// - Links discovered through topology control messages
    /// - MPR relationships
    public func networkGraph() -> NetworkGraph<NodeID> {
        var nodes: Set<NodeID> = [localNode.id]
        var edges: Set<Edge<NodeID>> = []
        var nodeMetadata: [NodeID: NodeMetadata] = [:]
        var edgeMetadata: [Edge<NodeID>: EdgeMetadata] = [:]
        
        // Add local node metadata
        nodeMetadata[localNode.id] = NodeMetadata(
            label: String(describing: localNode.id),
            type: "local",
            isLocal: true
        )
        
        // Add direct neighbors
        for neighbor in neighborSet {
            nodes.insert(neighbor)
            let edge = Edge(source: localNode.id, destination: neighbor)
            edges.insert(edge)
            
            // Check if neighbor is MPR
            let isMPR = mprSet.contains(neighbor)
            nodeMetadata[neighbor] = NodeMetadata(
                label: String(describing: neighbor),
                type: isMPR ? "mpr" : "neighbor"
            )
            
            edgeMetadata[edge] = EdgeMetadata(
                weight: 1,
                type: "direct",
                isActive: true
            )
            
            // Add reverse edge for bidirectional link
            let reverseEdge = Edge(source: neighbor, destination: localNode.id)
            edges.insert(reverseEdge)
            edgeMetadata[reverseEdge] = EdgeMetadata(
                weight: 1,
                type: "direct",
                isActive: true
            )
        }
        
        // Add topology information
        for topology in topologySet {
            nodes.insert(topology.destinationAddress)
            nodes.insert(topology.lastHopAddress)
            
            let edge = Edge(
                source: topology.lastHopAddress,
                destination: topology.destinationAddress
            )
            edges.insert(edge)
            
            // Add metadata for remote nodes
            if nodeMetadata[topology.destinationAddress] == nil {
                nodeMetadata[topology.destinationAddress] = NodeMetadata(
                    label: String(describing: topology.destinationAddress),
                    type: "remote"
                )
            }
            
            edgeMetadata[edge] = EdgeMetadata(
                weight: 1,
                type: "topology",
                isActive: true
            )
        }
        
        // Add routing table information
        for route in getRoutes() {
            nodes.insert(route.destination)
            
            // Add edge from local to destination via next hop
            if route.nextHop != route.destination {
                let routeEdge = Edge(
                    source: localNode.id,
                    destination: route.destination
                )
                
                edgeMetadata[routeEdge] = EdgeMetadata(
                    weight: route.hopCount,
                    type: "route",
                    isActive: true,
                    attributes: ["nextHop": String(describing: route.nextHop)]
                )
            }
        }
        
        return NetworkGraph(
            nodes: nodes,
            edges: edges,
            nodeMetadata: nodeMetadata,
            edgeMetadata: edgeMetadata
        )
    }
}

// MARK: - AODV Graph Extraction

extension AODV: NetworkGraphProvider {
    /// Extracts the network topology from AODV's perspective.
    ///
    /// The graph includes:
    /// - Local node and known neighbors
    /// - Active routes with their next hops
    /// - Route costs (hop counts)
    ///
    /// Note: AODV has limited topology knowledge compared to OLSR
    /// since it's a reactive protocol.
    public func networkGraph() -> NetworkGraph<NodeID> {
        var nodes: Set<NodeID> = [localNode.id]
        var edges: Set<Edge<NodeID>> = []
        var nodeMetadata: [NodeID: NodeMetadata] = [:]
        var edgeMetadata: [Edge<NodeID>: EdgeMetadata] = [:]
        
        // Add local node metadata
        nodeMetadata[localNode.id] = NodeMetadata(
            label: String(describing: localNode.id),
            type: "local",
            isLocal: true
        )
        
        // Add direct neighbors
        for neighbor in neighbors {
            nodes.insert(neighbor)
            let edge = Edge(source: localNode.id, destination: neighbor)
            edges.insert(edge)
            
            nodeMetadata[neighbor] = NodeMetadata(
                label: String(describing: neighbor),
                type: "neighbor"
            )
            
            edgeMetadata[edge] = EdgeMetadata(
                weight: 1,
                type: "direct",
                isActive: true
            )
            
            // Add reverse edge for bidirectional link
            let reverseEdge = Edge(source: neighbor, destination: localNode.id)
            edges.insert(reverseEdge)
            edgeMetadata[reverseEdge] = EdgeMetadata(
                weight: 1,
                type: "direct",
                isActive: true
            )
        }
        
        // Add routing table entries
        for route in getRoutes() where route.isValid {
            nodes.insert(route.destination)
            
            // If destination is not a direct neighbor, add the routing path
            if !neighbors.contains(route.destination) {
                // Add the destination node
                nodeMetadata[route.destination] = NodeMetadata(
                    label: String(describing: route.destination),
                    type: "remote"
                )
                
                // Add logical edge showing the route
                let routeEdge = Edge(
                    source: localNode.id,
                    destination: route.destination
                )
                
                edgeMetadata[routeEdge] = EdgeMetadata(
                    weight: route.hopCount,
                    type: "route",
                    isActive: true,
                    attributes: [
                        "nextHop": String(describing: route.nextHop),
                        "sequenceNumber": String(route.sequenceNumber)
                    ]
                )
            }
        }
        
        return NetworkGraph(
            nodes: nodes,
            edges: edges,
            nodeMetadata: nodeMetadata,
            edgeMetadata: edgeMetadata
        )
    }
}

// MARK: - Graph Export Formats

extension NetworkGraph {
    /// Exports the graph in DOT format for Graphviz visualization.
    ///
    /// Example usage:
    /// ```swift
    /// let dot = graph.exportDOT()
    /// // Save to file and visualize with: dot -Tpng graph.dot -o graph.png
    /// ```
    ///
    /// - Returns: A string containing the graph in DOT format.
    public func exportDOT() -> String {
        var dot = "digraph Network {\n"
        dot += "    rankdir=LR;\n"
        dot += "    node [shape=circle];\n\n"
        
        // Add nodes
        for node in nodes {
            let metadata = nodeMetadata[node]
            let label = metadata?.label ?? String(describing: node)
            var attributes = ["label=\"\(label)\""]
            
            if metadata?.isLocal == true {
                attributes.append("style=filled")
                attributes.append("fillcolor=lightblue")
            } else if metadata?.type == "mpr" {
                attributes.append("style=filled")
                attributes.append("fillcolor=lightgreen")
            } else if metadata?.type == "neighbor" {
                attributes.append("style=filled")
                attributes.append("fillcolor=lightyellow")
            }
            
            dot += "    \"\(node)\" [\(attributes.joined(separator: ", "))];\n"
        }
        
        dot += "\n"
        
        // Add edges
        for edge in edges {
            let metadata = edgeMetadata[edge]
            var attributes: [String] = []
            
            if let weight = metadata?.weight {
                attributes.append("label=\"\(weight)\"")
            }
            
            if metadata?.type == "direct" {
                attributes.append("color=black")
                attributes.append("penwidth=2")
            } else if metadata?.type == "route" {
                attributes.append("color=blue")
                attributes.append("style=dashed")
            } else if metadata?.type == "topology" {
                attributes.append("color=gray")
            }
            
            let attrString = attributes.isEmpty ? "" : " [\(attributes.joined(separator: ", "))]"
            dot += "    \"\(edge.source)\" -> \"\(edge.destination)\"\(attrString);\n"
        }
        
        dot += "}\n"
        return dot
    }
    
    /// Exports the graph as a JSON structure.
    ///
    /// The JSON format is compatible with many graph visualization libraries
    /// like D3.js, vis.js, and Cytoscape.js.
    ///
    /// - Returns: A dictionary representing the graph structure.
    public func exportJSON() -> [String: Any] {
        var nodesArray: [[String: Any]] = []
        var edgesArray: [[String: Any]] = []
        
        // Export nodes
        for node in nodes {
            var nodeDict: [String: Any] = ["id": String(describing: node)]
            
            if let metadata = nodeMetadata[node] {
                if let label = metadata.label {
                    nodeDict["label"] = label
                }
                if let type = metadata.type {
                    nodeDict["type"] = type
                }
                nodeDict["isLocal"] = metadata.isLocal
                
                if !metadata.attributes.isEmpty {
                    nodeDict["attributes"] = metadata.attributes
                }
            }
            
            nodesArray.append(nodeDict)
        }
        
        // Export edges
        for edge in edges {
            var edgeDict: [String: Any] = [
                "source": String(describing: edge.source),
                "target": String(describing: edge.destination)
            ]
            
            if let metadata = edgeMetadata[edge] {
                if let weight = metadata.weight {
                    edgeDict["weight"] = weight
                }
                if let type = metadata.type {
                    edgeDict["type"] = type
                }
                edgeDict["isActive"] = metadata.isActive
                
                if !metadata.attributes.isEmpty {
                    edgeDict["attributes"] = metadata.attributes
                }
            }
            
            edgesArray.append(edgeDict)
        }
        
        return [
            "nodes": nodesArray,
            "edges": edgesArray
        ]
    }
}