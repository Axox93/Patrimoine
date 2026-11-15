import XCTest
@testable import PatrimoineCore

final class CSVImportTests: XCTestCase {
    func testQuotedFieldsNewlinesAndBOM() throws {
        let table = try CSVTable("\u{feff}Name,Note\r\n\"A, B\",\"line 1\nline \"\"2\"\"\"\r\n")
        XCTAssertEqual(table.headers, ["Name","Note"])
        XCTAssertEqual(table.rows, [["A, B", "line 1\nline \"2\""]])
    }
    func testMalformedCSVRejected() {
        for csv in ["a,b\n1", "a,b\n\"unclosed", "a,b\n\"closed\"x,2", ""] {
            XCTAssertThrowsError(try CSVTable(csv))
        }
    }
    func testDegiroRepeatedAndUnnamedColumnsArePreserved() throws {
        let table = try CSVTable("Date;Valeur;;Valeur;\r\n02-01-2026;-100;USD;-90;EUR\r\n")
        XCTAssertEqual(table.headers.count, 5)
        XCTAssertEqual(Set(table.headers).count, 5)
        XCTAssertEqual(table.rows[0], ["02-01-2026","-100","USD","-90","EUR"])
    }
    func testHeaderDelimiterInsideQuotesDoesNotChangeDialect() throws {
        let table = try CSVTable("\"Name; description; label\",Amount\nTest,10")
        XCTAssertEqual(table.headers.count, 2)
    }
    func testTradeRepublicSignedAmountsExplicitActionAndStatus() throws {
        let table = try CSVTable("booking_date;booking_type;amount;currency;transaction_id;status\n2026-01-02T10:00:00Z;TRANSFER_IN;100;EUR;FAKE-TR-1;completed")
        var mapping = CSVMapping(headers: table.headers, broker: .tradeRepublic)
        mapping.basis = .netCash; mapping.signedAmounts = true
        mapping.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        XCTAssertNotNil(try CSVImport.preview(table, mapping: mapping)[0].issue)
        mapping.actionOverrides["TRANSFER_IN"] = .deposit
        let row = try XCTUnwrap(CSVImport.preview(table, mapping: mapping)[0].movement)
        XCTAssertEqual(row.amount, 100); XCTAssertEqual(row.broker, .tradeRepublic)
        let cancelled = try CSVTable("booking_date;booking_type;amount;currency;status\n2026-01-02T10:00:00Z;TRANSFER_IN;100;EUR;pending")
        var cancelledMap = CSVMapping(headers: cancelled.headers, broker: .tradeRepublic)
        cancelledMap.basis = .gross; cancelledMap.dateFormat = mapping.dateFormat; cancelledMap.actionOverrides = mapping.actionOverrides
        XCTAssertNotNil(try CSVImport.preview(cancelled, mapping: cancelledMap)[0].issue)
    }
    func testDegiroSignedQuantityAndSeparateTime() throws {
        let table = try CSVTable("Date;Heure;ISIN;Quantité;Montant;Devise;Frais;ID\n02-01-2026;10:00;FR0000000001;+2;-102;EUR;-2;FAKE-DG-1\n03-01-2026;11:00;FR0000000001;-1;+60;EUR;0;FAKE-DG-2")
        var mapping = CSVMapping(headers: table.headers, broker: .degiro)
        mapping.basis = .netCash; mapping.signedAmounts = true; mapping.inferTradesFromQuantity = true
        mapping.dateFormat = "dd-MM-yyyy HH:mm"
        let rows = try CSVImport.preview(table, mapping: mapping)
        let buy = try XCTUnwrap(rows[0].movement), sell = try XCTUnwrap(rows[1].movement)
        XCTAssertEqual(buy.kind, .buy); XCTAssertEqual(buy.amount, 100); XCTAssertEqual(buy.fees, 2)
        XCTAssertEqual(sell.kind, .sell); XCTAssertEqual(sell.quantity, 1)
        XCTAssertEqual(buy.broker, .degiro)
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
        var mapping = CSVMapping(headers: table.headers); mapping.basis = .gross; mapping.decimalSeparator = ","
        let row = try XCTUnwrap(CSVImport.preview(table, mapping: mapping).first?.movement)
        XCTAssertEqual(row.amount, Decimal(string: "12.50"))
    }
    func testDecimalConventionPreventsThousandsGuessing() throws {
        let table = try CSVTable("Time;Action;Total;Currency\n2026-01-02 10:00:00;Deposit;1,234;EUR")
        var mapping = CSVMapping(headers: table.headers); mapping.basis = .gross
        XCTAssertNotNil(try CSVImport.preview(table, mapping: mapping)[0].issue)
        mapping.decimalSeparator = ","
        XCTAssertEqual(try CSVImport.preview(table, mapping: mapping)[0].movement?.amount, Decimal(string: "1.234"))
    }
}
