import CBOR

/// Namespace for endpoint-related constants and functionality
public enum EndpointScheme {
    /// Scheme identifier for DTN URIs.
    public static let DTN: UInt8 = 1

    /// Scheme identifier for IPN URIs.
    public static let IPN: UInt8 = 2
}

/// The "dtn:none" endpoint ID.
@available(*, deprecated, message: "Use EndpointID.none() instead")
public let DTN_NONE: EndpointID = EndpointID.dtnNone(EndpointScheme.DTN, 0)

/// Represents a DTN address.
public struct DTNAddress: Hashable, Equatable, Sendable, CustomStringConvertible {
    /// The node name.
    public let name: String
    
    /// Initializes a new DTN address.
    /// - Parameter name: The node name.
    public init(_ name: String) {
        self.name = name
    }
    
    /// A string representation of the DTN address.
    public var description: String {
        return name
    }
}

/// Represents an IPN address.
public struct IPNAddress: Hashable, Equatable, Sendable, CustomStringConvertible {
    /// The node number.
    public let nodeNumber: UInt64
    
    /// The service number.
    public let serviceNumber: UInt64
    
    /// Initializes a new IPN address.
    /// - Parameters:
    ///   - node: The node number.
    ///   - service: The service number.
    public init(node: UInt64, service: UInt64) {
        self.nodeNumber = node
        self.serviceNumber = service
    }
    
    /// A string representation of the IPN address.
    public var description: String {
        return "\(nodeNumber).\(serviceNumber)"
    }
}

/// Represents an endpoint in various addressing schemes.
public enum EndpointID: Hashable, Equatable, Sendable, CustomStringConvertible {
    /// A DTN endpoint.
    case dtn(UInt8, DTNAddress)
    
    /// The "dtn:none" endpoint.
    case dtnNone(UInt8, UInt8)
    
    /// An IPN endpoint.
    case ipn(UInt8, IPNAddress)
    
    /// Creates a new "dtn:none" endpoint.
    /// - Returns: A "dtn:none" endpoint.
    public static func none() -> EndpointID {
        return .dtnNone(EndpointScheme.DTN, 0)
    }
    
    /// Creates a new endpoint ID from a string.
    /// - Parameter uri: The URI string.
    /// - Returns: A new endpoint ID.
    /// - Throws: An error if the URI is invalid.
    public static func from(_ uri: String) throws -> EndpointID {
        // Split the URI into scheme and SSP
        let parts = uri.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            throw BP7Error.endpointID(.schemeMissing)
        }
        
        let scheme = String(parts[0])
        let ssp = String(parts[1])
        
