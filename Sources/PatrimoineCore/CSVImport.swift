import Foundation
import CryptoKit

public struct CSVTable: Sendable {
    public let headers: [String]
    public let rows: [[String]]
    public init(_ text: String, delimiter: Character? = nil) throws {
        guard text.utf8.count <= 5_000_000 else { throw ImportFailure("Fichier trop volumineux (5 Mo maximum).") }
        let withoutBOM = text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text
        // CRLF is a single Swift Character; normalize line endings before parsing.
        let text = withoutBOM.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let separator: Character
        if let delimiter { separator = delimiter }
        else {
            let first = text.components(separatedBy: .newlines).first ?? ""
            func count(_ candidate: Character) -> Int {
                var inside = false, total = 0
                for char in first { if char == "\"" { inside.toggle() }; if char == candidate && !inside { total += 1 } }
                return total
            }
            separator = [Character(";"), ",", "\t"].max { count($0) < count($1) } ?? ";"
        }
        var records: [[String]] = [], row: [String] = [], cell = ""
        var quoted = false, closed = false
        let chars = Array(text); var index = 0
        func finishCell() { row.append(cell); cell = ""; closed = false }
        func finishRow() { finishCell(); if row.contains(where: { !$0.isEmpty }) { records.append(row) }; row = [] }
        while index < chars.count {
            let character = chars[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { cell.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(character) }
            } else if character == separator { finishCell() }
            else if character == "\r" || character == "\n" {
                finishRow()
                if character == "\r", index + 1 < chars.count, chars[index + 1] == "\n" { index += 1 }
            } else if character == "\"" {
                guard cell.isEmpty && !closed else { throw ImportFailure("Guillemets CSV invalides.") }
                quoted = true
            } else {
                guard !closed else { throw ImportFailure("Caractère inattendu après des guillemets CSV.") }
                cell.append(character)
            }
            index += 1
            guard records.count <= 10_001 else { throw ImportFailure("10 000 opérations maximum par fichier.") }
        }
        guard !quoted else { throw ImportFailure("Guillemets CSV non fermés.") }
        if !cell.isEmpty || !row.isEmpty || closed { finishRow() }
        guard let header = records.first, !header.isEmpty else { throw ImportFailure("Le fichier est vide.") }
        let cleaned = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard records.dropFirst().allSatisfy({ $0.count == header.count }) else { throw ImportFailure("Une ligne n’a pas le même nombre de colonnes que l’en-tête.") }
        guard records.count <= 10_001 else { throw ImportFailure("10 000 opérations maximum par fichier.") }
        // Broker exports may contain unnamed currency columns and repeated labels. Keep every column.
        var used = Set<String>()
        headers = cleaned.enumerated().map { index, original in
            var label = original.isEmpty ? "Colonne \(index + 1) (sans nom)" : original
            if used.contains(label.lowercased()) { label += " [colonne \(index + 1)]" }
            while used.contains(label.lowercased()) { label += "_" }
            used.insert(label.lowercased()); return label
        }
        rows = Array(records.dropFirst())
    }
}

public struct ImportFailure: Error, LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum ImportAmountBasis: String, CaseIterable, Sendable {
    case unconfirmed = "À confirmer", gross = "Montant brut", netCash = "Mouvement net de liquidités"
}

public struct CSVMapping: Sendable, Equatable {
    public var date = -1, kind = -1, amount = -1, currency = -1, quantity = -1
    public var symbol = -1, isin = -1, externalID = -1
    public var status = -1
    public var quoteCurrency = -1
    public var time = -1
    public var broker: ImportBroker = .trading212
    public var signedAmounts = false
    public var inferTradesFromQuantity = false
    public var fixedCurrency = ""
    public var decimalSeparator = "."
    public var actionOverrides: [String: MovementKind] = [:]
    public var fees: Set<Int> = []
    public var dateFormat = "yyyy-MM-dd HH:mm:ss"
    public var timeZoneID = "UTC"
    public var basis: ImportAmountBasis = .unconfirmed
    public init(headers: [String], broker: ImportBroker = .trading212) {
        self.broker = broker
        func find(_ names: [String]) -> Int { headers.firstIndex { names.contains($0.lowercased()) } ?? -1 }
        date = find(["time", "date", "datetime", "booking_date", "timestamp", "date et heure"]); kind = find(["action", "type", "opération", "booking_type", "transaction_type", "description"])
        amount = find(["gross total", "total", "amount", "montant", "montant eur", "valeur eur", "net amount", "net_amount"])
        currency = find(["currency (total)", "currency (gross total)", "currency", "devise"])
        quantity = find(["no. of shares", "quantity", "quantité"])
        symbol = find(["ticker", "symbol"]); isin = find(["isin"]); externalID = find(["id", "transaction id", "transaction_id", "id ordre", "order id"])
        status = find(["status", "statut"])
        quoteCurrency = find(["currency (price / share)", "price_currency", "devise de cotation"])
        if date >= 0 && headers[date].lowercased() == "date" { time = find(["heure", "time"]) }
        fees = Set(headers.indices.filter {
            let name = headers[$0].lowercased()
            return !name.hasPrefix("currency") && ["fee", "tax", "commission", "frais"].contains(where: { name.contains($0) })
        })
    }
}

