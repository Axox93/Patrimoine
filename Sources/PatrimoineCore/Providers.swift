import Foundation

public struct InstrumentIdentity: Codable, Equatable, Sendable {
    public let isin: String?
    public let symbol: String
    public let exchangeMIC: String
    public let currency: String
}

public struct MarketQuote: Codable, Equatable, Sendable {
    public let instrument: InstrumentIdentity
    public let price: Decimal
    public let observedAt: Date
    public let source: String
}

/// Provider implementations must validate identity, currency, freshness and licensing.
/// No network provider is enabled in the foundations release.
public protocol MarketDataProvider: Sendable {
    var name: String { get }
    func search(_ query: String) async throws -> [InstrumentIdentity]
    func quote(for instrument: InstrumentIdentity) async throws -> MarketQuote
}

public protocol ReadOnlyBrokerConnector: Sendable {
    var name: String { get }
    func fetchEntries(since: Date?) async throws -> [LedgerEntry]
}
