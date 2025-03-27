import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import BP7

@Suite("DTN Time Tests")
struct DtnTimeTests {
    
    @Test("DTN Time Conversion")
    func testDtnTimeConversion() {
        // Test conversion from DTN time to Unix timestamp
        let dtnTime: DtnTime = 1000 // 1 second after year 2000
        let unixTimestamp = dtnTime.toUnixTimestamp()
        
        // Expected: 1 second after year 2000 in Unix time
        #expect(unixTimestamp == DtnTimeConstants.SECONDS1970_TO2K + 1)
        
        // Test RFC3339 string format
        let timeString = dtnTime.toRFC3339String()
        #expect(!timeString.isEmpty)
        
        // Verify the string contains the correct year (2000)
        #expect(timeString.contains("2000"))
    }
    
    @Test("Current DTN Time")
    func testCurrentDtnTime() {
        // Get current DTN time
        let now = DtnTime.now()
        
        // Convert to Unix timestamp
        let unixNow = now.toUnixTimestamp()
        
        // Current Unix timestamp should be greater than the 2000 epoch
        #expect(unixNow > DtnTimeConstants.SECONDS1970_TO2K)
        
        // Current DTN time should be positive (we're after year 2000)
        #expect(now > 0)
        
        // Current Unix time should be reasonably close to system time
        let systemUnixTime = UInt64(Date().timeIntervalSince1970)
        let difference = abs(Int64(unixNow) - Int64(systemUnixTime))
        
        // Should be within 10 seconds (allowing for test execution time)
        #expect(difference < 10)
    }
    
    @Test("Creation Timestamp")
    func testCreationTimestamp() {
        // Create timestamp with specific values
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 42)
        
        #expect(timestamp.getDtnTime() == 1000)
        #expect(timestamp.getSequenceNumber() == 42)
        
        // Test description format
        let description = timestamp.description
        #expect(description.contains("2000"))
        #expect(description.contains("42"))
    }
    
    @Test("Creation Timestamp Auto-Sequence")
    func testCreationTimestampAutoSequence() {
        // Create two timestamps in quick succession
        let timestamp1 = CreationTimestamp.now()
        let timestamp2 = CreationTimestamp.now()
        
        // They should have the same time but different sequence numbers
        #expect(timestamp1.getDtnTime() == timestamp2.getDtnTime())
        #expect(timestamp1.getSequenceNumber() < timestamp2.getSequenceNumber())
        
        // Wait a bit to ensure we get a different timestamp
        Thread.sleep(forTimeInterval: 0.01)
        let timestamp3 = CreationTimestamp.now()
        
        // The third timestamp should have a different time and sequence number 0
        if timestamp3.getDtnTime() != timestamp1.getDtnTime() {
            #expect(timestamp3.getSequenceNumber() == 0)
        }
    }
    
    @Test("Creation Timestamp Codable")
    func testCreationTimestampCodable() {
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 42)
        
        // Encode to JSON
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(timestamp)
            
            // Decode from JSON
            let decoder = JSONDecoder()
            let decodedTimestamp = try decoder.decode(CreationTimestamp.self, from: data)
            
            // Verify values match
            #expect(decodedTimestamp.getDtnTime() == timestamp.getDtnTime())
            #expect(decodedTimestamp.getSequenceNumber() == timestamp.getSequenceNumber())
        } catch {
            #expect(Bool(false), "Encoding/decoding should not throw: \(error)")
        }
    }
}
