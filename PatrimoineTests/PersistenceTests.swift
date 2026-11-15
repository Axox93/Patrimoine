import XCTest
import SwiftData
import PatrimoineCore
@testable import Patrimoine

@MainActor final class PersistenceTests: XCTestCase {
    func testCreateModifyArchiveTrashAndRestore() throws {
        let container = try StoreFactory.make(inMemory: true)
        let context = container.mainContext
        try AccountRepository.create(name: "PEA test fictif", institution: "Établissement fictif", kind: .pea, context: context)
        let account = try XCTUnwrap(context.fetch(FetchDescriptor<Account>()).first)
        XCTAssertEqual(account.currency, "EUR")
        account.name = "PEA modifié"; account.archived = true
        try AccountRepository.save(context)
        account.deletedAt = .now
        try AccountRepository.save(context)
        XCTAssertEqual(ValuationService.summaries(accounts: [account], movements: [], prices: []).count, 0)
        account.deletedAt = nil
        try AccountRepository.save(context)
        XCTAssertEqual(ValuationService.summaries(accounts: [account], movements: [], prices: []).count, 1)
        XCTAssertTrue(account.archived)
    }
    func testTransactionSurvivesReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let url = folder.appending(path: "Test.store")
        defer { try? FileManager.default.removeItem(at: folder) }
        var first: ModelContainer? = try StoreFactory.make(at: url)
        try AccountRepository.create(name: "CTO test", institution: "Fictif", kind: .cto, context: first!.mainContext)
        var account: Account? = try first!.mainContext.fetch(FetchDescriptor<Account>()).first
        try AccountRepository.append(LedgerEntry(date: .now, sequence: 0, kind: .deposit, amount: 123, currency: "EUR"),
                                     to: account!, context: first!.mainContext)
        let id = account!.id
        account = nil; first = nil
        let second = try StoreFactory.make(at: url)
        let restored = try second.mainContext.fetch(FetchDescriptor<Account>())
        let movements = try second.mainContext.fetch(FetchDescriptor<Movement>())
        XCTAssertEqual(restored.first?.id, id)
        XCTAssertEqual(movements.count, 1)
        XCTAssertEqual(ValuationService.summaries(accounts: restored, movements: movements, prices: []).first?.value, 123)
    }
    func testRejectedPurchaseDoesNotPersist() throws {
        let container = try StoreFactory.make(inMemory: true)
        let context = container.mainContext
        let account = Account(name: "Test", institution: "Fictif", kind: "PEA")
        let instrument = Instrument(name: "Action fictive", symbol: "TEST", isin: "", exchange: "XPAR", kind: "Action", distribution: "Non renseigné")
        context.insert(account); context.insert(instrument); try context.save()
        XCTAssertThrowsError(try AccountRepository.append(LedgerEntry(date: .now, sequence: 0, kind: .buy,
            instrumentID: instrument.id, quantity: 1, amount: 100, currency: "EUR"), to: account, context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movement>()), 0)
    }
    func testLatestObservedQuoteAndIncompleteTotal() throws {
        let account = Account(name: "Test", institution: "Fictif", kind: "PEA")
        let id = UUID()
        let movements = [
            Movement(accountID: account.id, entry: LedgerEntry(date: Date(timeIntervalSince1970: 0), sequence: 0, kind: .deposit, amount: 100, currency: "EUR")),
            Movement(accountID: account.id, entry: LedgerEntry(date: Date(timeIntervalSince1970: 1), sequence: 1, kind: .buy, instrumentID: id, quantity: 2, amount: 100, currency: "EUR"))
        ]
        XCTAssertNil(ValuationService.total(ValuationService.summaries(accounts: [account], movements: movements, prices: [])))
        let prices = [Price(instrumentID: id, value: 70, date: Date(timeIntervalSince1970: 3)),
                      Price(instrumentID: id, value: 60, date: Date(timeIntervalSince1970: 2))]
        XCTAssertEqual(ValuationService.total(ValuationService.summaries(accounts: [account], movements: movements, prices: prices)), 140)
    }
    func testCapitalizingETFDividendRejected() throws {
        let container = try StoreFactory.make(inMemory: true)
        let context = container.mainContext
        let account = Account(name: "PEA", institution: "Fictif", kind: "PEA")
        let instrument = Instrument(name: "ETF fictif", symbol: "ACC", isin: "", exchange: "XPAR", kind: "ETF", distribution: "Capitalisant")
        context.insert(account); context.insert(instrument); try context.save()
        XCTAssertThrowsError(try AccountRepository.append(LedgerEntry(date: .now, sequence: 0, kind: .dividend,
            instrumentID: instrument.id, amount: 5, currency: "EUR"), to: account, context: context))
    }
    func testCorruptMonetaryDataNotSilentlyZeroed() throws {
        let account = Account(name: "PEA", institution: "Fictif", kind: "PEA")
        let movement = Movement(accountID: account.id, entry: LedgerEntry(date: .now, sequence: 0, kind: .deposit, amount: 10, currency: "EUR"))
        movement.amountText = "invalid"
        let summary = ValuationService.summaries(accounts: [account], movements: [movement], prices: []).first!
        XCTAssertNil(summary.value)
        XCTAssertNotNil(summary.issue)
    }
}
