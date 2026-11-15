import SwiftUI
import SwiftData
import PatrimoineCore

struct AccountsView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var prices: [Price]
    @State private var create = false
    @State private var includeArchived = false
    private var summaries: [AccountSummary] {
        ValuationService.summaries(accounts: accounts, movements: movements, prices: prices)
            .filter { includeArchived || !$0.account.archived }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(title: "Une place pour chaque projet", detail: "PEA, compte-titres et comptes personnels en euros.")
                Toggle("Afficher les comptes archivés", isOn: $includeArchived).font(.subheadline)
                if summaries.isEmpty {
                    EmptyStateView(title: "Vos comptes, réunis", message: "Ajoutez votre premier portefeuille. Vos données restent sur cet iPhone.", symbol: "wallet.pass")
                }
                ForEach(summaries, id: \.account.id) { summary in
                    NavigationLink { AccountDetailView(account: summary.account) } label: { AccountCard(summary: summary) }.buttonStyle(.plain)
                }
                Button { create = true } label: {
                    Label("Nouveau portefeuille", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(PrimaryButtonStyle())
            }.padding(20)
        }
        .background(Palette.background).navigationTitle("Portefeuilles")
        .sheet(isPresented: $create) { AccountForm() }
    }
}

struct AccountCard: View {
    let summary: AccountSummary
    var body: some View {
        FinancialCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "building.columns").font(.title3).foregroundStyle(Palette.accent)
                    .frame(width: 46, height: 46).background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.account.name).font(.headline)
                    Text(summary.account.institution).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(summary.account.kind).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                if summary.account.archived { Text("Archivé").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                MoneyText(value: summary.value).font(.title3.weight(.semibold))
            }
            if let issue = summary.issue { InlineIssue(message: issue) }
        }
    }
}