public struct ImportedMovement: Identifiable, Sendable {
    public let id: Int
    public let date: Date
    public let kind: MovementKind
    public let amount: Decimal
    public let fees: Decimal
    public let quantity: Decimal
    public let currency: String
    public let symbol: String
    public let isin: String
    public let externalID: String
    public let broker: ImportBroker
    public let quoteCurrency: String
    public var cashMovement: Decimal {
        switch kind {
        case .buy, .withdrawal: return -amount - fees
        case .sell, .deposit, .dividend, .interest: return amount - fees
        case .fee: return -amount
        case .split: return 0
        }
    }
    public var instrumentKey: String { isin.isEmpty ? symbol : isin }
    public func ledgerEntry(accountID: UUID, instrumentID: UUID?, sequence: Int, forceNewID: Bool = false) -> LedgerEntry {
        var identity = UUID()
        if !externalID.isEmpty && !forceNewID {
            let data = Data((accountID.uuidString + "|" + broker.rawValue + "/CSV|" + externalID).utf8)
            var bytes = Array(SHA256.hash(data: data).prefix(16))
            // RFC 9562 version 8: app-defined deterministic identity, distinguishable from manual UUIDv4.
            bytes[6] = (bytes[6] & 0x0f) | 0x80
            bytes[8] = (bytes[8] & 0x3f) | 0x80
            identity = UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
        }
        return LedgerEntry(id: identity, date: date, sequence: sequence, kind: kind, instrumentID: instrumentID,
                           quantity: quantity, amount: amount, fees: fees, currency: currency)
    }
}

public struct ImportLine: Identifiable, Sendable {
    public let id: Int
    public let movement: ImportedMovement?
    public let issue: String?
}

