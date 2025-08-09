import Testing
import CBOR
@testable import BP7

/// Tests for EndpointID implementation
@Suite("EndpointID Tests")
struct EndpointIDTests {
    
    // MARK: - String Conversion Tests
    
    @Test("Create from DTN string")
    func testCreateFromDTNString() throws {
        // Valid DTN endpoints
        let eid1 = try EndpointID.from("dtn://node1/incoming")
        #expect(eid1.description == "dtn://node1/incoming")
        #expect(eid1.getScheme() == EndpointScheme.DTN)
        #expect(!eid1.isNone())
        
        // DTN with trailing slash
        let eid2 = try EndpointID.from("dtn://node1/incoming/")
        #expect(eid2.description == "dtn://node1/incoming/")
        
        // Node ID only
        let eid3 = try EndpointID.from("dtn://node1/")
        #expect(eid3.description == "dtn://node1/")
        
        // Path with tilde
        let eid4 = try EndpointID.from("dtn://node_group/~mail")
        #expect(eid4.description == "dtn://node_group/~mail")
        
        // Complex path
        let eid5 = try EndpointID.from("dtn://home_net/~tele/sensors/temperature")
        #expect(eid5.description == "dtn://home_net/~tele/sensors/temperature")
        
        // None endpoint
        let eid6 = try EndpointID.from("dtn:none")
        #expect(eid6.description == "dtn:none")
        #expect(eid6 == EndpointID.none())
        #expect(eid6.isNone())
    }
    
    @Test("Create from IPN string")
    func testCreateFromIPNString() throws {
        // Valid IPN endpoint
        let eid1 = try EndpointID.from("ipn:23.42")
        #expect(eid1.description == "ipn:23.42")
        #expect(eid1.getScheme() == EndpointScheme.IPN)
        
        // Test with larger numbers
        let eid2 = try EndpointID.from("ipn:123456789.987654321")
        #expect(eid2.description == "ipn:123456789.987654321")
        
        // Test with zero service number
        let eid3 = try EndpointID.from("ipn:42.0")
        #expect(eid3.description == "ipn:42.0")
    }
    
    @Test("Error handling for invalid strings")
    func testErrorHandlingForInvalidStrings() {
        // Missing scheme
        #expect(throws: BP7Error.endpointID(.schemeMissing)) {
            _ = try EndpointID.from("invalid")
        }
        
        // Invalid scheme
        #expect(throws: BP7Error.endpointID(.invalidSSP)) {
            _ = try EndpointID.from("invalid:ssp")
        }
        
        // Invalid IPN format
        #expect(throws: BP7Error.endpointID(.invalidSSP)) {
            _ = try EndpointID.from("ipn:42")
        }
        
        // Invalid IPN node number
        #expect(throws: BP7Error.endpointID(.couldNotParseNumber("invalid"))) {
            _ = try EndpointID.from("ipn:invalid.42")
        }
        
        // Invalid IPN service number
        #expect(throws: BP7Error.endpointID(.couldNotParseNumber("invalid"))) {
            _ = try EndpointID.from("ipn:42.invalid")
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Scheme validation")
    func testSchemeValidation() throws {
        // DTN endpoint
        let dtn = try EndpointID.from("dtn://node1/incoming")
        try dtn.validateDTN()
        #expect(throws: BP7Error.endpointID(.schemeMismatch(found: EndpointScheme.DTN, expected: EndpointScheme.IPN))) {
            try dtn.validateIPN()
        }
        
        // IPN endpoint
        let ipn = try EndpointID.from("ipn:23.42")
        try ipn.validateIPN()
        #expect(throws: BP7Error.endpointID(.schemeMismatch(found: EndpointScheme.IPN, expected: EndpointScheme.DTN))) {
            try ipn.validateDTN()
        }
    }
    
    @Test("None endpoint")
    func testNoneEndpoint() {
        let none = EndpointID.none()
        #expect(none.description == "dtn:none")
        #expect(none.isNone())
        #expect(none.getScheme() == EndpointScheme.DTN)
    }
    
    // MARK: - CBOR Encoding/Decoding Tests
    
    @Test("CBOR encoding and decoding")
    func testCBORCoding() throws {
        let endpoints = [
            try EndpointID.from("dtn:none"),
            try EndpointID.from("dtn://node1/incoming"),
            try EndpointID.from("ipn:23.42")
        ]
        
        for endpoint in endpoints {
            // Encode to CBOR
            let cbor = endpoint.encode()
            
            // Decode from CBOR
            let decoded = try EndpointID(from: cbor)
            
            // Verify round-trip
            #expect(decoded == endpoint)
            #expect(decoded.description == endpoint.description)
        }
    }
    
    @Test("CBOR format validation")
    func testCBORFormatValidation() throws {
        // Invalid array length
        let invalidArray1 = CBOR.array([.unsignedInt(1)])
        #expect(throws: BP7Error.invalidBlock) {
            _ = try EndpointID(from: invalidArray1)
        }
        
        // Invalid scheme type
        let invalidArray2 = CBOR.array([.textString("1"), .textString("//node1")])
        #expect(throws: BP7Error.invalidBlock) {
            _ = try EndpointID(from: invalidArray2)
        }
        
        // Invalid IPN format
        let invalidIPN = CBOR.array([.unsignedInt(2), .textString("23.42")])
        #expect(throws: BP7Error.invalidBlock) {
            _ = try EndpointID(from: invalidIPN)
        }
    }
}
