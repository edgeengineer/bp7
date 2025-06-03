import CBOR

/// Represents a complete Bundle Protocol 7 bundle
public struct Bundle: Equatable, Sendable {
    /// Primary block of the bundle
    public let primary: PrimaryBlock
    
    /// Canonical blocks in the bundle
    public var canonicals: [CanonicalBlock]
    
    /// Create a new bundle
    public init(primary: PrimaryBlock, canonicals: [CanonicalBlock] = []) {
        self.primary = primary
        self.canonicals = canonicals
    }
    
    /// Get the payload block of the bundle
    public func payloadBlock() -> CanonicalBlock? {
        return canonicals.first { $0.blockType == BlockType.payload.rawValue }
    }
    
    /// Get the payload data of the bundle
    public func payload() -> [UInt8]? {
        if let block = payloadBlock() {
            if case .data(let data) = block.getData() {
                return data
            }
        }
        return nil
    }
    
    /// Set the CRC for all blocks in the bundle
    public mutating func setCrc(_ crcType: CrcValue) {
        // Create a mutable copy of the primary block
        var primaryCopy = primary
        
        // Set the CRC for the primary block
        if primaryCopy.crcValue() != crcType {
            primaryCopy.setCrc(crcType)
            
            // Calculate and set the CRC value
            if crcType != .crcNo {
                var mutableBlock = primaryCopy
                let calculatedCrc = BP7CRC.calculateCrc(&mutableBlock)
                primaryCopy.setCrc(calculatedCrc)
            }
        }
        
        // Update the primary block
        self = Bundle(primary: primaryCopy, canonicals: canonicals)
        
        // Update the CRC for all canonical blocks
        for i in 0..<canonicals.count {
            var block = canonicals[i]
            
            if block.crcValue() != crcType {
                block.setCrc(crcType)
                
                // Calculate and set the CRC value
                if crcType != .crcNo {
                    let calculatedCrc = BP7CRC.calculateCrc(&block)
                    block.setCrc(calculatedCrc)
                }
                
                canonicals[i] = block
            }
        }
    }
    
    /// Convert the bundle to CBOR format
    public func encode() -> [UInt8] {
        var items: [CBOR] = []
        
        // Add primary block
        items.append(.byteString(ArraySlice(primary.toCbor())))
        
        // Add canonical blocks
        for block in canonicals {
            items.append(.byteString(ArraySlice(block.toCbor())))
        }
        
        // Encode as CBOR array
        let cborArray = CBOR.array(items)
        return cborArray.encode()
    }
    
    /// Decode a bundle from CBOR format
    public static func decode(from data: [UInt8]) throws(BP7Error) -> Bundle {
        guard let cbor = try? CBOR.decode(data),
              case .array = cbor else {
            throw BP7Error.invalidBundle
        }
        
        let items: [CBOR]
        do {
            guard let decodedItems = try cbor.arrayValue() else {
                throw BP7Error.invalidBundle
            }
            items = decodedItems
        } catch {
            throw BP7Error.invalidBundle
        }
        
        guard !items.isEmpty else {
            throw BP7Error.invalidBundle
        }
        
        // Decode primary block
        guard let primaryData = items[0].byteStringValue() else {
            throw BP7Error.invalidBundle
        }
        
        // Create primary block from CBOR data
        let primary: PrimaryBlock
        do {
            // Try to decode the primary block from CBOR
            let primaryCbor = try CBOR.decode(primaryData)
            guard case .array = primaryCbor else {
                throw BP7Error.invalidBundle
            }
            
            // Create a primary block from the CBOR data
            primary = try PrimaryBlock(from: primaryData)
        } catch {
            throw BP7Error.invalidBundle
        }
        
        // Decode canonical blocks
        var canonicals: [CanonicalBlock] = []
        
        for i in 1..<items.count {
            guard let blockData = items[i].byteStringValue() else {
                continue
            }
            
            if let block = try? CanonicalBlock.fromCbor(blockData) {
                canonicals.append(block)
            }
        }
        
        return Bundle(primary: primary, canonicals: canonicals)
    }
    
    /// Validate the bundle
    public func validate() throws(BP7Error) {
        // Validate primary block
        try primary.validate()
        
        // Check for duplicate block numbers
        var blockNumbers = Set<UInt64>()
        
        for block in canonicals {
            if blockNumbers.contains(block.blockNumber) {
                throw BP7Error.duplicateBlockNumber
            }
            blockNumbers.insert(block.blockNumber)
        }
        
        // Check for payload block
        if !canonicals.contains(where: { $0.blockType == BlockType.payload.rawValue }) {
            throw BP7Error.missingPayloadBlock
        }
    }
    
    /// Implement Equatable for Bundle
    public static func == (lhs: Bundle, rhs: Bundle) -> Bool {
        // Compare primary blocks
        guard lhs.primary.toCbor() == rhs.primary.toCbor() else {
            return false
        }
        
        // Compare canonical blocks
        guard lhs.canonicals.count == rhs.canonicals.count else {
            return false
        }
        
        // Compare each canonical block by its CBOR representation
        for i in 0..<lhs.canonicals.count {
            guard lhs.canonicals[i].toCbor() == rhs.canonicals[i].toCbor() else {
                return false
            }
        }
        
        return true
    }
}

/// Builder for creating bundles
public struct BundleBuilder {
    private let primary: PrimaryBlock
    private var canonicals: [CanonicalBlock] = []
    
    /// Create a new bundle builder with a required primary block
    public init(primary: PrimaryBlock) {
        self.primary = primary
    }
    
    /// Sets and overwrites the canonical blocks
    public func canonicals(_ canonicals: [CanonicalBlock]) -> BundleBuilder {
        var builder = self
        builder.canonicals = canonicals
        return builder
    }
    
    /// Add a canonical block
    public func addCanonical(_ canonical: CanonicalBlock) -> BundleBuilder {
        var builder = self
        builder.canonicals.append(canonical)
        return builder
    }
    
    /// Build the bundle
    public func build() -> Bundle {
        return Bundle(primary: primary, canonicals: canonicals)
    }
}
