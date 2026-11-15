import SwiftUI
import SwiftData

@main struct PatrimoineApp: App {
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    @State private var container: ModelContainer?
    @State private var storageIssue = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                if let container {
                    RootView().modelContainer(container).environment(lock)
                } else if storageIssue {
                    VStack(spacing: 24) {
                        EmptyStateView(title: "Données temporairement indisponibles",
                            message: "Le stockage n’a pas pu être ouvert. Aucune donnée n’a été effacée. Déverrouillez l’iPhone puis réessayez.", symbol: "lock.shield")
                        Button("Réessayer", action: loadStore).buttonStyle(PrimaryButtonStyle())
                    }.padding(24)
                } else {
                    ProgressView("Ouverture du coffre local…")
                }
                }
                .accessibilityHidden(scenePhase != .active || (lock.enabled && !lock.unlocked))
                .allowsHitTesting(scenePhase == .active && (!lock.enabled || lock.unlocked))
                if scenePhase != .active {
                    PrivacyCover()
                } else if lock.enabled && !lock.unlocked {
                    LockScreen().environment(lock)
                }
            }
            .tint(Palette.accent)
            .preferredColorScheme(testColorScheme)
            .task(id: scenePhase) {
                if scenePhase == .active && container == nil && !storageIssue { loadStore() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { lock.lock() }
            }
        }
    }
    @MainActor private func loadStore() {
        #if DEBUG
        let inMemory = ProcessInfo.processInfo.arguments.contains("-patrimoine-ui-test")
        #else
        let inMemory = false
        #endif
        do { container = try StoreFactory.make(inMemory: inMemory); storageIssue = false }
        catch { storageIssue = true }
    }
    private var testColorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-patrimoine-ui-test") {
            return ProcessInfo.processInfo.environment["PATRIMOINE_TEST_APPEARANCE"] == "dark" ? .dark : .light
        }
        #endif
        return nil
    }
}

struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "square.stack.3d.up.fill").font(.largeTitle).foregroundStyle(Palette.accent)
                Text("PATRIMOINE").font(.caption.weight(.bold)).tracking(4)
            }
        }
    }
}

struct LockScreen: View {
    @Environment(AppLock.self) private var lock
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 24) {
                EmptyStateView(title: "Votre patrimoine, à l’abri",
                    message: "Authentifiez-vous pour consulter vos comptes.", symbol: "lock.shield")
                Button { Task { await lock.authenticate() } } label: {
                    Label("Déverrouiller", systemImage: "faceid").frame(minHeight: 44)
                }.buttonStyle(PrimaryButtonStyle()).disabled(lock.authenticating)
                if let message = lock.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }.padding(24)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }.tabItem { Label("Accueil", systemImage: "square.grid.2x2") }
            NavigationStack { AccountsView() }.tabItem { Label("Portefeuilles", systemImage: "wallet.pass") }
            NavigationStack { AnalysisView() }.tabItem { Label("Analyses", systemImage: "chart.pie") }
            NavigationStack { IncomeView() }.tabItem { Label("Revenus", systemImage: "calendar") }
            NavigationStack { MoreView() }.tabItem { Label("Plus", systemImage: "ellipsis") }
        }
    }
}
