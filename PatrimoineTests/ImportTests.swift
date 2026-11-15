import XCTest
import SwiftData
import PatrimoineCore
@testable import Patrimoine

@MainActor final class ImportTests: XCTestCase {
    private func rows(_ text: String) throws -> [ImportedMovement] {
        let table = try CSVTable("Time;Action;Total;Currency;ID\n" + text)
        var mapping = CSVMapping(headers: table.headers); mapping.basis = .gross
        return try CSVImport.preview(table, mapping: mapping).map {
            guard let row = $0.movement else { throw ImportFailure($0.issue ?? "Invalid fixture") }; return row
        }
    }
    private func fixture() throws -> (ModelContainer, Account) {
        let container = try StoreFactory.make(inMemory: true)
        let account = Account(name: "Compte fictif", institution: "Trading 212", kind: "Compte-titres")
        container.mainContext.insert(account); try container.mainContext.save()
        return (container, account)
    }
    func testImportAndRepeatedImportDoNotDuplicate() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let rows = try rows("2026-01-02 10:00:00;Deposit;100;EUR;FAKE-1")
        XCTAssertEqual(try ImportRepository.commit(rows, account: account, instruments: [:], allowSimilar: [], context: context), 1)
        let again = try ImportRepository.prepare(rows, account: account, instruments: [:], allowSimilar: [], context: context)
        XCTAssertTrue(again[0].duplicate)
        XCTAssertThrowsError(try ImportRepository.commit(rows, account: account, instruments: [:], allowSimilar: [], context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movement>()), 1)
    }
    func testAppendOverlappingHistory() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let first = "2026-01-02 10:00:00;Deposit;100;EUR;FAKE-1"
        _ = try ImportRepository.commit(rows(first), account: account, instruments: [:], allowSimilar: [], context: context)
        let history = try rows(first + "\n2026-01-03 10:00:00;Withdrawal;20;EUR;FAKE-2")
        XCTAssertEqual(try ImportRepository.commit(history, account: account, instruments: [:], allowSimilar: [], context: context), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movement>()), 2)
    }
    func testConflictCannotOverwriteHistory() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        _ = try ImportRepository.commit(rows("2026-01-02 10:00:00;Deposit;100;EUR;FAKE-1"), account: account, instruments: [:], allowSimilar: [], context: context)
        let changed = try rows("2026-01-02 10:00:00;Deposit;200;EUR;FAKE-1")
        XCTAssertThrowsError(try ImportRepository.commit(changed, account: account, instruments: [:], allowSimilar: [0], context: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Movement>()).first?.amountText, "100")
    }
    func testIncompleteHistoryIsAtomic() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let history = try rows("2026-01-02 10:00:00;Deposit;100;EUR;FAKE-1\n2026-01-03 10:00:00;Withdrawal;200;EUR;FAKE-2")
        XCTAssertThrowsError(try ImportRepository.commit(history, account: account, instruments: [:], allowSimilar: [], context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movement>()), 0)
    }
    func testSimilarWithoutIDNeedsExplicitOverride() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let rows = try rows("2026-01-02 10:00:00;Deposit;100;EUR;")
        _ = try ImportRepository.commit(rows, account: account, instruments: [:], allowSimilar: [], context: context)
        XCTAssertTrue(try ImportRepository.prepare(rows, account: account, instruments: [:], allowSimilar: [], context: context)[0].duplicate)
        XCTAssertEqual(try ImportRepository.commit(rows, account: account, instruments: [:], allowSimilar: [0], context: context), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movement>()), 2)
    }
    func testDistinctSourceIDsWithSameAmountsArePreserved() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let rows = try rows("2026-01-02 10:00:00;Deposit;100;EUR;FAKE-1\n2026-01-02 10:00:00;Deposit;100;EUR;FAKE-2")
        XCTAssertEqual(try ImportRepository.commit(rows, account: account, instruments: [:], allowSimilar: [], context: context), 2)
        XCTAssertTrue(try ImportRepository.prepare(rows, account: account, instruments: [:], allowSimilar: [], context: context).allSatisfy(\.duplicate))
    }
    func testImportedBuyDividendAndPartialSaleReconstructPosition() throws {
        let (container, account) = try fixture(); let context = container.mainContext
        let instrument = Instrument(name: "Action FICTIVE", symbol: "TEST", isin: "", exchange: "XPAR", kind: "Action", distribution: "Non renseigné")
        context.insert(instrument); try context.save()
        let table = try CSVTable("Time;Action;Total;Currency;Quantity;Ticker;Commission;ID\n2026-01-01 10:00:00;Deposit;1000;EUR;0;;0;FAKE-1\n2026-01-02 10:00:00;Market buy;102;EUR;2;TEST;2;FAKE-2\n2026-01-03 10:00:00;Dividend;8;EUR;0;TEST;2;FAKE-3\n2026-01-04 10:00:00;Market sell;58;EUR;1;TEST;2;FAKE-4")
        var mapping = CSVMapping(headers: table.headers); mapping.basis = .netCash
        let rows = try CSVImport.preview(table, mapping: mapping).map { try XCTUnwrap($0.movement, $0.issue ?? "") }
        XCTAssertEqual(try ImportRepository.commit(rows, account: account, instruments: ["TEST":instrument.id], allowSimilar: [], context: context), 4)
        let entries = try context.fetch(FetchDescriptor<Movement>()).map { try $0.entry() }
        let result = try LedgerEngine.replay(entries, currency: "EUR")
        XCTAssertEqual(result.cash, 964)
        XCTAssertEqual(result.holdings[instrument.id]?.quantity, 1)
        XCTAssertEqual(result.holdings[instrument.id]?.cost, 51)
        XCTAssertEqual(result.realizedGain, 7)
        XCTAssertEqual(result.dividends, 8)
        XCTAssertEqual(result.valuation(prices: [instrument.id:70]), 1034)
    }
}
