import Testing
import Foundation
@testable import DisruptionTolerantNetworking

@Suite("Network Graph Visualization Tests")
struct NetworkGraphTests {
    
    @Test func olsrNetworkGraph() {
        // Create a small network topology
        let nodeA = Node(id: "A")
        let olsr = OLSR(localNode: nodeA)
        
        // Add neighbors
        olsr.neighborUp("B")
        olsr.neighborUp("C")
        
        // Simulate topology information from B
        let tcFromB = TopologyControlMessage(
            originatorAddress: "B",
            ansn: 1,
            advertisedNeighborSet: ["D", "E"]
        )
        olsr.processUpdate(.tc(tcFromB), from: "B")
        
        // Extract network graph
        let graph = olsr.networkGraph()
        
        // Verify nodes
        #expect(graph.nodes.contains("A"))
        #expect(graph.nodes.contains("B"))
        #expect(graph.nodes.contains("C"))
        #expect(graph.nodes.contains("D"))
        #expect(graph.nodes.contains("E"))
        
        // Verify local node metadata
        #expect(graph.nodeMetadata["A"]?.isLocal == true)
        #expect(graph.nodeMetadata["A"]?.type == "local")
        
        // Verify edges exist
        #expect(graph.edges.contains(Edge(source: "A", destination: "B")))
        #expect(graph.edges.contains(Edge(source: "A", destination: "C")))
        #expect(graph.edges.contains(Edge(source: "B", destination: "D")))
        #expect(graph.edges.contains(Edge(source: "B", destination: "E")))
    }
    
    @Test func aodvNetworkGraph() {
        // Create a small network
        let nodeA = Node(id: "A")
        let aodv = AODV(localNode: nodeA)
        
        // Add neighbors
        aodv.neighborUp("B")
        aodv.neighborUp("C")
        
        // Add route through B to D
        let rrep = RouteReply(
            source: "A",
            destination: "D",
            destinationSequenceNumber: 1,
            hopCount: 2,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrep), from: "B")
        
        // Extract network graph
        let graph = aodv.networkGraph()
        
        // Verify nodes
        #expect(graph.nodes.contains("A"))
        #expect(graph.nodes.contains("B"))
        #expect(graph.nodes.contains("C"))
        #expect(graph.nodes.contains("D"))
        
        // Verify local node
        #expect(graph.nodeMetadata["A"]?.isLocal == true)
        
        // Verify neighbor metadata
        #expect(graph.nodeMetadata["B"]?.type == "neighbor")
        #expect(graph.nodeMetadata["C"]?.type == "neighbor")
        
        // Verify remote node
        #expect(graph.nodeMetadata["D"]?.type == "remote")
        
        // Verify direct edges
        #expect(graph.edges.contains(Edge(source: "A", destination: "B")))
        #expect(graph.edges.contains(Edge(source: "A", destination: "C")))
    }
    
    @Test func dotExport() {
        // Create simple graph
        let edges: Set<Edge<String>> = [
            Edge(source: "A", destination: "B"),
            Edge(source: "B", destination: "C")
        ]
        
        let nodeMetadata: [String: NodeMetadata] = [
            "A": NodeMetadata(label: "Node A", type: "local", isLocal: true),
            "B": NodeMetadata(label: "Node B", type: "mpr"),
            "C": NodeMetadata(label: "Node C", type: "neighbor")
        ]
        
        let graph = NetworkGraph(
            nodes: ["A", "B", "C"],
            edges: edges,
            nodeMetadata: nodeMetadata
        )
        
        let dot = graph.exportDOT()
        
        // Verify DOT format contains expected elements
        #expect(dot.contains("digraph Network"))
        #expect(dot.contains("\"A\" [label=\"Node A\""))
        #expect(dot.contains("fillcolor=lightblue")) // Local node
        #expect(dot.contains("fillcolor=lightgreen")) // MPR node
        #expect(dot.contains("\"A\" -> \"B\""))
        #expect(dot.contains("\"B\" -> \"C\""))
    }
    
    @Test func jsonExport() {
        // Create simple graph
        let edges: Set<Edge<String>> = [
            Edge(source: "A", destination: "B")
        ]
        
        let edgeMetadata: [Edge<String>: EdgeMetadata] = [
            Edge(source: "A", destination: "B"): EdgeMetadata(
                weight: 1,
                type: "direct",
                isActive: true
            )
        ]
        
        let graph = NetworkGraph(
            nodes: ["A", "B"],
            edges: edges,
            nodeMetadata: [:],
            edgeMetadata: edgeMetadata
        )
        
        let json = graph.exportJSON()
        
        // Verify JSON structure
        #expect(json["nodes"] != nil)
        #expect(json["edges"] != nil)
        
        if let nodes = json["nodes"] as? [[String: Any]] {
            #expect(nodes.count == 2)
        }
        
        if let edges = json["edges"] as? [[String: Any]] {
            #expect(edges.count == 1)
            if let firstEdge = edges.first {
                #expect(firstEdge["source"] as? String == "A")
                #expect(firstEdge["target"] as? String == "B")
                #expect(firstEdge["weight"] as? Int == 1)
                #expect(firstEdge["type"] as? String == "direct")
            }
        }
    }
    
    @Test func mprVisualization() {
        // Create network where MPR selection matters
        let nodeA = Node(id: "A")
        let olsr = OLSR(localNode: nodeA)
        
        // A has neighbors B and C
        olsr.neighborUp("B")
        olsr.neighborUp("C")
        
        // B can reach D, C can reach E and F
        let helloFromB = OLSRHelloMessage(
            originatorAddress: "B",
            neighbors: [
                NeighborInfo(nodeID: "A", linkType: .symmetric),
                NeighborInfo(nodeID: "D", linkType: .symmetric)
            ],
            sequenceNumber: 1
        )
        olsr.processUpdate(.hello(helloFromB), from: "B")
        
        let helloFromC = OLSRHelloMessage(
            originatorAddress: "C",
            neighbors: [
                NeighborInfo(nodeID: "A", linkType: .symmetric),
                NeighborInfo(nodeID: "E", linkType: .symmetric),
                NeighborInfo(nodeID: "F", linkType: .symmetric)
            ],
            sequenceNumber: 1
        )
        olsr.processUpdate(.hello(helloFromC), from: "C")
        
        let graph = olsr.networkGraph()
        
        // Check that MPRs are properly marked
        let mprNodes = graph.nodeMetadata.filter { $0.value.type == "mpr" }
        #expect(!mprNodes.isEmpty)
        
        // Export to DOT for visualization
        let dot = graph.exportDOT()
        #expect(dot.contains("fillcolor=lightgreen")) // MPR nodes should be green
    }
}