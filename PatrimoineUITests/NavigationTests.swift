import XCTest

final class NavigationTests: XCTestCase {
    private func launch(_ appearance: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-patrimoine-ui-test", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchEnvironment["PATRIMOINE_TEST_APPEARANCE"] = appearance
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
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Votre histoire commence ici"].exists)
        capture(app, "Accueil-sombre-etat-vide")
        for tab in ["Portefeuilles", "Analyses", "Revenus", "Plus", "Accueil"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }
    func testCreateAccountAndRecordDepositInLightMode() {
        let app = launch("light")
        XCTAssertTrue(app.buttons["Créer un portefeuille"].waitForExistence(timeout: 15))
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
}
