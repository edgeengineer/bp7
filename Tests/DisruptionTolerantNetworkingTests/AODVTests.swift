import Testing
import Foundation
@testable import DisruptionTolerantNetworking

@Suite("AODV Routing Tests")
struct AODVTests {
    
    @Test func initialization() {
        let node = Node(id: "A")
        let aodv = AODV(localNode: node)
        
        #expect(aodv.getRoutes().count == 0)
        #expect(aodv.nextHop(to: "B") == nil)
    }
    
    @Test func neighborUp() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        aodv.neighborUp("B")
        
        let routes = aodv.getRoutes()
        #expect(routes.count == 1)
        #expect(aodv.nextHop(to: "B") == "B")
        #expect(aodv.costTo("B") == 1)
    }
    
    @Test func neighborDown() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        aodv.neighborUp("B")
        aodv.neighborUp("C")
        
        // Add a route through B to D
        let rrepFromD = RouteReply(
            source: "A",
            destination: "D",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrepFromD), from: "B")
        
        #expect(aodv.getRoutes().count == 3)
        
        // When B goes down, routes through B should be removed
        aodv.neighborDown("B")
        
        let routes = aodv.getRoutes()
        #expect(routes.count == 1) // Only C remains
        #expect(aodv.nextHop(to: "B") == nil)
        #expect(aodv.nextHop(to: "D") == nil)
        #expect(aodv.nextHop(to: "C") == "C")
    }
    
    @Test func generateHelloMessage() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        let update = aodv.generateUpdate()
        
        switch update {
        case .hello(let hello):
            #expect(hello.source == "A")
            #expect(hello.sequenceNumber > 0)
        default:
            Issue.record("Expected HELLO message")
        }
    }
    
    @Test func routeRequestProcessing() {
        let localNode = Node(id: "B")
        let aodv = AODV(localNode: localNode)
        
        // A is looking for C, and B is intermediate node
        let rreq = RouteRequest(
            source: "A",
            sourceSequenceNumber: 1,
            broadcastID: 1,
            destination: "C",
            destinationSequenceNumber: 0,
            hopCount: 0
        )
        
        aodv.processUpdate(.rreq(rreq), from: "A")
        
        // Should create reverse route to A
        #expect(aodv.nextHop(to: "A") == "A")
        #expect(aodv.costTo("A") == 1)
    }
    
    @Test func routeRequestAtDestination() {
        let localNode = Node(id: "C")
        let aodv = AODV(localNode: localNode)
        
        // A is looking for C (us)
        let rreq = RouteRequest(
            source: "A",
            sourceSequenceNumber: 1,
            broadcastID: 1,
            destination: "C",
            destinationSequenceNumber: 0,
            hopCount: 1
        )
        
        aodv.processUpdate(.rreq(rreq), from: "B")
        
        // Should create reverse route to A through B
        #expect(aodv.nextHop(to: "A") == "B")
        #expect(aodv.costTo("A") == 2)
    }
    
    @Test func routeReplyProcessing() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        // Receive RREP for destination C through B
        let rrep = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(300)
        )
        
        aodv.processUpdate(.rrep(rrep), from: "B")
        
        // Should create forward route to C through B
        #expect(aodv.nextHop(to: "C") == "B")
        #expect(aodv.costTo("C") == 2)
    }
    
    @Test func routeErrorProcessing() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        // Set up routes through B
        aodv.neighborUp("B")
        
        let rrepFromC = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrepFromC), from: "B")
        
        let rrepFromD = RouteReply(
            source: "A",
            destination: "D",
            destinationSequenceNumber: 1,
            hopCount: 2,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrepFromD), from: "B")
        
        #expect(aodv.getRoutes().count == 3)
        
        // Receive RERR from B for C and D
        let rerr = RouteError(unreachableDestinations: ["C", "D"])
        aodv.processUpdate(.rerr(rerr), from: "B")
        
        // Routes to C and D should be removed
        #expect(aodv.nextHop(to: "C") == nil)
        #expect(aodv.nextHop(to: "D") == nil)
        #expect(aodv.nextHop(to: "B") == "B") // Direct neighbor still reachable
    }
    
    @Test func routeLifetime() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        // Create an expired route
        let expiredRrep = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(-1) // Already expired
        )
        
        aodv.processUpdate(.rrep(expiredRrep), from: "B")
        
        // The route is created but getRoutes filters out expired ones
        #expect(aodv.getRoutes().count == 0)
        #expect(aodv.nextHop(to: "C") == nil) // nextHop checks validity
    }
    
    @Test func sequenceNumberHandling() {
        let localNode = Node(id: "A")
        let aodv = AODV(localNode: localNode)
        
        // First route with seq 1
        let rrep1 = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 1,
            hopCount: 3,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrep1), from: "B")
        #expect(aodv.costTo("C") == 4)
        
        // Better route with same seq number
        let rrep2 = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 1,
            hopCount: 1,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrep2), from: "D")
        #expect(aodv.costTo("C") == 2)
        #expect(aodv.nextHop(to: "C") == "D")
        
        // Newer sequence number with worse hop count - should still update
        let rrep3 = RouteReply(
            source: "A",
            destination: "C",
            destinationSequenceNumber: 2,
            hopCount: 4,
            lifetime: Date().addingTimeInterval(300)
        )
        aodv.processUpdate(.rrep(rrep3), from: "E")
        #expect(aodv.costTo("C") == 5)
        #expect(aodv.nextHop(to: "C") == "E")
    }
    
    @Test func duplicateRREQHandling() {
        let localNode = Node(id: "B")
        let aodv = AODV(localNode: localNode)
        
        let rreq = RouteRequest(
            source: "A",
            sourceSequenceNumber: 1,
            broadcastID: 1,
            destination: "C",
            destinationSequenceNumber: 0,
            hopCount: 0
        )
        
        // Process same RREQ twice
        aodv.processUpdate(.rreq(rreq), from: "A")
        let routesAfterFirst = aodv.getRoutes().count
        
        aodv.processUpdate(.rreq(rreq), from: "A")
        let routesAfterSecond = aodv.getRoutes().count
        
        // Should not create duplicate routes
        #expect(routesAfterFirst == routesAfterSecond)
    }
}