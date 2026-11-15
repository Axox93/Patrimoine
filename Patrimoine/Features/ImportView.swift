import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PatrimoineCore

struct ImportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Instrument.name) private var instruments: [Instrument]
    @State private var accountID: UUID?
    @State private var broker: ImportBroker = .trading212
    @State private var chooseFile = false
    @State private var source = ""
    @State private var pdfText = ""
    @State private var filename = ""
    @State private var table: CSVTable?
    @State private var mapping = CSVMapping(headers: [])
    @State private var lines: [ImportLine] = []
    @State private var excluded: Set<Int> = []
    @State private var links: [String: UUID] = [:]
    @State private var includeSimilar: Set<Int> = []
    @State private var prepared: [PreparedImport] = []
    @State private var showInstrument = false
    @State private var confirm = false
    @State private var error: ErrorMessage?
    @State private var success: String?
    @State private var busy = false
    @State private var feesConfirmed = false
    @State private var balanceValidated = false
    @AppStorage("privacy.hideAmounts") private var hideAmounts = false
    private var activeAccounts: [Account] { accounts.filter { !$0.archived && $0.deletedAt == nil } }
    private var account: Account? { activeAccounts.first { $0.id == accountID } }
    private var selected: [ImportedMovement] { lines.filter { !excluded.contains($0.id) }.compactMap(\.movement) }
    private var instrumentKeys: [String] { Array(Set(selected.filter { $0.kind.needsInstrument }.map(\.instrumentKey))).sorted() }

    var body: some View {
        Form {
            Section {
                Text(broker.rawValue + " · import manuel").font(.headline)
                Picker("Établissement du fichier", selection: $broker) { ForEach(ImportBroker.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Text(broker.guidance).font(.footnote).foregroundStyle(.secondary)
                Text("Exportez l’historique complet : ordres, versements, retraits, dividendes et intérêts. Chaque nouvel import met à jour le portefeuille après votre validation. Le fichier reste sur l’iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Consulter l’aide officielle de " + broker.rawValue, destination: broker.helpURL)
                Picker("Portefeuille de destination", selection: $accountID) {
                    Text("Choisir un portefeuille").tag(UUID?.none)
                    ForEach(activeAccounts) { Text($0.name + " · " + $0.institution).tag(Optional($0.id)) }
                }
                if activeAccounts.isEmpty { Text("Créez d’abord le compte dans Portefeuilles.").foregroundStyle(.secondary) }
                Button("Choisir un CSV ou PDF", systemImage: "doc.badge.plus") { chooseFile = true }.disabled(busy)
                if source.isEmpty { Button("Coller un tableau CSV") { source = "Time;Action;Total;Currency;Quantity;Ticker;ISIN;Fees;ID\n" } }
                if !filename.isEmpty { Text(filename).font(.caption).foregroundStyle(.secondary) }
                if busy { ProgressView("Lecture locale du document…") }
            }
            if !pdfText.isEmpty {
                Section("PDF : transcription assistée") {
                    Text("Le texte a été extrait localement. Aucune opération n’est déduite automatiquement d’un relevé PDF non validé. Recopiez les opérations utiles dans le tableau CSV ci-dessous, puis vérifiez les montants avant import.")
                        .font(.footnote)
                    TextEditor(text: .constant(pdfText)).frame(minHeight: 180).font(.caption).accessibilityLabel("Texte extrait du PDF")
                }
            }
            if !source.isEmpty || !pdfText.isEmpty {
                Section("Contenu CSV à vérifier ou corriger") {
                    TextEditor(text: $source).frame(minHeight: 150).font(.system(.caption, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("import.csv.source")
                    Button("Lire les colonnes", action: readColumns)
                    Text("CSV UTF-8 ou UTF-16 avec BOM, séparateur virgule, point-virgule ou tabulation. Aucun séparateur de milliers. Les sorties négatives sont acceptées seulement en mode montants signés.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let table {
                mappingSection(table)
            }
            if !lines.isEmpty {
                if !instrumentKeys.isEmpty {
                    Section("Associer les instruments") {
                        ForEach(instrumentKeys, id: \.self) { key in
                            Picker(key, selection: Binding(get: { links[key] }, set: { links[key] = $0; prepared = [] })) {
                                Text("Choisir").tag(UUID?.none)
                                ForEach(instruments) { Text($0.name + " · " + $0.exchange + " · " + $0.currency).tag(Optional($0.id)) }
                            }
                        }
                        Button("Créer un instrument", systemImage: "plus") { showInstrument = true }
                        Text("Vérifiez la place de cotation et l’ISIN. Aucun ticker ambigu n’est associé automatiquement.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Prévisualisation · \(lines.count) lignes") {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: Binding(get: { !excluded.contains(line.id) }, set: { include in
                                if include { excluded.remove(line.id) } else { excluded.insert(line.id) }
                                prepared = []
                            })) {
                                if let row = line.movement {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(row.kind.label) · \(row.instrumentKey)").font(.subheadline.weight(.semibold))
                                        Text(row.date, format: .dateTime.day().month().year().hour().minute()).font(.caption)
                                        HStack { MoneyText(value: row.amount); Text("brut · frais").font(.caption); MoneyText(value: row.fees) }
                                        MetricRow(title: "Mouvement de liquidités", value: row.cashMovement)
                                        if row.quantity > 0 { Text("Quantité : \(row.quantity.formatted())").font(.caption) }
                                        if !row.quoteCurrency.isEmpty { Text("Devise de cotation : " + row.quoteCurrency).font(.caption).foregroundStyle(.secondary) }
                                    }
                                } else { Text("Ligne \(line.id + 2) : \(line.issue ?? "invalide")").font(.footnote).foregroundStyle(.orange) }
                            }
                            if let status = prepared.first(where: { $0.id == line.id }) {
                                if status.conflict { InlineIssue(message: "Identifiant déjà présent avec des données différentes : import bloqué.") }
                                else if status.duplicate { InlineIssue(message: "Doublon ou correspondance possible : cette ligne sera exclue.") }
                            }
                            if prepared.contains(where: { $0.id == line.id && $0.duplicate && !$0.conflict }) || includeSimilar.contains(line.id) {
                                Toggle("C’est une opération distincte : l’ajouter aussi", isOn: Binding(get: { includeSimilar.contains(line.id) }, set: {
                                    if $0 { includeSimilar.insert(line.id) } else { includeSimilar.remove(line.id) }
                                    prepared = []
                                })).font(.caption)
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    Button("Vérifier les doublons et les soldes", action: reconcile)
                    if !prepared.isEmpty {
                        Text("\(prepared.filter { !$0.duplicate && !$0.conflict }.count) nouvelles opérations · \(prepared.filter(\.duplicate).count) correspondances exclues.").font(.subheadline)
                        Button("Confirmer l’importation", systemImage: "checkmark.circle") { confirm = true }
                            .disabled(!balanceValidated || prepared.contains(where: \.conflict) || prepared.allSatisfy(\.duplicate))
                    }
                } footer: { Text("Un historique incomplet peut provoquer un solde négatif ou une vente supérieure aux titres détenus. Complétez l’historique ou saisissez les opérations antérieures ; aucun versement fictif n’est créé.") }
            }
            if let success { Section { Label(success, systemImage: "checkmark.circle.fill").foregroundStyle(Palette.positive) } }
        }
        .navigationTitle("Importer un compte").navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
        .scrollDismissesKeyboard(.immediately)
        .accessibilityHidden(hideAmounts)
        .allowsHitTesting(!hideAmounts)
        .overlay {
            if hideAmounts {
                ZStack {
                    Palette.background.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Le fichier contient vos montants et vos opérations.").multilineTextAlignment(.center)
                        Button("Afficher pour vérifier l’import") { hideAmounts = false }.buttonStyle(PrimaryButtonStyle())
                    }.padding(24)
                }
            }
        }
        .fileImporter(isPresented: $chooseFile, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { load(url) }
            case .failure(let error): self.error = ErrorMessage(error)
            }
        }
        .sheet(isPresented: $showInstrument) { InstrumentForm() }
        .confirmationDialog("Importer \(broker.rawValue) dans \(account?.name ?? "le portefeuille") ?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Importer les nouvelles opérations", action: commit)
        } message: { Text("Les opérations et les frais affichés seront enregistrés ensemble. L’historique existant sera conservé.") }
        .alert(item: $error) { Alert(title: Text("Import non effectué"), message: Text($0.text)) }
        .onChange(of: accountID) { _, _ in prepared = []; success = nil }
        .onChange(of: broker) { _, newBroker in
            if let table { mapping = CSVMapping(headers: table.headers, broker: newBroker); mapping.timeZoneID = "" }
            feesConfirmed = false; links = [:]; invalidate()
        }
        .onChange(of: source) { _, _ in table = nil; lines = []; prepared = []; success = nil }
        .task {
            #if DEBUG
            if source.isEmpty, ProcessInfo.processInfo.arguments.contains("-patrimoine-ui-test"),
               let fixture = ProcessInfo.processInfo.environment["PATRIMOINE_TEST_CSV"] {
                source = fixture; filename = "Jeu fictif de test d’interface"
            }
            #endif
        }
    }

    @ViewBuilder private func mappingSection(_ table: CSVTable) -> some View {
        Section("Vérifier les colonnes") {
            column("Date", binding: $mapping.date, table: table)
            column("Heure séparée (facultative)", binding: $mapping.time, table: table)
            column("Type d’opération", binding: $mapping.kind, table: table)
            column("Montant total", binding: $mapping.amount, table: table)
            column("Devise du montant", binding: $mapping.currency, table: table)
            column("Devise de cotation (si disponible)", binding: $mapping.quoteCurrency, table: table)
            column("Quantité", binding: $mapping.quantity, table: table)
            column("Ticker", binding: $mapping.symbol, table: table)
            column("ISIN", binding: $mapping.isin, table: table)
            column("Identifiant de transaction", binding: $mapping.externalID, table: table)
            column("Statut (si disponible)", binding: $mapping.status, table: table)
            if mapping.currency < 0 {
                Picker("Devise de la colonne montant", selection: $mapping.fixedCurrency) {
                    Text("À confirmer").tag(""); Text("EUR : montants déjà en euros").tag("EUR")
                }
            }
            Toggle("Montants signés : sorties négatives, entrées positives", isOn: $mapping.signedAmounts).font(.footnote)
            if broker == .degiro {
                Toggle("Relevé Transactions : quantité positive = achat, négative = vente", isOn: $mapping.inferTradesFromQuantity).font(.footnote)
            }
            if !mapping.inferTradesFromQuantity && table.headers.indices.contains(mapping.kind) {
                DisclosureGroup("Vérifier les libellés d’opérations") {
                    let actions = Array(Set(table.rows.map { $0[mapping.kind].trimmingCharacters(in: .whitespacesAndNewlines) })).sorted()
                    ForEach(Array(actions.prefix(100)), id: \.self) { action in
                        Picker(action.isEmpty ? "Libellé vide" : action, selection: Binding(get: { mapping.actionOverrides[action] }, set: { mapping.actionOverrides[action] = $0 })) {
                            Text("Reconnaissance stricte du libellé").tag(MovementKind?.none)
                            ForEach(MovementKind.allCases.filter { $0 != .split }, id: \.self) { Text($0.label).tag(Optional($0)) }
                        }
                    }
                    if actions.count > 100 { Text("Plus de 100 libellés distincts : normalisez la colonne Type dans le CSV avant de continuer.").font(.caption) }
                }
            }
            Picker("Sens du montant", selection: $mapping.basis) { ForEach(ImportAmountBasis.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Séparateur décimal", selection: $mapping.decimalSeparator) {
                Text("Point : 1234.56").tag("."); Text("Virgule : 1234,56").tag(",")
            }
            Picker("Format de date", selection: $mapping.dateFormat) {
                ForEach(["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "dd/MM/yyyy", "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm", "dd-MM-yyyy", "dd-MM-yyyy HH:mm", "yyyy-MM-dd'T'HH:mm:ssXXXXX"], id: \.self) { Text($0).tag($0) }
            }
            TextField("Fuseau des dates sans décalage", text: $mapping.timeZoneID).textInputAutocapitalization(.never).autocorrectionDisabled()
            Text(mapping.fees.isEmpty ? "Aucune colonne de frais sélectionnée : vérifiez le fichier." : "Frais sélectionnés : " + mapping.fees.sorted().map { table.headers[$0] }.joined(separator: ", "))
                .font(.footnote).foregroundStyle(.secondary)
            DisclosureGroup("Choisir les colonnes de frais et retenues") {
                ForEach(table.headers.indices, id: \.self) { index in
                    Toggle("Frais / retenue : \(table.headers[index])", isOn: Binding(get: { mapping.fees.contains(index) }, set: {
                        if $0 { mapping.fees.insert(index) } else { mapping.fees.remove(index) }
                    })).font(.caption)
                }
            }
            Toggle("J’ai vérifié le brut/net, le fuseau des dates et toutes les colonnes de frais dans la devise du compte", isOn: $feesConfirmed).font(.footnote)
            Button("Prévisualiser les opérations", action: preview).disabled(!feesConfirmed)
        }
        .onChange(of: mapping) { old, new in
            if old.isin != new.isin || old.symbol != new.symbol { links = [:] }
            feesConfirmed = false; invalidate()
        }
        .onChange(of: feesConfirmed) { _, value in if !value { invalidate() } }
    }
    private func column(_ title: String, binding: Binding<Int>, table: CSVTable) -> some View {
        Picker(title, selection: binding) {
            Text("Non renseignée").tag(-1)
            ForEach(table.headers.indices, id: \.self) { Text(table.headers[$0]).tag($0) }
        }
    }
    private func invalidate() { lines = []; prepared = []; success = nil }
    private func readColumns() {
        let text = source
        busy = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try CSVTable(text) }.value
                table = result; mapping = CSVMapping(headers: result.headers, broker: broker); mapping.timeZoneID = ""
                feesConfirmed = false; invalidate()
            } catch { self.error = ErrorMessage(error) }
            busy = false
        }
    }
    private func preview() {
        guard let table, feesConfirmed else { return }
        let configuration = mapping
        busy = true
        Task {
            do {
                lines = try await Task.detached(priority: .userInitiated) { try CSVImport.preview(table, mapping: configuration) }.value
                excluded = []; includeSimilar = []; prepared = []; success = nil
            } catch { self.error = ErrorMessage(error) }
            busy = false
        }
    }
    private func validRows() throws -> (Account, [ImportedMovement]) {
        guard let account else { throw ImportFailure("Choisissez un portefeuille de destination.") }
        guard !lines.contains(where: { !excluded.contains($0.id) && $0.issue != nil }) else { throw ImportFailure("Corrigez les lignes invalides dans le CSV ou excluez-les explicitement.") }
        guard !selected.isEmpty else { throw ImportFailure("Aucune opération sélectionnée.") }
        return (account, selected)
    }
    private func reconcile() {
        balanceValidated = false
        do {
            let (account, rows) = try validRows()
            prepared = try ImportRepository.prepare(rows, account: account, instruments: links, allowSimilar: includeSimilar, context: context)
            if prepared.contains(where: \.conflict) { return }
            let stored = try context.fetch(FetchDescriptor<Movement>()).filter { $0.accountID == account.id }.map { try $0.entry() }
            _ = try LedgerEngine.replay(stored + prepared.filter { !$0.duplicate }.map(\.entry), currency: account.currency)
            balanceValidated = true
        } catch { self.error = ErrorMessage(error) }
    }
    private func commit() {
        do {
            let (account, rows) = try validRows()
            let count = try ImportRepository.commit(rows, account: account, instruments: links, allowSimilar: includeSimilar, context: context)
            success = "\(count) opérations importées dans \(account.name)."
            lines = []; prepared = []; includeSimilar = []
        } catch { prepared = []; self.error = ErrorMessage(error) }
    }
    private func load(_ url: URL) {
        busy = true; error = nil; success = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) { try ImportDocumentReader.read(url) }.value
                filename = url.lastPathComponent; pdfText = result.pdfText
                source = result.csv.isEmpty ? "Date;Type;Montant;Devise;Quantité;Ticker;ISIN;Frais;ID\n" : result.csv
                table = nil; lines = []; prepared = []; links = [:]; excluded = []; includeSimilar = []
            } catch { self.error = ErrorMessage(error) }
            busy = false
        }
    }
}
