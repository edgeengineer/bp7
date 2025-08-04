#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct Node<ID: Hashable>: Identifiable {
    public let id: ID
    public init(id: ID) {
        self.id = id
    }
}