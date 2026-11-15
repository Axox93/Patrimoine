import Foundation
import SwiftData
import PatrimoineCore

enum AccountKind: String, CaseIterable, Codable, Identifiable {
    case pea = "PEA", peaPME = "PEA-PME", cto = "Compte-titres", assurance = "Assurance-vie"
    case per = "PER", pee = "PEE", perco = "PERCO", livretA = "Livret A", ldds = "LDDS", lep = "LEP"
    case bank = "Compte bancaire", term = "Compte à terme", bonds = "Obligations"
    case crypto = "Crypto", property = "Immobilier", custom = "Personnalisé"
    var id: String { rawValue }
}

enum PatrimoineSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Account.self, Instrument.self, Movement.self, Price.self, Snapshot.self] }

    @Model final class Account {
        @Attribute(.unique) var id: UUID
        var name: String
        var institution: String
        var kind: String
        var currency: String
        var createdAt: Date
        var archived: Bool
        var deletedAt: Date?
        init(name: String, institution: String, kind: String, currency: String = "EUR") {
            id = UUID(); self.name = name; self.institution = institution; self.kind = kind
            self.currency = currency; createdAt = .now; archived = false
        }
    }

    @Model final class Instrument {
        @Attribute(.unique) var id: UUID
        var name: String
        var symbol: String
        var isin: String
        var exchange: String
        var currency: String
        var kind: String
        var distribution: String
        init(name: String, symbol: String, isin: String, exchange: String, kind: String, distribution: String) {
            id = UUID(); self.name = name; self.symbol = symbol; self.isin = isin
            self.exchange = exchange; currency = "EUR"; self.kind = kind; self.distribution = distribution
        }
    }

    @Model final class Movement {
        @Attribute(.unique) var id: UUID
        var accountID: UUID
        var instrumentID: UUID?
        var date: Date
        var sequence: Int
        var kind: String
        // Decimal strings avoid binary floating point and preserve decimal precision in storage.
        var quantityText: String
        var amountText: String
        var feesText: String
        var currency: String
        init(accountID: UUID, entry: LedgerEntry) {
            id = entry.id; self.accountID = accountID; instrumentID = entry.instrumentID
            date = entry.date; sequence = entry.sequence; kind = entry.kind.rawValue
            quantityText = entry.quantity.description; amountText = entry.amount.description
            feesText = entry.fees.description; currency = entry.currency
        }
        func entry() throws -> LedgerEntry {
            guard let kind = MovementKind(rawValue: kind),
                  let quantity = DecimalInput.parse(quantityText),
                  let amount = DecimalInput.parse(amountText),
                  let fees = DecimalInput.parse(feesText) else { throw StorageError.corruptRecord }
            return LedgerEntry(id: id, date: date, sequence: sequence, kind: kind,
                               instrumentID: instrumentID, quantity: quantity, amount: amount, fees: fees, currency: currency)
        }
    }

    @Model final class Price {
        @Attribute(.unique) var id: UUID
        var instrumentID: UUID
        var valueText: String
        var currency: String
        var observedAt: Date
        var enteredAt: Date
        var source: String
        init(instrumentID: UUID, value: Decimal, date: Date) {
            id = UUID(); self.instrumentID = instrumentID; valueText = value.description
            currency = "EUR"; observedAt = date; enteredAt = .now; source = "Saisie manuelle"
        }
    }

    @Model final class Snapshot {
        @Attribute(.unique) var id: UUID
        var date: Date
        var valueText: String
        var contributionsText: String
        var scope: String
        init(value: Decimal, contributions: Decimal, scope: String) {
            id = UUID(); date = .now; valueText = value.description
            contributionsText = contributions.description; self.scope = scope
        }
    }
}

enum PatrimoineMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PatrimoineSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Account = PatrimoineSchemaV1.Account
typealias Instrument = PatrimoineSchemaV1.Instrument
typealias Movement = PatrimoineSchemaV1.Movement
typealias Price = PatrimoineSchemaV1.Price
typealias Snapshot = PatrimoineSchemaV1.Snapshot

enum StorageError: LocalizedError {
    case corruptRecord, invalidName, incompatibleCurrency, missingInstrument, accumulatingDividend
    var errorDescription: String? {
        switch self {
        case .corruptRecord: return "Une donnée locale est illisible. Les données ont été conservées."
        case .invalidName: return "Renseignez le nom et l’établissement."
        case .incompatibleCurrency: return "Cette version prend en charge les comptes et instruments en euros uniquement."
        case .missingInstrument: return "Sélectionnez un instrument enregistré."
        case .accumulatingDividend: return "Un ETF capitalisant ne verse pas de dividende. Vérifiez sa politique de distribution."
        }
    }
}
