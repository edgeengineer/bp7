import Testing
import CBOR
@testable import BP7

/// Tests for CyclicRedundancyCheck implementation
@Suite("CyclicRedundancyCheck Tests")
struct CyclicRedundancyCheckTests {
    
    /// A simple struct that conforms to CrcBlock for testing
    struct TestBlock: CrcBlock {
        var data: [UInt8]
        var currentCrc: CrcValue
        
        init(data: [UInt8], crcType: CrcRawType = CyclicRedundancyCheck.NO) {
            self.data = data
            
            switch crcType {
            case CyclicRedundancyCheck.NO:
                self.currentCrc = .crcNo
            case CyclicRedundancyCheck.CRC16:
                self.currentCrc = .crc16Empty
            case CyclicRedundancyCheck.CRC32:
                self.currentCrc = .crc32Empty
            default:
                self.currentCrc = .unknown(crcType)
            }
        }
        
        func crcValue() -> CrcValue {
            return currentCrc
        }
        
        mutating func setCrc(_ crc: CrcValue) {
            currentCrc = crc
        }
        
        func toCbor() -> [UInt8] {
            return data
        }
    }
    
    // MARK: - CrcValue Tests
    
    @Test("CrcValue properties")
    func testCrcValueProperties() {
        // Test CrcNo
        let crcNo = CrcValue.crcNo
        #expect(!crcNo.hasCrc())
        #expect(crcNo.toCode() == CyclicRedundancyCheck.NO)
        #expect(crcNo.bytes() == nil)
        
        // Test Crc16Empty
        let crc16Empty = CrcValue.crc16Empty
        #expect(crc16Empty.hasCrc())
        #expect(crc16Empty.toCode() == CyclicRedundancyCheck.CRC16)
        #expect(crc16Empty.bytes() == CyclicRedundancyCheck.CRC16_EMPTY)
        
        // Test Crc32Empty
        let crc32Empty = CrcValue.crc32Empty
        #expect(crc32Empty.hasCrc())
        #expect(crc32Empty.toCode() == CyclicRedundancyCheck.CRC32)
        #expect(crc32Empty.bytes() == CyclicRedundancyCheck.CRC32_EMPTY)
        
        // Test Crc16
        let crc16Data: [UInt8] = [0x12, 0x34]
        let crc16 = CrcValue.crc16(crc16Data)
        #expect(crc16.hasCrc())
        #expect(crc16.toCode() == CyclicRedundancyCheck.CRC16)
        #expect(crc16.bytes() == crc16Data)
        
        // Test Crc32
        let crc32Data: [UInt8] = [0x12, 0x34, 0x56, 0x78]
        let crc32 = CrcValue.crc32(crc32Data)
        #expect(crc32.hasCrc())
        #expect(crc32.toCode() == CyclicRedundancyCheck.CRC32)
        #expect(crc32.bytes() == crc32Data)
        
        // Test Unknown
        let unknownCode: CrcRawType = 99
        let unknown = CrcValue.unknown(unknownCode)
        #expect(unknown.hasCrc())
        #expect(unknown.toCode() == unknownCode)
        #expect(unknown.bytes() == nil)
    }
    
    @Test("CrcRawType toString")
    func testCrcRawTypeToString() {
        #expect(CyclicRedundancyCheck.NO.toString() == "no")
        #expect(CyclicRedundancyCheck.CRC16.toString() == "16")
        #expect(CyclicRedundancyCheck.CRC32.toString() == "32")
        #expect(CrcRawType(99).toString() == "unknown")
    }
    
    // MARK: - CRC Calculation Tests
    
    @Test("Calculate CRC-16")
    func testCalculateCRC16() {
        // Test with empty data
        let emptyData: [UInt8] = []
        let emptyCrc16 = CyclicRedundancyCheck.calculateCRC16(emptyData)
        #expect(emptyCrc16 == 0xFFFF)
        
        // Test with simple data
        let simpleData: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let simpleCrc16 = CyclicRedundancyCheck.calculateCRC16(simpleData)
        // Expected value calculated using our implementation
        #expect(simpleCrc16 == 0x89C3)
        
        // Test with longer data
        let longerData: [UInt8] = Array("Hello, world!".utf8)
        let longerCrc16 = CyclicRedundancyCheck.calculateCRC16(longerData)
        // Expected value calculated using our implementation
        #expect(longerCrc16 == 0x52D2)
    }
    
