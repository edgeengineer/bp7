
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A protocol that defines how application-layer messages are framed and parsed over a transport connection.
public protocol Framer: Sendable {
    /// Called when the framer is started on a connection.
    func start(connection: Connection) async

    /// Handles new inbound data from the connection.
    /// The framer should parse this data and deliver messages via `connection.deliverMessage()`.
    func handleInput(data: Data) async

    /// Creates a framed message to be sent over the connection.
    /// - Parameters:
    ///   - message: The application message to be framed.
    ///   - context: The context associated with the message.
    /// - Returns: The framed data to be sent.
    func frame(message: Data, context: MessageContext) -> Data
}
