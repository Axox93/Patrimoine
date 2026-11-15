import SwiftUI
import SwiftData
import Charts
import PatrimoineCore

struct AnalysisView: View {
    @Query private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var prices: [Price]
    @AppStorage("privacy.hideAmounts") private var hidden = false
    private var summaries: [AccountSummary] { ValuationService.summaries(accounts: accounts, movements: movements, prices: prices) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeading(title: "Prendre du recul", detail: "Répartition des valeurs déclarées par portefeuille.")
                if let total = ValuationService.total(summaries), total > 0 {
                    FinancialCard {
                        if !hidden {
                            Chart(summaries, id: \.account.id) { summary in
                                SectorMark(angle: .value("Valeur", NSDecimalNumber(decimal: summary.value ?? 0).doubleValue), innerRadius: .ratio(0.72), angularInset: 3)
                                    .cornerRadius(5).foregroundStyle(by: .value("Compte", summary.account.name))
                            }.frame(height: 220).accessibilityLabel("Allocation par portefeuille")
                        }
                        ForEach(summaries, id: \.account.id) { MetricRow(title: $0.account.name, value: $0.value) }
                    }
                    FinancialCard {
                        SectionHeading(title: "Ce que les chiffres disent")
                        let cash = summaries.reduce(Decimal.zero) { $0 + ($1.ledger?.cash ?? 0) }
                        MetricRow(title: "Liquidités", value: cash)
                        MetricRow(title: "Plus-values réalisées", value: summaries.reduce(0) { $0 + ($1.ledger?.realizedGain ?? 0) })
                        MetricRow(title: "Revenus nets saisis", value: summaries.reduce(0) { $0 + ($1.ledger?.netIncome ?? 0) })
                    }
                } else {
                    FinancialCard { EmptyStateView(title: "Une vision à construire", message: "Ajoutez des comptes, des opérations et les cours manquants pour calculer votre répartition.", symbol: "chart.pie") }
                }
                FinancialCard {
                    SectionHeading(title: "Des analyses qui demandent du recul")
                    Text("TWR, XIRR, volatilité, benchmarks et compositions d’ETF ne sont pas encore disponibles. Ils nécessitent des historiques et des flux validés. Aucun rendement approximatif ne leur est substitué.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(20)
        }.background(Palette.background).navigationTitle("Analyses")
    }
}

struct IncomeView: View {
    @Query private var accounts: [Account]
    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query private var instruments: [Instrument]
    private var income: [Movement] {
        let ids = Set(accounts.filter { $0.deletedAt == nil }.map(\.id))
        return movements.filter { ids.contains($0.accountID) && [MovementKind.dividend.rawValue, MovementKind.interest.rawValue].contains($0.kind) }
    }
    private var net: Decimal? {
        do { return try income.reduce(Decimal.zero) { let entry = try $1.entry(); return $0 + entry.amount - entry.fees } }
        catch { return nil }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FinancialCard {
                    Text("Revenus enregistrés").font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(value: net).font(.largeTitle.weight(.semibold))
                    Text("Depuis l’origine • nets des frais et retenues saisis").font(.caption).foregroundStyle(.secondary)
                }
                if income.isEmpty {
                    FinancialCard { EmptyStateView(title: "Les fruits de votre patience", message: "Les dividendes et intérêts saisis dans vos portefeuilles apparaîtront ici. Aucun revenu n’est estimé automatiquement.", symbol: "leaf") }
                } else {
                    SectionHeading(title: "Encaissements", detail: "Montants bruts affichés dans le journal ; retenues saisies séparément.")
                    ForEach(income) { movement in TransactionRow(movement: movement, instrument: instruments.first { $0.id == movement.instrumentID }) }
                }
                Text("Calendrier prévisionnel, coupons et projection sur douze mois : à venir après validation des données et conventions.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(20)
        }.background(Palette.background).navigationTitle("Revenus")
    }
}

struct MoreView: View {
    @Environment(AppLock.self) private var lock
    @AppStorage("privacy.hideAmounts") private var hidden = false
    var body: some View {
        List {
            Section("Votre espace") {
                NavigationLink("Instruments", systemImage: "list.bullet.rectangle") { InstrumentsView() }
                NavigationLink("Corbeille", systemImage: "trash") { TrashView() }
            }
            Section("Confidentialité") {
                Toggle("Masquer les montants", isOn: $hidden)
                Toggle("Verrouillage de l’application", isOn: Binding(get: { lock.enabled }, set: { enabled in
                    Task { await lock.authenticate(enabling: enabled, disabling: !enabled) }
                })).disabled(lock.authenticating)
                if let message = lock.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                Text("Face ID ou code de l’iPhone. Les écrans sont masqués lorsque l’application est inactive.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("État des intégrations") {
                LabeledContent("Cours de marché", value: "Saisie manuelle")
                LabeledContent("Banques et courtiers", value: "Non connectés")
                LabeledContent("Import CSV / Excel / PDF", value: "À venir")
                LabeledContent("Sauvegarde chiffrée", value: "À venir")
                Text("Cette version de fondations conserve les données uniquement sur cet iPhone. Elles ne sont pas synchronisées ni incluses dans la sauvegarde iCloud. Ne l’utilisez pas comme unique registre avant la validation de la sauvegarde et de la restauration.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("À propos") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                Text("Patrimoine · Personnel par nature.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Plus")
    }
}

struct InstrumentsView: View {
    @Query(sort: \Instrument.name) private var instruments: [Instrument]
    @State private var create = false
    @State private var selected: Instrument?
    var body: some View {
        List {
            if instruments.isEmpty { Text("Ajoutez une action ou un ETF pour l’utiliser dans vos opérations.").foregroundStyle(.secondary) }
            ForEach(instruments) { instrument in
                Button { selected = instrument } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(instrument.name).foregroundStyle(.primary)
                        Text(instrument.symbol + " · " + instrument.exchange + " · EUR").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            }
        }.navigationTitle("Instruments")
        .toolbar { Button("Ajouter", systemImage: "plus") { create = true } }
        .sheet(isPresented: $create) { InstrumentForm() }
        .sheet(item: $selected) { PriceForm(instrument: $0) }
    }
}

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var error: ErrorMessage?
    var body: some View {
        List {
            Section {
                ForEach(accounts.filter { $0.deletedAt != nil }) { account in
                    HStack {
                        VStack(alignment: .leading) { Text(account.name); Text(account.institution).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Restaurer") {
                            account.deletedAt = nil
                            do { try AccountRepository.save(context) } catch { self.error = ErrorMessage(error) }
                        }.frame(minHeight: 44)
                    }
                }
            } footer: { Text("La mise à la corbeille exclut le compte du patrimoine, mais conserve toutes ses opérations. Aucune purge définitive n’est proposée dans cette version.") }
        }.navigationTitle("Corbeille")
        .alert(item: $error) { Alert(title: Text("Restauration impossible"), message: Text($0.text)) }
    }
}