struct AccountForm: View {
    var account: Account? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var institution = ""
    @State private var kind: AccountKind = .pea
    @State private var error: ErrorMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section("Votre portefeuille") {
                    TextField("Nom du portefeuille", text: $name).textInputAutocapitalization(.sentences)
                    TextField("Établissement", text: $institution)
                    Picker("Type", selection: $kind) { ForEach(AccountKind.allCases) { Text($0.rawValue).tag($0) } }
                    LabeledContent("Devise", value: "EUR")
                }
                Section {
                    Text("Le type sert au classement. Seul le suivi comptable manuel des liquidités, actions et ETF en euros est disponible dans cette version. Les règles fiscales et produits spécialisés ne sont pas encore calculés.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(account == nil ? "Nouveau portefeuille" : "Modifier le compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || institution.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                if let account { name = account.name; institution = account.institution; kind = AccountKind(rawValue: account.kind) ?? .custom }
            }
            .alert(item: $error) { Alert(title: Text("Enregistrement impossible"), message: Text($0.text)) }
        }
    }
    private func save() {
        do {
            if let account {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StorageError.invalidName }
                account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                account.institution = institution.trimmingCharacters(in: .whitespacesAndNewlines)
                account.kind = kind.rawValue
                try AccountRepository.save(context)
            } else { try AccountRepository.create(name: name, institution: institution, kind: kind, context: context) }
            dismiss()
        } catch { self.error = ErrorMessage(error) }
    }
}

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var movements: [Movement]
    @Query(sort: \Instrument.name) private var instruments: [Instrument]
    @Query private var prices: [Price]
    @State private var addMovement = false
    @State private var addInstrument = false
    @State private var edit = false
    @State private var deleting = false
    @State private var selectedInstrument: Instrument?
    @State private var error: ErrorMessage?
    private var summary: AccountSummary { ValuationService.summaries(accounts: [account], movements: movements, prices: prices)[0] }
    private var history: [Movement] { movements.filter { $0.accountID == account.id }.sorted { ($0.date, $0.sequence) > ($1.date, $1.sequence) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FinancialCard {
                    Text(account.institution + " · " + account.kind).font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(value: summary.value).font(.largeTitle.weight(.semibold))
                    MetricRow(title: "Versements nets", value: summary.ledger?.netContributions)
                    MetricRow(title: "Liquidités", value: summary.ledger?.cash)
                    MetricRow(title: "Plus-values réalisées", value: summary.ledger?.realizedGain)
                    MetricRow(title: "Dividendes nets saisis", value: summary.ledger?.dividends)
                    if let issue = summary.issue { InlineIssue(message: issue) }
                }
                if !account.archived {
                    Button { addMovement = true } label: { Label("Enregistrer une opération", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(PrimaryButtonStyle())
                }
                HStack {
                    SectionHeading(title: "Positions")
                    Spacer()
                    Button("Instrument", systemImage: "plus") { addInstrument = true }.font(.subheadline).disabled(account.archived)
                }
                if let ledger = summary.ledger {
                    let positions = instruments.filter { (ledger.holdings[$0.id]?.quantity ?? 0) > 0 }
                    if positions.isEmpty { Text("Aucune position ouverte.").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(positions) { instrument in
                        Button { selectedInstrument = instrument } label: {
                            AssetRow(instrument: instrument, holding: ledger.holdings[instrument.id]!,
                                price: prices.filter { $0.instrumentID == instrument.id }.sorted { ($0.observedAt, $0.enteredAt) > ($1.observedAt, $1.enteredAt) }.first)
                        }.buttonStyle(.plain)
                    }
                }
                SectionHeading(title: "Journal des opérations", detail: "Historique conservé sans modification silencieuse.")
                if history.isEmpty { Text("Commencez par un versement, puis un achat.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(history) { movement in
                    TransactionRow(movement: movement, instrument: instruments.first { $0.id == movement.instrumentID })
                }
            }.padding(20)
        }
        .background(Palette.background).navigationTitle(account.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Modifier", systemImage: "pencil") { edit = true }
                Button(account.archived ? "Désarchiver" : "Archiver", systemImage: "archivebox") {
                    account.archived.toggle(); persist()
                }
                Button("Placer dans la corbeille", systemImage: "trash", role: .destructive) { deleting = true }
            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
        }
        .confirmationDialog("Placer ce portefeuille dans la corbeille ?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Placer dans la corbeille", role: .destructive) {
                account.deletedAt = .now
                do { try AccountRepository.save(context); dismiss() } catch { self.error = ErrorMessage(error) }
            }
        } message: { Text("Vous pourrez le restaurer depuis Plus. Ses opérations seront conservées.") }
        .sheet(isPresented: $addMovement) { MovementForm(account: account) }
        .sheet(isPresented: $addInstrument) { InstrumentForm() }
        .sheet(isPresented: $edit) { AccountForm(account: account) }
        .sheet(item: $selectedInstrument) { PriceForm(instrument: $0) }
        .alert(item: $error) { Alert(title: Text("Modification impossible"), message: Text($0.text)) }
    }
    private func persist() { do { try AccountRepository.save(context) } catch { self.error = ErrorMessage(error) } }
}

struct AssetRow: View {
    let instrument: Instrument
    let holding: Holding
    let price: Price?
    @AppStorage("privacy.hideAmounts") private var hidden = false
    var body: some View {
        FinancialCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(instrument.name).font(.headline)
                    Text(instrument.symbol + " · " + instrument.exchange).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(instrument.kind).font(.caption).foregroundStyle(.secondary)
            }
            Text(hidden ? "Quantité masquée" : holding.quantity.formatted() + " titres").font(.subheadline)
            MetricRow(title: "Coût d’acquisition", value: holding.cost)
            MetricRow(title: "PRU, frais inclus", value: holding.averageCost)
            MetricRow(title: "Valeur déclarée", value: price.flatMap { DecimalInput.parse($0.valueText) }.map { holding.quantity * $0 })
            if let price {
                Text("Saisie manuelle · " + price.observedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                if Date.now.timeIntervalSince(price.observedAt) > 86400 { InlineIssue(message: "Cours datant de plus de 24 heures") }
            } else { InlineIssue(message: "Touchez pour saisir un cours réel et sa date.") }
        }
    }
}

struct TransactionRow: View {
    let movement: Movement
    let instrument: Instrument?
    @AppStorage("privacy.hideAmounts") private var hidden = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.left.arrow.right").foregroundStyle(Palette.accent).frame(width: 32, height: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(MovementKind(rawValue: movement.kind)?.label ?? "Opération inconnue").font(.subheadline.weight(.semibold))
                if let instrument { Text(instrument.name).font(.caption).foregroundStyle(.secondary) }
                Text(movement.date, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                MoneyText(value: DecimalInput.parse(movement.amountText)).font(.subheadline.weight(.medium))
                if !hidden && movement.feesText != "0" { Text("Frais : " + movement.feesText + " €").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 8)
    }
}