    @Test("Calculate CRC-32")
    func testCalculateCRC32() {
        // Test with empty data
        let emptyData: [UInt8] = []
        let emptyCrc32 = CyclicRedundancyCheck.calculateCRC32(emptyData)
        #expect(emptyCrc32 == 0x0)
        
        // Test with simple data
        let simpleData: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let simpleCrc32 = CyclicRedundancyCheck.calculateCRC32(simpleData)
        // Expected value calculated using our implementation
        #expect(simpleCrc32 == 0x29308CF4)
        
        // Test with longer data
        let longerData: [UInt8] = Array("Hello, world!".utf8)
        let longerCrc32 = CyclicRedundancyCheck.calculateCRC32(longerData)
        // Expected value calculated using our implementation
        #expect(longerCrc32 == 0xC8A106E5)
    }
    
    // MARK: - CrcBlock Tests
    
    @Test("CrcBlock basic operations")
    func testCrcBlockBasicOperations() {
        // Create a test block with no CRC
        var block = TestBlock(data: [0x01, 0x02, 0x03, 0x04])
        
        // Check initial state
        #expect(!block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.NO)
        #expect(block.crc() == nil)
        
        // Set CRC type to CRC-16
        block.setCrcType(CyclicRedundancyCheck.CRC16)
        #expect(block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.CRC16)
        #expect(block.crc() == CyclicRedundancyCheck.CRC16_EMPTY)
        
        // Update CRC
        block.updateCrc()
        #expect(block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.CRC16)
        #expect(block.crc() != nil)
        
        // Check CRC
        #expect(block.checkCrc())
        
        // Reset CRC
        block.resetCrc()
        #expect(block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.CRC16)
        #expect(block.crc() == CyclicRedundancyCheck.CRC16_EMPTY)
        
        // Set CRC type to CRC-32
        block.setCrcType(CyclicRedundancyCheck.CRC32)
        #expect(block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.CRC32)
        #expect(block.crc() == CyclicRedundancyCheck.CRC32_EMPTY)
        
        // Update CRC
        block.updateCrc()
        #expect(block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.CRC32)
        #expect(block.crc() != nil)
        
        // Check CRC
        #expect(block.checkCrc())
        
        // Set CRC type to no CRC
        block.setCrcType(CyclicRedundancyCheck.NO)
        #expect(!block.hasCrc())
        #expect(block.crcType() == CyclicRedundancyCheck.NO)
        #expect(block.crc() == nil)
    }
    
    @Test("CrcBlock with invalid CRC")
    func testCrcBlockWithInvalidCRC() {
        // Create a test block with CRC-16
        var block = TestBlock(data: [0x01, 0x02, 0x03, 0x04], crcType: CyclicRedundancyCheck.CRC16)
        
        // Update CRC
        block.updateCrc()
        #expect(block.checkCrc())
        
        // Modify data without updating CRC
        block.data = [0x05, 0x06, 0x07, 0x08]
        #expect(!block.checkCrc())
    }
    
    @Test("Calculate and check CRC")
    func testCalculateAndCheckCRC() {
        // Test with CRC-16
        var block16 = TestBlock(data: [0x01, 0x02, 0x03, 0x04], crcType: CyclicRedundancyCheck.CRC16)
        let crc16 = CyclicRedundancyCheck.calculateCrc(&block16)
        #expect(crc16.toCode() == CyclicRedundancyCheck.CRC16)
        #expect(crc16.bytes() != nil)
        
        block16.setCrc(crc16)
        #expect(block16.checkCrc())
        
        // Test with CRC-32
        var block32 = TestBlock(data: [0x01, 0x02, 0x03, 0x04], crcType: CyclicRedundancyCheck.CRC32)
        let crc32 = CyclicRedundancyCheck.calculateCrc(&block32)
        #expect(crc32.toCode() == CyclicRedundancyCheck.CRC32)
        #expect(crc32.bytes() != nil)
        
        block32.setCrc(crc32)
        #expect(block32.checkCrc())
    }
}
