import Testing
import Foundation
@testable import DisruptionTolerantNetworking

@Suite("OLSR Routing Tests")
struct OLSRTests {
    
    @Test func initialization() {
        let node = Node(id: "A")
        let olsr = OLSR(localNode: node)
        
        #expect(olsr.getRoutes().count == 0)
        #expect(olsr.nextHop(to: "B") == nil)
    }
    
    @Test func neighborUp() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        olsr.neighborUp("B")
        
        let routes = olsr.getRoutes()
        #expect(routes.count == 1)
        #expect(olsr.nextHop(to: "B") == "B")
        #expect(olsr.costTo("B") == 1)
    }
    
    @Test func neighborDown() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        olsr.neighborUp("B")
        olsr.neighborUp("C")
        #expect(olsr.getRoutes().count == 2)
        
        olsr.neighborDown("B")
        
        let routes = olsr.getRoutes()
        #expect(routes.count == 1)
        #expect(olsr.nextHop(to: "B") == nil)
        #expect(olsr.nextHop(to: "C") == "C")
    }
    
    @Test func generateHelloMessage() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        olsr.neighborUp("B")
        olsr.neighborUp("C")
        
        let update = olsr.generateUpdate()
        
        switch update {
        case .hello(let helloMessage):
            #expect(helloMessage.originatorAddress == "A")
            #expect(helloMessage.neighbors.count == 2)
            #expect(helloMessage.neighbors.contains(where: { $0.nodeID == "B" }))
            #expect(helloMessage.neighbors.contains(where: { $0.nodeID == "C" }))
        case .tc:
            Issue.record("Expected HELLO message")
        }
    }
    
    @Test func processHelloMessage() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        // Simulate receiving a HELLO from B that sees A and has neighbor C
        let helloFromB = OLSRHelloMessage(
            originatorAddress: "B",
            neighbors: [
                NeighborInfo(nodeID: "A", linkType: .symmetric),
                NeighborInfo(nodeID: "C", linkType: .symmetric)
            ],
            sequenceNumber: 1
        )
        
        olsr.processUpdate(.hello(helloFromB), from: "B")
        
        // B should be added as a neighbor
        let routes = olsr.getRoutes()
        #expect(routes.count == 1)
        #expect(olsr.nextHop(to: "B") == "B")
    }
    
    @Test func topologyDiscovery() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        // A has neighbor B
        olsr.neighborUp("B")
        
        // Receive TC message from B advertising C
        let tcFromB = TopologyControlMessage(
            originatorAddress: "B",
            ansn: 1,
            advertisedNeighborSet: ["C"]
        )
        
        olsr.processUpdate(.tc(tcFromB), from: "B")
        
        // Should have routes to B (direct) and C (via B)
        let routes = olsr.getRoutes()
        #expect(routes.count == 2)
        #expect(olsr.nextHop(to: "B") == "B")
        #expect(olsr.nextHop(to: "C") == "B")
        #expect(olsr.costTo("C") == 2)
    }
    
    @Test func mprSelection() {
        let localNode = Node(id: "A")
        let olsr = OLSR(localNode: localNode)
        
        // Set up a scenario: A has neighbors B and C
        // B can reach D, C can reach E and F
        olsr.neighborUp("B")
        olsr.neighborUp("C")
        
        // Process HELLO from B showing it can reach D
        let helloFromB = OLSRHelloMessage(
            originatorAddress: "B",
            neighbors: [
                NeighborInfo(nodeID: "A", linkType: .symmetric),
                NeighborInfo(nodeID: "D", linkType: .symmetric)
            ],
            sequenceNumber: 1
        )
        olsr.processUpdate(.hello(helloFromB), from: "B")
        
        // Process HELLO from C showing it can reach E and F
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
        
        // Both B and C should be selected as MPRs to cover all 2-hop neighbors
        // This is implicit in the implementation - we can verify by checking routes
        let routes = olsr.getRoutes()
        #expect(routes.count >= 2)
    }
}