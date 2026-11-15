import Foundation

public enum MovementKind: String, Codable, CaseIterable, Sendable {
    case deposit, withdrawal, buy, sell, dividend, interest, fee, split

    public var label: String {
        switch self {
        case .deposit: return "Versement"
        case .withdrawal: return "Retrait"
        case .buy: return "Achat"
        case .sell: return "Vente"
        case .dividend: return "Dividende"
        case .interest: return "Intérêt"
        case .fee: return "Frais"
        case .split: return "Fractionnement"
        }
    }
    public var needsInstrument: Bool { [.buy, .sell, .dividend, .split].contains(self) }
}

public struct LedgerEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let sequence: Int
    public let kind: MovementKind
    public let instrumentID: UUID?
    public let quantity: Decimal
    /// Positive gross cash amount in the account currency (not unit price).
    public let amount: Decimal
    /// Positive cash costs, including withholding where entered by the user.
    public let fees: Decimal
    public let currency: String

    public init(id: UUID = UUID(), date: Date, sequence: Int, kind: MovementKind,
                instrumentID: UUID? = nil, quantity: Decimal = 0,
                amount: Decimal, fees: Decimal = 0, currency: String) {
        self.id = id; self.date = date; self.sequence = sequence; self.kind = kind
        self.instrumentID = instrumentID; self.quantity = quantity
        self.amount = amount; self.fees = fees; self.currency = currency
    }
}

public struct Holding: Equatable, Sendable {
    public var quantity: Decimal = 0
    public var cost: Decimal = 0
    public var averageCost: Decimal? { quantity > 0 ? cost / quantity : nil }
    public init() {}
}

public struct LedgerResult: Equatable, Sendable {
    public var cash: Decimal = 0
    public var netContributions: Decimal = 0
    public var realizedGain: Decimal = 0
    public var netIncome: Decimal = 0
    public var dividends: Decimal = 0
    public var fees: Decimal = 0
    public var holdings: [UUID: Holding] = [:]

    /// No cost-price fallback: all open holdings need an explicit quote.
    public func valuation(prices: [UUID: Decimal]) -> Decimal? {
        var result = cash
        for (id, holding) in holdings where holding.quantity > 0 {
            guard let price = prices[id], price >= 0, !price.isNaN else { return nil }
            result += holding.quantity * price
        }
        return result
    }
    public func unrealizedGain(prices: [UUID: Decimal]) -> Decimal? {
        guard let value = valuation(prices: prices) else { return nil }
        return value - cash - holdings.values.reduce(0) { $0 + $1.cost }
    }
}

public enum LedgerError: Error, LocalizedError, Equatable {
    case duplicate, invalidAmount, invalidInstrument, insufficientCash, oversell, currencyMismatch, ambiguousOrder
    public var errorDescription: String? {
        switch self {
        case .duplicate: return "Une opération est déjà présente."
        case .invalidAmount: return "Montant, quantité ou frais invalides."
        case .invalidInstrument: return "Un instrument est requis pour cette opération."
        case .insufficientCash: return "Liquidités insuffisantes. Enregistrez le versement initial."
        case .oversell: return "La vente dépasse la quantité détenue."
        case .currencyMismatch: return "La devise doit correspondre à celle du compte. Le change sera ajouté ultérieurement."
        case .ambiguousOrder: return "Deux opérations ont le même ordre comptable."
        }
    }
}

public enum LedgerEngine {
    /// Weighted average cost, with purchase costs capitalized and sale costs deducted.
    /// Replay never mutates historical entries. Negative cash and short sales are rejected.
    public static func replay(_ entries: [LedgerEntry], currency: String) throws -> LedgerResult {
        var result = LedgerResult()
        var identifiers = Set<UUID>()
        var sequences = Set<Int>()
        for entry in entries.sorted(by: { ($0.date, $0.sequence) < ($1.date, $1.sequence) }) {
            guard identifiers.insert(entry.id).inserted else { throw LedgerError.duplicate }
            guard sequences.insert(entry.sequence).inserted else { throw LedgerError.ambiguousOrder }
            guard entry.currency == currency else { throw LedgerError.currencyMismatch }
            guard !entry.amount.isNaN, !entry.fees.isNaN, !entry.quantity.isNaN,
                  entry.amount >= 0, entry.fees >= 0, entry.quantity >= 0 else { throw LedgerError.invalidAmount }
            if entry.kind.needsInstrument && entry.instrumentID == nil { throw LedgerError.invalidInstrument }
            if [.buy, .sell, .split].contains(entry.kind) {
                guard entry.quantity > 0 else { throw LedgerError.invalidAmount }
            } else if entry.quantity != 0 { throw LedgerError.invalidAmount }
            if entry.kind == .split {
                guard entry.amount == 0, entry.fees == 0 else { throw LedgerError.invalidAmount }
            } else {
                guard entry.amount > 0 else { throw LedgerError.invalidAmount }
            }
            switch entry.kind {
            case .deposit:
                result.cash += entry.amount - entry.fees
                result.netContributions += entry.amount
            case .withdrawal:
                result.cash -= entry.amount + entry.fees
                result.netContributions -= entry.amount
            case .buy:
                let id = entry.instrumentID!
                var holding = result.holdings[id, default: Holding()]
                holding.quantity += entry.quantity
                holding.cost += entry.amount + entry.fees
                result.holdings[id] = holding
                result.cash -= entry.amount + entry.fees
            case .sell:
                let id = entry.instrumentID!
                var holding = result.holdings[id, default: Holding()]
                guard entry.quantity <= holding.quantity else { throw LedgerError.oversell }
                let removedCost = entry.quantity == holding.quantity
                    ? holding.cost : holding.cost * entry.quantity / holding.quantity
                holding.quantity -= entry.quantity
                holding.cost -= removedCost
                result.holdings[id] = holding
                result.realizedGain += entry.amount - entry.fees - removedCost
                result.cash += entry.amount - entry.fees
            case .dividend, .interest:
                guard entry.fees <= entry.amount else { throw LedgerError.invalidAmount }
                let net = entry.amount - entry.fees
                result.cash += net; result.netIncome += net
                if entry.kind == .dividend { result.dividends += net }
            case .fee:
                guard entry.fees == 0 else { throw LedgerError.invalidAmount }
                result.cash -= entry.amount
            case .split:
                let id = entry.instrumentID!
                var holding = result.holdings[id, default: Holding()]
                guard holding.quantity > 0 else { throw LedgerError.invalidInstrument }
                holding.quantity *= entry.quantity
                result.holdings[id] = holding
            }
            result.fees += entry.fees + (entry.kind == .fee ? entry.amount : 0)
            guard result.cash >= 0 else { throw LedgerError.insufficientCash }
        }
        return result
    }
}
