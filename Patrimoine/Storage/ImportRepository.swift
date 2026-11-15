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
        let sources = Set(rows.map(\.broker))
        guard sources.count <= 1 else { throw ImportFailure("Un lot doit provenir d’un seul établissement.") }
        func normalized(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
        if let institution = ImportBroker.allCases.first(where: { normalized($0.rawValue) == normalized(account.institution) }),
           let source = sources.first, institution != source {
            throw ImportFailure("Le courtier sélectionné ne correspond pas à l’établissement de ce portefeuille. Choisissez le bon compte.")
        }
        let stored = try context.fetch(FetchDescriptor<Movement>()).filter { $0.accountID == account.id }.map { try $0.entry() }
        let registered = try context.fetch(FetchDescriptor<Instrument>())
        var byID: [UUID: LedgerEntry] = [:]
        var allBuckets: [String: [LedgerEntry]] = [:]
        var weakBuckets: [String: [LedgerEntry]] = [:]
        func key(_ entry: LedgerEntry, offset: Int64 = 0) -> String {
            let minute = Int64((entry.date.timeIntervalSince1970 / 60).rounded(.down)) + offset
            return [entry.kind.rawValue, entry.instrumentID?.uuidString ?? "", entry.currency,
                NSDecimalNumber(decimal: entry.quantity).stringValue, NSDecimalNumber(decimal: entry.amount).stringValue,
                NSDecimalNumber(decimal: entry.fees).stringValue, String(minute)].joined(separator: "|")
        }
        func index(_ entry: LedgerEntry) {
            byID[entry.id] = entry
            allBuckets[key(entry), default: []].append(entry)
            if !CSVImport.hasImportedIdentity(entry.id) { weakBuckets[key(entry), default: []].append(entry) }
        }
        for entry in stored { index(entry) }
        var sequence = (stored.map(\.sequence).max() ?? -1) + 1
        var result: [PreparedImport] = []
        for row in rows.sorted(by: { ($0.date, $0.id) < ($1.date, $1.id) }) {
            let instrumentID = row.kind.needsInstrument ? instruments[row.instrumentKey] : nil
            if row.kind.needsInstrument {
                guard let instrument = registered.first(where: { $0.id == instrumentID }) else { throw ImportFailure("Associez l’instrument \(row.instrumentKey) avant l’import.") }
                if !row.isin.isEmpty && !instrument.isin.isEmpty && row.isin != instrument.isin { throw ImportFailure("L’ISIN de l’instrument choisi ne correspond pas au fichier.") }
                if !row.quoteCurrency.isEmpty && row.quoteCurrency != instrument.currency {
                    throw ImportFailure("La devise de cotation de \(row.instrumentKey) ne correspond pas à celle de l’instrument choisi. Vérifiez la place et la devise de cotation.")
                }
                if row.kind == .dividend && instrument.distribution == "Capitalisant" { throw StorageError.accumulatingDividend }
            }
            guard row.currency == account.currency else { throw StorageError.incompatibleCurrency }
            var entry = row.ledgerEntry(accountID: account.id, instrumentID: instrumentID, sequence: sequence)
            let identifierMatch = byID[entry.id]
            let conflict = identifierMatch.map { !CSVImport.sameEconomics($0, entry) } ?? false
            let similar = [-1, 0, 1].contains { offset in
                // Distinct source IDs remain distinct. Nearby buckets handle second/millisecond differences
                // against manually entered operations without scanning the complete ledger for every row.
                let bucketKey = key(entry, offset: Int64(offset))
                let candidates = row.externalID.isEmpty ? allBuckets[bucketKey] : weakBuckets[bucketKey]
                return candidates?.contains { CSVImport.potentialDuplicate($0, entry) } ?? false
            }
            let duplicate = identifierMatch != nil || similar
            if duplicate && !conflict && allowSimilar.contains(row.id) {
                entry = row.ledgerEntry(accountID: account.id, instrumentID: instrumentID, sequence: sequence, forceNewID: true)
            }
            result.append(PreparedImport(id: row.id, entry: entry, duplicate: duplicate && !allowSimilar.contains(row.id), conflict: conflict))
            if !conflict && (!duplicate || allowSimilar.contains(row.id)) { index(entry); sequence += 1 }
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