        switch scheme.lowercased() {
        case "dtn":
            return try fromDTN(ssp)
        case "ipn":
            return try fromIPN(ssp)
        default:
            throw BP7Error.endpointID(.invalidSSP)
        }
    }
    
    /// Creates a new DTN endpoint ID from an SSP.
    /// - Parameter ssp: The SSP string.
    /// - Returns: A new DTN endpoint ID.
    /// - Throws: An error if the SSP is invalid.
    private static func fromDTN(_ ssp: String) throws -> EndpointID {
        if ssp == "none" {
            return .none()
        }
        
        // Handle DTN URIs
        if ssp.hasPrefix("//") {
            // Remove the leading "//"
            let rest = String(ssp.dropFirst(2))
            
            // Split the rest into node and path
            let parts = rest.split(separator: "/", maxSplits: 1)
            if parts.count == 1 {
                // Just a node name
                return .dtn(EndpointScheme.DTN, DTNAddress(String(parts[0])))
            } else {
                // Node name and path
                let node = String(parts[0])
                let path = String(parts[1])
                return .dtn(EndpointScheme.DTN, DTNAddress("\(node)/\(path)"))
            }
        } else {
            // Just a path
            return .dtn(EndpointScheme.DTN, DTNAddress(ssp))
        }
    }
    
    /// Creates a new IPN endpoint ID from an SSP.
    /// - Parameter ssp: The SSP string.
    /// - Returns: A new IPN endpoint ID.
    /// - Throws: An error if the SSP is invalid.
    private static func fromIPN(_ ssp: String) throws -> EndpointID {
        // Split the SSP into node and service numbers
        let parts = ssp.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else {
            throw BP7Error.endpointID(.invalidSSP)
        }
        
        // Parse the node number
        guard let nodeNumber = UInt64(parts[0]) else {
            throw BP7Error.endpointID(.couldNotParseNumber(String(parts[0])))
        }
        
        // Parse the service number
        guard let serviceNumber = UInt64(parts[1]) else {
            throw BP7Error.endpointID(.couldNotParseNumber(String(parts[1])))
        }
        
        return .ipn(EndpointScheme.IPN, IPNAddress(node: nodeNumber, service: serviceNumber))
    }
    
    /// Gets the scheme identifier.
    /// - Returns: The scheme identifier.
    public func getScheme() -> UInt8 {
        switch self {
        case .dtn(let scheme, _):
            return scheme
        case .dtnNone(let scheme, _):
            return scheme
        case .ipn(let scheme, _):
            return scheme
        }
    }
    
    /// Gets the scheme-specific part (SSP).
    /// - Returns: The SSP.
    public func getSSP() -> String {
        switch self {
        case .dtn(_, let name):
            return name.description
        case .dtnNone(_, _):
            return "none"
        case .ipn(_, let addr):
            return addr.description
        }
    }
    
    /// Checks if this endpoint ID is the "dtn:none" endpoint.
    /// - Returns: `true` if this is the "dtn:none" endpoint, `false` otherwise.
    public func isNone() -> Bool {
        switch self {
        case .dtnNone(_, _):
            return true
        case .dtn(_, let name):
            return name.description.isEmpty
        default:
            return false
        }
    }
    
    /// Validates that this endpoint ID has the expected scheme.
    /// - Parameter expectedScheme: The expected scheme.
    /// - Throws: An error if the scheme does not match.
    public func validateScheme(_ expectedScheme: UInt8) throws {
        let scheme = getScheme()
        guard scheme == expectedScheme else {
            throw BP7Error.endpointID(.schemeMismatch(found: scheme, expected: expectedScheme))
        }
    }
    
    /// Validates that this endpoint ID is a DTN endpoint.
    /// - Throws: An error if this is not a DTN endpoint.
    public func validateDTN() throws {
        try validateScheme(EndpointScheme.DTN)
    }
    
    /// Validates that this endpoint ID is an IPN endpoint.
    /// - Throws: An error if this is not an IPN endpoint.
    public func validateIPN() throws {
        try validateScheme(EndpointScheme.IPN)
    }
    
    /// A string representation of the endpoint ID.
    public var description: String {
        switch self {
        case .dtn(_, let name):
            if name.description.hasPrefix("//") || name.description.isEmpty {
                return "dtn:\(name.description)"
            } else if name.description.contains("/") {
                return "dtn://\(name.description)"
            } else {
                // Ensure node-only DTN endpoints end with a trailing slash
                return "dtn://\(name.description)/"
            }
        case .dtnNone(_, _):
            return "dtn:none"
        case .ipn(_, let addr):
            return "ipn:\(addr.description)"
        }
    }
}

// MARK: - CBOR Coding
extension EndpointID {
    public func encode() throws -> CBOR {
        switch self {
        case .dtn(let eidType, let name):
            return .array([.unsignedInt(UInt64(eidType)), .textString(name.description)])
            
        case .dtnNone(let eidType, let name):
            return .array([.unsignedInt(UInt64(eidType)), .unsignedInt(UInt64(name))])
            
        case .ipn(let eidType, let ipnAddr):
            // For IPN addresses, encode as [scheme, [node, service]]
            let ipnArray: CBOR = .array([
                .unsignedInt(ipnAddr.nodeNumber),
                .unsignedInt(ipnAddr.serviceNumber)
            ])
            return .array([.unsignedInt(UInt64(eidType)), ipnArray])
        }
    }
    
    public init(from cbor: CBOR) throws {
        guard case let .array(items) = cbor, items.count == 2 else {
            throw BP7Error.invalidBlock
        }
        
        guard case let .unsignedInt(eidTypeInt) = items[0], eidTypeInt <= UInt64(UInt8.max) else {
            throw BP7Error.invalidBlock
        }
        
        let eidType = UInt8(eidTypeInt)
        
        if eidType == EndpointScheme.DTN {
            // Handle DTN scheme
            switch items[1] {
            case .textString(let name):
                if name.isEmpty {
                    self = EndpointID.none()
                } else {
                    self = EndpointID.dtn(eidType, DTNAddress(name))
                }
                
            case .unsignedInt(let value):
                if value == 0 {
                    self = EndpointID.none()
                } else {
                    throw BP7Error.invalidBlock
                }
                
            default:
                throw BP7Error.invalidBlock
            }
        } else if eidType == EndpointScheme.IPN {
            // Handle IPN scheme
            guard case let .array(ipnItems) = items[1], ipnItems.count == 2,
                  case let .unsignedInt(nodeNumber) = ipnItems[0],
                  case let .unsignedInt(serviceNumber) = ipnItems[1] else {
                throw BP7Error.invalidBlock
            }
            
            let ipnAddr = IPNAddress(node: nodeNumber, service: serviceNumber)
            self = EndpointID.ipn(eidType, ipnAddr)
        } else {
            throw BP7Error.invalidBlock
        }
    }
}

// MARK: - CustomStringConvertible
extension EndpointID {
    /// A string representation of the endpoint ID.
    public var debugDescription: String {
        return description
    }
}
