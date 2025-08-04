
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Represents a network endpoint, which can be either local or remote.
public struct Endpoint: Sendable {
    public enum EndpointType: Sendable {
        case local
        case remote
    }

    let type: EndpointType
    var hostName: String? = nil
    var port: UInt16? = nil
    var service: String? = nil
    var ipAddress: String? = nil
    var interface: String? = nil
    var multicastGroupIP: String? = nil
    var hopLimit: UInt8? = nil
    var stunServer: (address: String, port: UInt16, credentials: String?)? = nil
    var protocolIdentifier: String? = nil

    public struct StunServerConfig: Sendable {
        let address: String
        let port: UInt16
        let credentials: String?
    }
    var sendableStunServer: StunServerConfig? = nil

    init(type: EndpointType) {
        self.type = type
    }
}

/// Represents a local endpoint for a connection.
public struct LocalEndpoint: Sendable {
    private var _endpoint = Endpoint(type: .local)
    public var port: UInt16? { _endpoint.port }
    public var ipAddress: String? { _endpoint.ipAddress }
    public var interface: String? { _endpoint.interface }

    public init() {}

    public func withHostName(_ hostName: String) -> Self {
        var new = self; new._endpoint.hostName = hostName; return new
    }

    public func withPort(_ port: UInt16) -> Self {
        var new = self; new._endpoint.port = port; return new
    }

    public func withService(_ service: String) -> Self {
        var new = self; new._endpoint.service = service; return new
    }

    public func withIPAddress(_ ipAddress: String) -> Self {
        var new = self; new._endpoint.ipAddress = ipAddress; return new
    }

    public func withInterface(_ interface: String) -> Self {
        var new = self; new._endpoint.interface = interface; return new
    }

    public func withProtocol(_ protocolIdentifier: String) -> Self {
        var new = self; new._endpoint.protocolIdentifier = protocolIdentifier; return new
    }
    
    public func withAnySourceMulticastGroupIP(_ groupAddress: String) -> Self {
        var new = self; new._endpoint.multicastGroupIP = groupAddress; return new
    }

    public func withSingleSourceMulticastGroupIP(_ groupAddress: String, sourceAddress: String) -> Self {
        var new = self; new._endpoint.multicastGroupIP = groupAddress; return new
    }

    public func withStunServer(address: String, port: UInt16, credentials: String? = nil) -> Self {
        var new = self
        new._endpoint.sendableStunServer = Endpoint.StunServerConfig(address: address, port: port, credentials: credentials)
        return new
    }
}

/// Represents a remote endpoint for a connection.
public struct RemoteEndpoint: Sendable {
    private var _endpoint = Endpoint(type: .remote)
    public var port: UInt16? { _endpoint.port }
    public var hostname: String? { _endpoint.hostName }
    public var ipAddress: String? { _endpoint.ipAddress }
    public var interface: String? { _endpoint.interface }

    public init() {}

    public func withHostName(_ hostName: String) -> Self {
        var new = self; new._endpoint.hostName = hostName; return new
    }

    public func withPort(_ port: UInt16) -> Self {
        var new = self; new._endpoint.port = port; return new
    }

    public func withService(_ service: String) -> Self {
        var new = self; new._endpoint.service = service; return new
    }

    public func withIPAddress(_ ipAddress: String) -> Self {
        var new = self; new._endpoint.ipAddress = ipAddress; return new
    }

    public func withInterface(_ interface: String) -> Self {
        var new = self; new._endpoint.interface = interface; return new
    }

    public func withProtocol(_ protocolIdentifier: String) -> Self {
        var new = self; new._endpoint.protocolIdentifier = protocolIdentifier; return new
    }
    
    public func withMulticastGroupIP(_ groupAddress: String) -> Self {
        var new = self; new._endpoint.multicastGroupIP = groupAddress; return new
    }

    public func withHopLimit(_ hopLimit: UInt8) -> Self {
        var new = self; new._endpoint.hopLimit = hopLimit; return new
    }
}
