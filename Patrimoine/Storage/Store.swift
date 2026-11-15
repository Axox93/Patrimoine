import Foundation
import SwiftData
import PatrimoineCore

enum StoreFactory {
    @MainActor static func make(inMemory: Bool = false, at customURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PatrimoineSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let folder = customURL?.deletingLastPathComponent() ?? URL.applicationSupportDirectory.appending(path: "Patrimoine", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            // Exclude the sensitive database from automatic cloud backup. Local data stays on this device.
            var protectedFolder = folder
            var resources = URLResourceValues(); resources.isExcludedFromBackup = true
            try protectedFolder.setResourceValues(resources)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
            for child in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: child.path)
            }
            configuration = ModelConfiguration("Patrimoine", schema: schema,
                url: customURL ?? folder.appending(path: "Patrimoine.store"), cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, migrationPlan: PatrimoineMigrationPlan.self, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }
}

@MainActor enum AccountRepository {
    static func save(_ context: ModelContext) throws {
        do { try context.save() } catch { context.rollback(); throw error }
    }
    static func create(name: String, institution: String, kind: AccountKind, context: ModelContext) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let institution = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !institution.isEmpty else { throw StorageError.invalidName }
        context.insert(Account(name: name, institution: institution, kind: kind.rawValue))
        try save(context)
    }
    static func append(_ entry: LedgerEntry, to account: Account, context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<Movement>()).filter { $0.accountID == account.id }
        if entry.kind.needsInstrument {
            guard let instrument = try context.fetch(FetchDescriptor<Instrument>()).first(where: { $0.id == entry.instrumentID }) else {
                throw StorageError.missingInstrument
            }
            if entry.kind == .dividend && instrument.distribution == "Capitalisant" { throw StorageError.accumulatingDividend }
        }
        _ = try LedgerEngine.replay(try entries.map { try $0.entry() } + [entry], currency: account.currency)
        context.insert(Movement(accountID: account.id, entry: entry))
        try save(context)
    }
}

struct AccountSummary {
    let account: Account
    let ledger: LedgerResult?
    let value: Decimal?
    let issue: String?
}

@MainActor enum ValuationService {
    static func prices(_ records: [Price]) throws -> [UUID: Decimal] {
        var values: [UUID: Decimal] = [:]
        for record in records.sorted(by: { ($0.observedAt, $0.enteredAt) > ($1.observedAt, $1.enteredAt) }) where values[record.instrumentID] == nil {
            guard record.currency == "EUR", let value = DecimalInput.parse(record.valueText) else { throw StorageError.corruptRecord }
            values[record.instrumentID] = value
        }
        return values
    }
    static func summaries(accounts: [Account], movements: [Movement], prices: [Price]) -> [AccountSummary] {
        accounts.filter { $0.deletedAt == nil }.map { account in
            do {
                guard account.currency == "EUR" else { throw StorageError.incompatibleCurrency }
                let entries = try movements.filter { $0.accountID == account.id }.map { try $0.entry() }
                let ledger = try LedgerEngine.replay(entries, currency: account.currency)
                let value = ledger.valuation(prices: try Self.prices(prices))
                return AccountSummary(account: account, ledger: ledger, value: value,
                                      issue: value == nil ? "Cours manquant : valorisation incomplète" : nil)
            } catch {
                return AccountSummary(account: account, ledger: nil, value: nil, issue: error.localizedDescription)
            }
        }
    }
    static func total(_ summaries: [AccountSummary]) -> Decimal? {
        guard summaries.allSatisfy({ $0.value != nil }) else { return nil }
        return summaries.reduce(0) { $0 + ($1.value ?? 0) }
    }
    static func scope(_ accounts: [Account]) -> String {
        accounts.filter { $0.deletedAt == nil }.map { $0.id.uuidString }.sorted().joined(separator: ";")
    }
}