public enum CSVImport {
    public static func preview(_ table: CSVTable, mapping: CSVMapping, now: Date = .now) throws -> [ImportLine] {
        guard [mapping.date, mapping.amount].allSatisfy({ table.headers.indices.contains($0) }),
              mapping.inferTradesFromQuantity ? table.headers.indices.contains(mapping.quantity) : table.headers.indices.contains(mapping.kind),
              table.headers.indices.contains(mapping.currency) || mapping.fixedCurrency == "EUR", mapping.basis != .unconfirmed else {
            throw ImportFailure("Choisissez les colonnes requises et confirmez si le montant est brut ou net.")
        }
        guard TimeZone(identifier: mapping.timeZoneID) != nil else { throw ImportFailure("Fuseau horaire invalide.") }
        guard [".", ","].contains(mapping.decimalSeparator) else { throw ImportFailure("Séparateur décimal invalide.") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(identifier: mapping.timeZoneID)
        formatter.dateFormat = mapping.dateFormat; formatter.isLenient = false
        let isoFormatter = ISO8601DateFormatter()
        return table.rows.enumerated().map { offset, row in
            do { return ImportLine(id: offset, movement: try parse(row, headers: table.headers, mapping: mapping, index: offset, now: now, formatter: formatter, isoFormatter: isoFormatter), issue: nil) }
            catch { return ImportLine(id: offset, movement: nil, issue: error.localizedDescription) }
        }
    }
    private static func parse(_ row: [String], headers: [String], mapping m: CSVMapping, index: Int, now: Date,
                              formatter: DateFormatter, isoFormatter: ISO8601DateFormatter) throws -> ImportedMovement {
        func text(_ column: Int) -> String { row.indices.contains(column) ? row[column].trimmingCharacters(in: .whitespacesAndNewlines) : "" }
        func decimal(_ column: Int, empty: Decimal? = nil, signed: Bool = false) throws -> Decimal {
            if text(column).isEmpty, let empty { return empty }
            let raw = text(column), negative = signed && text(column).hasPrefix("-")
            guard !raw.contains(m.decimalSeparator == "." ? "," : ".") else { throw ImportFailure("Séparateur décimal incompatible dans « \(row.indices.contains(column) ? headers[column] : "colonne absente") ». Les séparateurs de milliers ne sont pas acceptés.") }
            let hasSign = negative || (signed && raw.hasPrefix("+"))
            guard let value = DecimalInput.parse(hasSign ? String(raw.dropFirst()) : raw) else { throw ImportFailure("Nombre invalide dans « \(row.indices.contains(column) ? headers[column] : "colonne absente") ». Pas de séparateur de milliers.") }
            return negative ? -value : value
        }
        if m.status >= 0 {
            let status = text(m.status).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            guard ["completed", "executed", "settled", "booked", "termine", "execute", "comptabilise"].contains(status) else {
                throw ImportFailure("Statut non confirmé ou opération en attente : \(text(m.status)).")
            }
        }
        let action = text(m.kind).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let kinds: [String: MovementKind] = ["deposit":.deposit,"versement":.deposit,"withdrawal":.withdrawal,"retrait":.withdrawal,
            "market buy":.buy,"limit buy":.buy,"stop buy":.buy,"stop limit buy":.buy,"buy":.buy,"achat":.buy,
            "market sell":.sell,"limit sell":.sell,"stop sell":.sell,"stop limit sell":.sell,"sell":.sell,"vente":.sell,
            "dividend":.dividend,"dividend (ordinary)":.dividend,"dividende":.dividend,"interest on cash":.interest,"interest":.interest,"interet":.interest,"fee":.fee,"frais":.fee]
        let kind: MovementKind
        if m.inferTradesFromQuantity {
            let signedQuantity = try decimal(m.quantity, signed: true)
            guard signedQuantity != 0 else { throw ImportFailure("Quantité nulle dans le relevé d’achats/ventes.") }
            kind = signedQuantity > 0 ? .buy : .sell
        } else {
            guard let resolved = m.actionOverrides[text(m.kind)] ?? kinds[action] else { throw ImportFailure("Opération non prise en charge : \(text(m.kind)). Associez ce libellé explicitement ou corrigez le CSV.") }
            kind = resolved
        }
        let parsedDate: Date?
        let dateText = text(m.date) + (m.time >= 0 ? " " + text(m.time) : "")
        if m.dateFormat == "yyyy-MM-dd'T'HH:mm:ssXXXXX" {
            parsedDate = isoFormatter.date(from: dateText)
        } else {
            parsedDate = formatter.date(from: dateText).flatMap { formatter.string(from: $0) == dateText ? $0 : nil }
        }
        guard let date = parsedDate, date <= now else { throw ImportFailure("Date invalide, future ou incompatible avec le format sélectionné.") }
        let currency = (m.currency < 0 ? m.fixedCurrency : text(m.currency)).uppercased()
        guard currency == "EUR" else { throw ImportFailure("Le montant comptable doit être en EUR. Aucun taux de change n’est inventé.") }
        var fees: Decimal = 0
        for column in m.fees {
            let signedFee = try decimal(column, empty: 0, signed: m.signedAmounts)
            let fee = signedFee < 0 ? -signedFee : signedFee
            if fee != 0, let companion = headers.firstIndex(where: { $0.lowercased() == "currency (\(headers[column].lowercased()))" }) {
                guard text(companion).uppercased() == currency else { throw ImportFailure("Des frais sont exprimés dans une autre devise.") }
            }
            fees += fee
        }
        let signedTotal = try decimal(m.amount, signed: m.signedAmounts)
        if m.signedAmounts {
            let debit = [.buy, .withdrawal, .fee].contains(kind)
            guard (signedTotal < 0) == debit else { throw ImportFailure("Le signe du montant ne correspond pas au type d’opération. Vérifiez la colonne et la convention sélectionnées.") }
        }
        let total = signedTotal < 0 ? -signedTotal : signedTotal
        var amount = total
        if m.basis == .netCash {
            if [.buy, .withdrawal].contains(kind) { amount = total - fees }
            else if [.sell, .deposit, .dividend, .interest].contains(kind) { amount = total + fees }
        }
        let signedQuantity = [.buy, .sell].contains(kind) ? try decimal(m.quantity, signed: m.signedAmounts || m.inferTradesFromQuantity) : 0
        let quantity = signedQuantity < 0 ? -signedQuantity : signedQuantity
        guard amount > 0, !amount.isNaN, !fees.isNaN, !([.buy,.sell].contains(kind) && quantity <= 0), !(kind == .fee && fees != 0) else { throw ImportFailure("Montant, quantité ou frais incompatibles.") }
        let symbol = text(m.symbol).uppercased(), isin = text(m.isin).uppercased()
        guard !kind.needsInstrument || !symbol.isEmpty || !isin.isEmpty else { throw ImportFailure("Ticker ou ISIN requis.") }
        return ImportedMovement(id: index, date: date, kind: kind, amount: amount, fees: fees, quantity: quantity,
                                currency: currency, symbol: symbol, isin: isin, externalID: text(m.externalID), broker: m.broker, quoteCurrency: text(m.quoteCurrency).uppercased())
    }
    public static func sameEconomics(_ lhs: LedgerEntry, _ rhs: LedgerEntry) -> Bool {
        lhs.date == rhs.date && lhs.kind == rhs.kind && lhs.instrumentID == rhs.instrumentID && lhs.currency == rhs.currency
        && lhs.amount == rhs.amount && lhs.fees == rhs.fees && lhs.quantity == rhs.quantity
    }
    public static func hasImportedIdentity(_ id: UUID) -> Bool { (id.uuid.6 >> 4) == 8 }
    public static func potentialDuplicate(_ lhs: LedgerEntry, _ rhs: LedgerEntry) -> Bool {
        abs(lhs.date.timeIntervalSince(rhs.date)) <= 60 && lhs.kind == rhs.kind && lhs.instrumentID == rhs.instrumentID
        && lhs.currency == rhs.currency && lhs.amount == rhs.amount && lhs.fees == rhs.fees && lhs.quantity == rhs.quantity
    }
}
