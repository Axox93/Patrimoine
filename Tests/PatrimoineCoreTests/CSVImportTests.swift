import XCTest
@testable import PatrimoineCore

final class CSVImportTests: XCTestCase {
    func testQuotedFieldsNewlinesAndBOM() throws {
        let table = try CSVTable("\u{feff}Name,Note\r\n\"A, B\",\"line 1\nline \"\"2\"\"\"\r\n")
        XCTAssertEqual(table.headers, ["Name","Note"])
        XCTAssertEqual(table.rows, [["A, B", "line 1\nline \"2\""]])
    }
    func testMalformedCSVRejected() {
        for csv in ["a,a\n1,2", "a,b\n1", "a,b\n\"unclosed", "a,b\n\"closed\"x,2", ""] {
            XCTAssertThrowsError(try CSVTable(csv))
        }
    }
    private func parse(_ action: String = "Market buy", total: String = "102", currency: String = "EUR", date: String = "2026-01-02 10:00:00", feeCurrency: String = "EUR", basis: ImportAmountBasis = .netCash) throws -> ImportedMovement {
        let table = try CSVTable("Action;Time;ID;Ticker;No. of shares;Total;Currency (Total);Commission;Currency (Commission)\n\(action);\(date);FAKE-1;TEST;2;\(total);\(currency);2;\(feeCurrency)\n")
        var mapping = CSVMapping(headers: table.headers); mapping.basis = basis
        let line = try XCTUnwrap(CSVImport.preview(table, mapping: mapping).first)
        if let issue = line.issue { throw ImportFailure(issue) }
        return try XCTUnwrap(line.movement)
    }
    func testNetPurchaseAndGrossPurchaseNotDoubleCharged() throws {
        let net = try parse()
        XCTAssertEqual(net.amount, 100); XCTAssertEqual(net.fees, 2)
        let gross = try parse(total: "100", basis: .gross)
        XCTAssertEqual(gross.amount, 100); XCTAssertEqual(gross.fees, 2)
    }
    func testNetSaleAndDividendReconstructGross() throws {
        XCTAssertEqual(try parse("Market sell", total: "98").amount, 100)
        XCTAssertEqual(try parse("Dividend (Ordinary)", total: "8").amount, 10)
    }
    func testInvalidDateCurrencyActionAndNumberRejected() {
        XCTAssertThrowsError(try parse(currency: "USD"))
        XCTAssertThrowsError(try parse(date: "2026-02-30 10:00:00"))
        XCTAssertThrowsError(try parse(date: "2099-01-01 10:00:00"))
        XCTAssertThrowsError(try parse("Currency conversion"))
        XCTAssertThrowsError(try parse(total: "1.000,00"))
        XCTAssertThrowsError(try parse(feeCurrency: "USD"))
    }
    func testMappingAndBrutNetConfirmationRequired() throws {
        let table = try CSVTable("Action;Time;Total;Currency\nDeposit;2026-01-02 10:00:00;10;EUR")
        XCTAssertThrowsError(try CSVImport.preview(table, mapping: CSVMapping(headers: table.headers)))
    }
    func testStableIdentityScopedToAccount() throws {
        let row = try parse()
        let account = UUID(), instrument = UUID()
        let first = row.ledgerEntry(accountID: account, instrumentID: instrument, sequence: 1)
        let second = row.ledgerEntry(accountID: account, instrumentID: instrument, sequence: 2)
        XCTAssertEqual(first.id, second.id)
        XCTAssertTrue(CSVImport.sameEconomics(first, second))
        XCTAssertNotEqual(first.id, row.ledgerEntry(accountID: UUID(), instrumentID: instrument, sequence: 1).id)
    }
    func testFrenchDecimalsAndTabSeparator() throws {
        let table = try CSVTable("Time\tAction\tTotal\tCurrency\n2026-01-02 10:00:00\tDeposit\t12,50\tEUR")
        var mapping = CSVMapping(headers: table.headers); mapping.basis = .gross
        let row = try XCTUnwrap(CSVImport.preview(table, mapping: mapping).first?.movement)
        XCTAssertEqual(row.amount, Decimal(string: "12.50"))
    }
}
