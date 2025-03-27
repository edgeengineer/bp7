import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import BP7

@Suite("DTN Time Tests")
struct DisruptionTolerantNetworkingTimeTests {
    @Test("DTN Time Conversion")
    func testDtnTimeConversion() {
        // Test conversion from DTN time to Unix timestamp
        let dtnTime: DisruptionTolerantNetworkingTime = 1000 // 1 second after year 2000
        let unixTimestamp = dtnTime.toUnixTimestamp()
        
        // Expected: 1 second after year 2000 in Unix time
        #expect(unixTimestamp == DisruptionTolerantNetworkingTimeConstants.SECONDS1970_TO2K + 1)
        
        // Test RFC3339 string format
        let rfc3339String = dtnTime.toRFC3339String()
        #expect(rfc3339String.contains("2000-01-01T00:00:01"))
    }
    
    @Test("Creation Timestamp")
    func testCreationTimestamp() {
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 42)
        #expect(timestamp.getDtnTime() == 1000)
        #expect(timestamp.getSequenceNumber() == 42)
    }
    
    @Test("Current DTN Time")
    func testCurrentDtnTime() {
        // Get current DTN time
        let now = DisruptionTolerantNetworkingTime.now()
        
        // Convert to Unix timestamp
        let unixNow = now.toUnixTimestamp()
        
        // Current Unix timestamp should be greater than the 2000 epoch
        #expect(unixNow > DisruptionTolerantNetworkingTimeConstants.SECONDS1970_TO2K)
        
        // Current DTN time should be positive (we're after year 2000)
        #expect(now > 0)
    }
    
    @Test("Creation Timestamp Auto-Sequence")
    func testCreationTimestampAutoSequence() {
        // Create timestamps at the "same" time
        let timestamp1 = CreationTimestamp.now()
        let timestamp2 = CreationTimestamp.now()
        
        // Timestamps should have the same time or very close
        let timeDiff = abs(Int64(timestamp1.getDtnTime()) - Int64(timestamp2.getDtnTime()))
        #expect(timeDiff < 1000) // Within 1 second
        
        // Sequence numbers should be different
        if timestamp1.getDtnTime() == timestamp2.getDtnTime() {
            #expect(timestamp1.getSequenceNumber() != timestamp2.getSequenceNumber())
        }
    }
    
    @Test("Creation Timestamp Codable")
    func testCreationTimestampCodable() {
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 42)
        
        do {
            // Encode to JSON
            let encoder = JSONEncoder()
            let data = try encoder.encode(timestamp)
            
            // Decode from JSON
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CreationTimestamp.self, from: data)
            
            // Verify decoded values
            #expect(decoded.getDtnTime() == timestamp.getDtnTime())
            #expect(decoded.getSequenceNumber() == timestamp.getSequenceNumber())
        } catch {
            #expect(Bool(false), "Encoding/decoding failed: \(error)")
        }
    }
    
    @Test("DTN Time to Date Conversion")
    func testDtnTimeToDateConversion() {
        // Test conversion from DTN time to Date
        let dtnTime: DisruptionTolerantNetworkingTime = 1000 // 1 second after year 2000
        let date = dtnTime.toDate()
        
        // Expected: 1 second after year 2000 in Date format
        let expectedTimestamp = TimeInterval(DisruptionTolerantNetworkingTimeConstants.SECONDS1970_TO2K + 1)
        let expectedDate = Date(timeIntervalSince1970: expectedTimestamp)
        
        #expect(date.timeIntervalSince1970 == expectedDate.timeIntervalSince1970)
    }
    
    @Test("Date to DTN Time Conversion")
    func testDateToDtnTimeConversion() {
        // Create a Date for 1 second after year 2000
        let timestamp = TimeInterval(DisruptionTolerantNetworkingTimeConstants.SECONDS1970_TO2K + 1)
        let date = Date(timeIntervalSince1970: timestamp)
        
        // Convert to DTN time
        let dtnTime = DisruptionTolerantNetworkingTime.from(date: date)
        
        // Expected: 1000 milliseconds (1 second after year 2000 in DTN time)
        #expect(dtnTime == 1000)
    }
    
    @Test("Creation Timestamp Date Conversion")
    func testCreationTimestampDateConversion() {
        // Create a timestamp with a specific time
        let dtnTime: DisruptionTolerantNetworkingTime = 1000
        let timestamp = CreationTimestamp(time: dtnTime, sequenceNumber: 42)
        
        // Convert to Date
        let date = timestamp.toDate()
        
        // Expected: 1 second after year 2000
        let expectedTimestamp = TimeInterval(DisruptionTolerantNetworkingTimeConstants.SECONDS1970_TO2K + 1)
        #expect(date.timeIntervalSince1970 == expectedTimestamp)
        
        // Create a timestamp from a Date
        let newTimestamp = CreationTimestamp.from(date: date, sequenceNumber: 84)
        
        // Verify the conversion
        #expect(newTimestamp.getDtnTime() == dtnTime)
        #expect(newTimestamp.getSequenceNumber() == 84)
    }
}
