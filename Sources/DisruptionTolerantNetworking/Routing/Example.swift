import Foundation

/// Example usage of routing algorithms with network graph visualization.
///
/// This example demonstrates how to:
/// 1. Create routing algorithm instances
/// 2. Build a network topology
/// 3. Extract and visualize the network graph
public struct RoutingExample {
    
    /// Demonstrates OLSR routing with graph visualization.
    public static func olsrExample() {
        print("=== OLSR Network Example ===\n")
        
        // Create nodes
        let nodeA = Node(id: "A")
        let nodeB = Node(id: "B")
        let nodeC = Node(id: "C")
        
        // Create OLSR instances for each node
        let olsrA = OLSR(localNode: nodeA)
        let olsrB = OLSR(localNode: nodeB)
        let olsrC = OLSR(localNode: nodeC)
        
        // Establish neighbor relationships
        olsrA.neighborUp("B")
        olsrA.neighborUp("C")
        
        olsrB.neighborUp("A")
        olsrB.neighborUp("C")
        olsrB.neighborUp("D")
        
        olsrC.neighborUp("A")
        olsrC.neighborUp("B")
        olsrC.neighborUp("E")
        
        // Exchange HELLO messages
        let helloFromB = olsrB.generateUpdate()
        olsrA.processUpdate(helloFromB, from: "B")
        
        let helloFromC = olsrC.generateUpdate()
        olsrA.processUpdate(helloFromC, from: "C")
        
        // Simulate topology control messages
        let tcFromB = TopologyControlMessage(
            originatorAddress: "B",
            ansn: 1,
            advertisedNeighborSet: ["D"]
        )
        olsrA.processUpdate(.tc(tcFromB), from: "B")
        
        let tcFromC = TopologyControlMessage(
            originatorAddress: "C",
            ansn: 1,
            advertisedNeighborSet: ["E"]
        )
        olsrA.processUpdate(.tc(tcFromC), from: "C")
        
        // Extract network graph from node A's perspective
        let graph = olsrA.networkGraph()
        
        print("Network as seen by Node A:")
        print("Nodes: \(graph.nodes.sorted())")
        print("\nRouting Table:")
        for route in olsrA.getRoutes().sorted(by: { $0.destination < $1.destination }) {
            print("  To \(route.destination): next hop = \(route.nextHop), hops = \(route.hopCount)")
        }
        
        // Export to DOT format
        print("\n=== DOT Format (for Graphviz) ===")
        print(graph.exportDOT())
        
        // Export to JSON
        print("\n=== JSON Format ===")
        if let jsonData = try? JSONSerialization.data(withJSONObject: graph.exportJSON(), options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    /// Demonstrates AODV routing with graph visualization.
    public static func aodvExample() {
        print("\n\n=== AODV Network Example ===\n")
        
        // Create nodes
        let nodeA = Node(id: "A")
        let nodeB = Node(id: "B")
        let nodeC = Node(id: "C")
        
        // Create AODV instances
        let aodvA = AODV(localNode: nodeA)
        let aodvB = AODV(localNode: nodeB)
        let aodvC = AODV(localNode: nodeC)
        
        // Establish neighbors
        aodvA.neighborUp("B")
        aodvA.neighborUp("C")
        
        aodvB.neighborUp("A")
        aodvB.neighborUp("D")
        
        aodvC.neighborUp("A")
        aodvC.neighborUp("E")
        
        // Simulate route discovery from A to D
        print("Discovering route from A to D...")
        
        // A wants to reach D but has no route
        if aodvA.nextHop(to: "D") == nil {
            print("No route to D, initiating route discovery...")
        }
        
        // Simulate RREQ propagation
        let rreq = RouteRequest(
            source: "A",
            sourceSequenceNumber: 1,
            broadcastID: 1,
            destination: "D",
            destinationSequenceNumber: 0,
            hopCount: 0
        )
        
        // B receives and processes RREQ from A
        aodvB.processUpdate(.rreq(rreq), from: "A")
        
        // D receives RREQ from B and sends RREP
        let rrep = RouteReply(
            source: "A",
            destination: "D",
            destinationSequenceNumber: 1,
            hopCount: 0,
            lifetime: Date().addingTimeInterval(300)
        )
        
        // B receives RREP from D
        aodvB.processUpdate(.rrep(rrep), from: "D")
        
        // A receives RREP from B
        aodvA.processUpdate(.rrep(rrep), from: "B")
        
        print("\nRoute discovery complete!")
        
        // Simulate route to E through C
        let rrepE = RouteReply(
            source: "A",
            destination: "E",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(300)
        )
        aodvA.processUpdate(.rrep(rrepE), from: "C")
        
        // Extract network graph
        let graph = aodvA.networkGraph()
        
        print("\nNetwork as seen by Node A:")
        print("Nodes: \(graph.nodes.sorted())")
        print("\nActive Routes:")
        for route in aodvA.getRoutes().sorted(by: { $0.destination < $1.destination }) {
            print("  To \(route.destination): next hop = \(route.nextHop), hops = \(route.hopCount)")
        }
        
        // Visualize the network
        print("\n=== Network Visualization ===")
        print(graph.exportDOT())
    }
    
    /// Runs all examples.
    public static func runExamples() {
        olsrExample()
        aodvExample()
        
        print("\n\n=== Visualization Instructions ===")
        print("1. Save the DOT output to a file (e.g., network.dot)")
        print("2. Use Graphviz to generate an image:")
        print("   dot -Tpng network.dot -o network.png")
        print("3. Or use online tools like http://www.webgraphviz.com/")
        print("\nFor interactive visualization, use the JSON output with:")
        print("- D3.js (https://d3js.org/)")
        print("- Cytoscape.js (https://js.cytoscape.org/)")
        print("- vis.js (https://visjs.org/)")
    }
}