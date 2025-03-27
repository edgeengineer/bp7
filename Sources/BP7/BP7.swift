#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// Bundle Protocol Version 7 implementation in Swift.
/// Based on RFC 9171 (https://datatracker.ietf.org/doc/html/rfc9171).
public struct BP7 {
    /// The version of the Bundle Protocol.
    public static let version: UInt = 7
    
    /// Returns the version of the Bundle Protocol.
    /// - Returns: The version of the Bundle Protocol.
    public static func getVersion() -> UInt {
        return version
    }
}
