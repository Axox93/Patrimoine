import SwiftUI
import SwiftData
import PatrimoineCore

struct MovementForm: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Instrument.name) private var instruments: [Instrument]
    @Query private var movements: [Movement]
    @State private var kind: MovementKind = .deposit
    @State private var date = Date.now
    @State private var instrumentID: UUID?
    @State private var quantity = ""
    @State private var amount = ""
    @State private var fees = "0"
    @State private var error: ErrorMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Opération", selection: $kind) { ForEach(MovementKind.allCases, id: \.self) { Text($0.label).tag($0) } }
                    DatePicker("Date comptable", selection: $date, in: ...Date.now)
                    if kind.needsInstrument {
                        Picker("Instrument", selection: $instrumentID) {
                            Text("Choisir").tag(UUID?.none)
                            ForEach(instruments) { Text($0.name + " · " + $0.currency).tag(Optional($0.id)) }
                        }
                    }
                    if [.buy, .sell, .split].contains(kind) {
                        TextField(kind == .split ? "Coefficient (ex. 4)" : "Quantité de titres", text: $quantity).keyboardType(.decimalPad)
                    }
                    if kind != .split {
                        TextField("Montant brut total en EUR", text: $amount).keyboardType(.decimalPad)
                        if kind != .fee { TextField("Frais et retenues en EUR", text: $fees).keyboardType(.decimalPad) }
                    }
                } header: { Text(account.name) } footer: {
                    Text(kind == .buy || kind == .sell
                        ? "Saisissez le montant total brut de l’opération, et non le prix unitaire. Les frais sont comptabilisés séparément."
                        : kind == .split ? "Le coefficient multiplie la quantité détenue sans changer son coût total."
                        : "Montants positifs. Le journal détermine automatiquement le sens du mouvement.")
                }
                Section {
                    Text("Le compte doit être alimenté avant tout achat. Une vente dépassant vos titres est refusée. Les opérations sont rejouées dans leur ordre comptable.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if kind == .dividend { Text("Les frais et retenues saisis sont déduits du montant brut. Aucun calcul fiscal automatique.").font(.footnote) }
                }
            }
            .navigationTitle("Nouvelle opération").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer", action: save) }
            }
            .alert(item: $error) { Alert(title: Text("Opération refusée"), message: Text($0.text)) }
        }
    }
    private func save() {
        do {
            guard let amount = kind == .split ? Decimal.zero : DecimalInput.parse(amount),
                  let fees = [.split, .fee].contains(kind) ? Decimal.zero : DecimalInput.parse(fees),
                  let quantity = [.buy, .sell, .split].contains(kind) ? DecimalInput.parse(quantity) : Decimal.zero else {
                throw LedgerError.invalidAmount
            }
            let order = (movements.filter { $0.accountID == account.id }.map(\.sequence).max() ?? -1) + 1
            let entry = LedgerEntry(date: date, sequence: order, kind: kind,
                instrumentID: kind.needsInstrument ? instrumentID : nil,
                quantity: quantity, amount: amount, fees: fees, currency: account.currency)
            try AccountRepository.append(entry, to: account, context: context)
            dismiss()
        } catch { self.error = ErrorMessage(error) }
    }
}

struct InstrumentForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var instruments: [Instrument]
    @State private var name = ""
    @State private var symbol = ""
    @State private var isin = ""
    @State private var exchange = ""
    @State private var kind = "Action"
    @State private var distribution = "Non renseigné"
    @State private var currency = "EUR"
    @State private var error: ErrorMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section("Identité de l’instrument") {
                    TextField("Nom", text: $name)
                    TextField("Ticker", text: $symbol).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("ISIN (facultatif)", text: $isin).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("Code MIC de la place (ex. XPAR)", text: $exchange).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Picker("Classe", selection: $kind) { Text("Action").tag("Action"); Text("ETF").tag("ETF") }
                    if kind == "ETF" {
                        Picker("Distribution", selection: $distribution) {
                            Text("Non renseigné").tag("Non renseigné"); Text("Capitalisant").tag("Capitalisant"); Text("Distribuant").tag("Distribuant")
                        }
                    }
                    Picker("Devise de cotation", selection: $currency) {
                        ForEach(["EUR", "USD", "GBP", "GBX", "CHF", "JPY", "CAD", "AUD", "HKD"], id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    Text("Vérifiez l’identité et la place de cotation auprès de votre courtier. Ces informations sont déclarées par vous et ne sont pas vérifiées par une source externe.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nouvel instrument").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Ajouter", action: save) }
            }
            .alert(item: $error) { Alert(title: Text("Instrument non ajouté"), message: Text($0.text)) }
        }
    }
    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanExchange = exchange.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanISIN = isin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            guard !cleanName.isEmpty, !cleanSymbol.isEmpty, cleanExchange.range(of: "^[A-Z0-9]{4}$", options: .regularExpression) != nil,
                  cleanISIN.isEmpty || cleanISIN.range(of: "^[A-Z]{2}[A-Z0-9]{9}[0-9]$", options: .regularExpression) != nil else {
                throw FormError.invalidIdentity
            }
            guard !instruments.contains(where: { $0.symbol == cleanSymbol && $0.exchange == cleanExchange && $0.currency == currency }) else { throw FormError.duplicateInstrument }
            context.insert(Instrument(name: cleanName, symbol: cleanSymbol, isin: cleanISIN,
                exchange: cleanExchange, kind: kind, distribution: kind == "ETF" ? distribution : "Non renseigné", currency: currency))
            try AccountRepository.save(context); dismiss()
        } catch { self.error = ErrorMessage(error) }
    }
}

struct PriceForm: View {
    let instrument: Instrument
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var date = Date.now
    @State private var error: ErrorMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section(instrument.name) {
                    TextField("Valeur d’un titre en EUR", text: $value).keyboardType(.decimalPad)
                    DatePicker("Date du cours", selection: $date, in: ...Date.now)
                    Text("Devise de cotation de l’instrument : \(instrument.currency). Saisissez sa valeur équivalente en euros depuis une source fiable, en effectuant vous-même la conversion si nécessaire. Aucun taux n’est calculé par l’application. Cette valeur déclarée, datée, s’applique à tous vos portefeuilles.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Valorisation manuelle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        do {
                            guard let price = DecimalInput.parse(value) else { throw LedgerError.invalidAmount }
                            let record = Price(instrumentID: instrument.id, value: price, date: date)
                            if instrument.currency != "EUR" { record.source = "Valeur en EUR déclarée (cotation \(instrument.currency))" }
                            context.insert(record)
                            try AccountRepository.save(context); dismiss()
                        } catch { self.error = ErrorMessage(error) }
                    }
                }
            }
            .alert(item: $error) { Alert(title: Text("Cours non enregistré"), message: Text($0.text)) }
        }
    }
}

enum FormError: LocalizedError {
    case invalidIdentity, duplicateInstrument
    var errorDescription: String? {
        switch self {
        case .invalidIdentity: return "Renseignez le nom, le ticker, un code MIC de quatre caractères et un ISIN au bon format si vous en saisissez un."
        case .duplicateInstrument: return "Cet instrument existe déjà sur cette place. Vous pouvez le sélectionner dans vos opérations."
        }
    }
}
