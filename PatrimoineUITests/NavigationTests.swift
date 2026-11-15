import XCTest

final class NavigationTests: XCTestCase {
    private func launch(_ appearance: String, csv: String? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-patrimoine-ui-test", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchEnvironment["PATRIMOINE_TEST_APPEARANCE"] = appearance
        if let csv { app.launchEnvironment["PATRIMOINE_TEST_CSV"] = csv }
        // Unit tests use the app as their host. Start a fresh process with the UI-test arguments.
        app.terminate()
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testEmptyDashboardInDarkMode() {
        let app = launch("dark")
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.staticTexts["Votre histoire commence ici"].exists)
        capture(app, "Accueil-sombre-etat-vide")
        for tab in ["Portefeuilles", "Analyses", "Revenus", "Plus", "Accueil"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }
    func testCreateAccountAndRecordDepositInLightMode() {
        let app = launch("light")
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 45))
        app.buttons["Créer un portefeuille"].tap()
        let name = app.textFields["Nom du portefeuille"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("PEA de test")
        let institution = app.textFields["Établissement"]
        institution.tap(); institution.typeText("Établissement fictif")
        app.navigationBars.buttons["Enregistrer"].tap()
        let account = app.staticTexts["PEA de test"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        app.buttons["Enregistrer une opération"].tap()
        let amount = app.textFields["Montant brut total en EUR"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("1000")
        app.navigationBars.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Versement"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["Opération refusée"].exists)
        capture(app, "PEA-clair-versement-fictif")
    }
    func testImportEntryPoint() {
        let app = launch("dark")
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 45))
        app.tabBars.buttons["Plus"].tap()
        app.buttons["Importer un compte"].tap()
        XCTAssertTrue(app.buttons["Choisir un CSV ou PDF"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Trading 212 · import manuel"].exists)
        capture(app, "Import-Trading212")
    }
    func testImportReviewCommitAndDuplicateReimport() {
        executionTimeAllowance = 180
        let csv = "Time;Action;Total;Currency;ID\n2026-01-01 10:00:00;Deposit;100;EUR;FAKE-UI-1\n2026-01-02 10:00:00;Withdrawal;20;EUR;FAKE-UI-2"
        let app = launch("light", csv: csv)
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 45))
        app.buttons["Créer un portefeuille"].tap()
        app.textFields["Nom du portefeuille"].tap(); app.textFields["Nom du portefeuille"].typeText("Import fictif")
        app.textFields["Établissement"].tap(); app.textFields["Établissement"].typeText("Trading 212")
        app.navigationBars.buttons["Enregistrer"].tap()
        app.tabBars.buttons["Plus"].tap()
        app.buttons["Importer un compte"].tap()
        func reveal(_ element: XCUIElement) {
            for _ in 0..<12 {
                if element.exists && element.isHittable { return }
                app.swipeUp()
            }
            XCTAssertTrue(element.exists)
        }
        func tap(_ title: String) { let button = app.buttons[title]; reveal(button); button.tap() }
        let portfolioPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Portefeuille de destination")).firstMatch
        XCTAssertTrue(portfolioPicker.waitForExistence(timeout: 10)); portfolioPicker.tap()
        app.buttons["Import fictif · Trading 212"].tap()
        tap("Lire les colonnes")
        let basisPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sens du montant")).firstMatch
        reveal(basisPicker); basisPicker.tap(); app.buttons["Montant brut"].tap()
        let zone = app.textFields["Fuseau des dates sans décalage"]
        reveal(zone); zone.tap(); zone.typeText("UTC")
        let reviewed = app.switches["J’ai vérifié le brut/net, le fuseau des dates et toutes les colonnes de frais dans la devise du compte"]
        reveal(reviewed); reviewed.tap()
        tap("Prévisualiser les opérations")
        tap("Vérifier les doublons et les soldes")
        tap("Confirmer l’importation")
        app.buttons["Importer les nouvelles opérations"].tap()
        let success = app.staticTexts["2 opérations importées dans Import fictif."]
        reveal(success); XCTAssertTrue(success.exists)
        capture(app, "Import-CSV-confirme")
        // The same source is still in the editor. Re-preview and reconcile it against the ledger.
        for _ in 0..<8 { app.swipeDown() }
        tap("Prévisualiser les opérations")
        tap("Vérifier les doublons et les soldes")
        let summary = app.staticTexts["0 nouvelles opérations · 2 correspondances exclues."]
        reveal(summary); XCTAssertTrue(summary.exists)
        XCTAssertFalse(app.buttons["Confirmer l’importation"].isEnabled)
        capture(app, "Import-CSV-doublons-exclus")
    }
}
