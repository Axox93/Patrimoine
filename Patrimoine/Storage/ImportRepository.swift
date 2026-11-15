import Foundation
import SwiftData
import PatrimoineCore

struct PreparedImport: Identifiable {
    let id: Int
    let entry: LedgerEntry
    let duplicate: Bool
    let conflict: Bool
}

@MainActor enum ImportRepository {
    static func prepare(_ rows: [ImportedMovement], account: Account, instruments: [String: UUID],
                        allowSimilar: Set<Int>, context: ModelContext) throws -> [PreparedImport] {
        guard !account.archived && account.deletedAt == nil else { throw ImportFailure("Choisissez un portefeuille actif.") }
        let stored = try context.fetch(FetchDescriptor<Movement>()).filter { $0.accountID == account.id }.map { try $0.entry() }
        let registered = try context.fetch(FetchDescriptor<Instrument>())
        var compared = stored
        var sequence = (stored.map(\.sequence).max() ?? -1) + 1
        var result: [PreparedImport] = []
        for row in rows.sorted(by: { ($0.date, $0.id) < ($1.date, $1.id) }) {
            let instrumentID = row.kind.needsInstrument ? instruments[row.instrumentKey] : nil
            if row.kind.needsInstrument {
                guard let instrument = registered.first(where: { $0.id == instrumentID }) else { throw ImportFailure("Associez l’instrument \(row.instrumentKey) avant l’import.") }
                if !row.isin.isEmpty && !instrument.isin.isEmpty && row.isin != instrument.isin { throw ImportFailure("L’ISIN de l’instrument choisi ne correspond pas au fichier.") }
                if row.kind == .dividend && instrument.distribution == "Capitalisant" { throw StorageError.accumulatingDividend }
            }
            guard row.currency == account.currency else { throw StorageError.incompatibleCurrency }
            var entry = row.ledgerEntry(accountID: account.id, instrumentID: instrumentID, sequence: sequence)
            let identifierMatch = compared.first { $0.id == entry.id }
            let conflict = identifierMatch.map { !CSVImport.sameEconomics($0, entry) } ?? false
            let similar = compared.contains {
                // Distinct source IDs identify distinct operations even when their values are identical.
                (row.externalID.isEmpty || !CSVImport.hasImportedIdentity($0.id)) && CSVImport.potentialDuplicate($0, entry)
            }
            let duplicate = identifierMatch != nil || similar
            if duplicate && !conflict && allowSimilar.contains(row.id) {
                entry = row.ledgerEntry(accountID: account.id, instrumentID: instrumentID, sequence: sequence, forceNewID: true)
            }
            result.append(PreparedImport(id: row.id, entry: entry, duplicate: duplicate && !allowSimilar.contains(row.id), conflict: conflict))
            if !conflict && (!duplicate || allowSimilar.contains(row.id)) { compared.append(entry); sequence += 1 }
        }
        return result
    }

    static func commit(_ rows: [ImportedMovement], account: Account, instruments: [String: UUID],
                       allowSimilar: Set<Int>, context: ModelContext) throws -> Int {
        // Recompute at confirmation time: a preview is never trusted as a write authorization.
        let prepared = try prepare(rows, account: account, instruments: instruments, allowSimilar: allowSimilar, context: context)
        guard !prepared.contains(where: \.conflict) else { throw ImportFailure("Un identifiant du fichier existe avec des données différentes. Aucun historique n’a été modifié.") }
        let additions = prepared.filter { !$0.duplicate }.map(\.entry)
        guard !additions.isEmpty else { throw ImportFailure("Aucune nouvelle opération à importer.") }
        let stored = try context.fetch(FetchDescriptor<Movement>()).filter { $0.accountID == account.id }.map { try $0.entry() }
        _ = try LedgerEngine.replay(stored + additions, currency: account.currency)
        for entry in additions { context.insert(Movement(accountID: account.id, entry: entry)) }
        try AccountRepository.save(context)
        return additions.count
    }
}
