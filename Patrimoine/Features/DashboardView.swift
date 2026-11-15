import SwiftUI
import SwiftData
import Charts
import PatrimoineCore

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var prices: [Price]
    @Query(sort: \Snapshot.date) private var snapshots: [Snapshot]
    @AppStorage("privacy.hideAmounts") private var hidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCreate = false
    @State private var error: ErrorMessage?
    private var summaries: [AccountSummary] { ValuationService.summaries(accounts: accounts, movements: movements, prices: prices) }
    private var total: Decimal? { ValuationService.total(summaries) }
    private var contributions: Decimal? {
        summaries.allSatisfy { $0.ledger != nil } ? summaries.reduce(0) { $0 + ($1.ledger?.netContributions ?? 0) } : nil
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VOTRE VUE D’ENSEMBLE").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                        Text("Chaque détail compte.").font(.title2.weight(.semibold))
                    }
                    Spacer()
                    Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { hidden.toggle() } } label: {
                        Image(systemName: hidden ? "eye.slash" : "eye").frame(width: 44, height: 44)
                    }.accessibilityLabel(hidden ? "Afficher les montants" : "Masquer les montants")
                }
                FinancialCard {
                    Label("Patrimoine suivi", systemImage: "circle.dotted").font(.subheadline).foregroundStyle(.secondary)
                    MoneyText(value: total).font(.system(.largeTitle, design: .rounded, weight: .semibold)).minimumScaleFactor(0.7)
                    if let total, let contributions, !summaries.isEmpty {
                        HStack { PerformanceBadge(value: total - contributions); Text("gain net depuis l’origine").font(.caption).foregroundStyle(.secondary) }
                    }
                    Divider()
                    MetricRow(title: "Versements nets", value: contributions)
                    Text("Comptes en euros • valorisations déclarées").font(.caption).foregroundStyle(.secondary)
                    if summaries.contains(where: { $0.issue != nil }) { InlineIssue(message: "Complétez les cours manquants pour obtenir le total.") }
                }
                if summaries.isEmpty {
                    FinancialCard {
                        EmptyStateView(title: "Votre histoire commence ici",
                            message: "Créez un PEA ou un compte-titres, puis enregistrez votre premier versement. Aucune donnée de démonstration n’est ajoutée.")
                        Button { showCreate = true } label: {
                            Label("Créer un portefeuille", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.borderedProminent)
                    }
                } else {
                    FinancialCard {
                        SectionHeading(title: "La perspective compte", detail: "Instantanés réellement enregistrés, sans historique reconstitué.")
                        if hidden {
                            Text("Graphique masqué en mode confidentialité.").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            PortfolioChart(snapshots: snapshots.filter { $0.scope == ValuationService.scope(accounts) })
                        }
                        Button("Enregistrer la valorisation du jour", systemImage: "plus.circle") { saveSnapshot() }
                            .font(.subheadline).disabled(total == nil)
                    }
                    SectionHeading(title: "Vos portefeuilles", detail: "Les comptes archivés restent inclus dans le patrimoine.")
                    ForEach(summaries, id: \.account.id) { summary in
                        NavigationLink { AccountDetailView(account: summary.account) } label: { AccountCard(summary: summary) }.buttonStyle(.plain)
                    }
                    FinancialCard {
                        SectionHeading(title: "En toute transparence")
                        Label("Stockage local, sans connexion bancaire", systemImage: "internaldrive").font(.subheadline)
                        Text("Les prix sont saisis par vous et datés. Les cours automatiques et le change seront intégrés après validation des fournisseurs.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }.padding(20)
        }
        .background(Palette.background).navigationTitle("Patrimoine").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreate) { AccountForm() }
        .alert(item: $error) { Alert(title: Text("Enregistrement impossible"), message: Text($0.text)) }
    }
    private func saveSnapshot() {
        guard let total, let contributions else { return }
        context.insert(Snapshot(value: total, contributions: contributions, scope: ValuationService.scope(accounts)))
        do { try AccountRepository.save(context) } catch { self.error = ErrorMessage(error) }
    }
}

struct PortfolioChart: View {
    let snapshots: [Snapshot]
    @State private var selectedDate: Date?
    @State private var period = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private struct Point: Identifiable {
        let id: UUID; let date: Date; let value: Decimal; let contributions: Decimal
    }
    private var points: [Point] {
        let cutoff = period == 0 ? Date.distantPast : Calendar.current.date(byAdding: .day, value: -period, to: .now)!
        return snapshots.filter { $0.date >= cutoff }.compactMap {
            guard let value = DecimalInput.parse($0.valueText), let contributions = Decimal(string: $0.contributionsText, locale: Locale(identifier: "en_US_POSIX")), !contributions.isNaN else { return nil }
            return Point(id: $0.id, date: $0.date, value: value, contributions: contributions)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Période", selection: $period) {
                Text("1 M").tag(30); Text("1 A").tag(365); Text("Tout").tag(0)
            }.pickerStyle(.segmented)
            if points.count < 2 {
                EmptyStateView(title: "Le temps dessinera la courbe",
                    message: "Enregistrez au moins deux valorisations pour cette période.", symbol: "chart.xyaxis.line")
            } else {
                if let selectedDate, let point = points.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                    HStack { Text(point.date, format: .dateTime.day().month().hour().minute()); Spacer(); MoneyText(value: point.value) }.font(.caption)
                }
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Valeur", NSDecimalNumber(decimal: point.value).doubleValue), series: .value("Série", "Patrimoine"))
                            .foregroundStyle(Palette.accent).lineStyle(StrokeStyle(lineWidth: 2.5))
                        LineMark(x: .value("Date", point.date), y: .value("Versements nets", NSDecimalNumber(decimal: point.contributions).doubleValue), series: .value("Série", "Versements nets"))
                            .foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    if let selectedDate { RuleMark(x: .value("Sélection", selectedDate)).foregroundStyle(.secondary.opacity(0.5)) }
                }
                .chartXSelection(value: $selectedDate).chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 190).animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: period)
                .accessibilityLabel("Évolution des valorisations enregistrées et des versements nets")
                HStack(spacing: 16) {
                    Label("Patrimoine", systemImage: "minus").foregroundStyle(Palette.accent)
                    Label("Versements nets", systemImage: "minus").foregroundStyle(.secondary)
                }.font(.caption)
            }
        }
    }
}
