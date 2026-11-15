import XCTest
@testable import PatrimoineCore

final class LedgerTests: XCTestCase {
    private let instrument = UUID()
    private func entry(_ kind: MovementKind, _ amount: Decimal, quantity: Decimal = 0,
                       fees: Decimal = 0, order: Int = 0, currency: String = "EUR") -> LedgerEntry {
        LedgerEntry(date: Date(timeIntervalSince1970: Double(order)), sequence: order, kind: kind,
                    instrumentID: kind.needsInstrument ? instrument : nil,
                    quantity: quantity, amount: amount, fees: fees, currency: currency)
    }
    func testWeightedAverageAndPartialSale() throws {
        let result = try LedgerEngine.replay([
            entry(.deposit, 1000), entry(.buy, 100, quantity: 2, fees: 2, order: 1),
            entry(.buy, 200, quantity: 2, fees: 2, order: 2),
            entry(.sell, 120, quantity: 1, fees: 1, order: 3)
        ], currency: "EUR")
        XCTAssertEqual(result.holdings[instrument]?.quantity, 3)
        XCTAssertEqual(result.holdings[instrument]?.cost, 228)
        XCTAssertEqual(result.realizedGain, 43)
        XCTAssertEqual(result.cash, 815)
        XCTAssertEqual(result.valuation(prices: [instrument: 100]), 1115)
        XCTAssertEqual(result.unrealizedGain(prices: [instrument: 100]), 72)
    }
    func testFractionalPurchaseAndFullSale() throws {
        let result = try LedgerEngine.replay([
            entry(.deposit, 100), entry(.buy, 50, quantity: Decimal(string: "0.125")!, order: 1),
            entry(.sell, 60, quantity: Decimal(string: "0.125")!, fees: 1, order: 2)
        ], currency: "EUR")
        XCTAssertEqual(result.holdings[instrument]?.cost, 0)
        XCTAssertEqual(result.cash, 109)
        XCTAssertEqual(result.realizedGain, 9)
        XCTAssertEqual(result.valuation(prices: [:]), 109)
    }
    func testIncomeAndReinvestment() throws {
        let result = try LedgerEngine.replay([
            entry(.dividend, 10, fees: 3), entry(.buy, 7, quantity: 1, order: 1)
        ], currency: "EUR")
        XCTAssertEqual(result.dividends, 7)
        XCTAssertEqual(result.cash, 0)
        XCTAssertEqual(result.netContributions, 0)
        XCTAssertEqual(result.holdings[instrument]?.cost, 7)
    }
    func testSplitPreservesCost() throws {
        let result = try LedgerEngine.replay([
            entry(.deposit, 100), entry(.buy, 100, quantity: 2, order: 1),
            entry(.split, 0, quantity: 4, order: 2)
        ], currency: "EUR")
        XCTAssertEqual(result.holdings[instrument]?.quantity, 8)
        XCTAssertEqual(result.holdings[instrument]?.averageCost, Decimal(string: "12.5"))
    }
    func testMissingQuoteDoesNotInventValue() throws {
        let result = try LedgerEngine.replay([
            entry(.deposit, 100), entry(.buy, 100, quantity: 1, order: 1)
        ], currency: "EUR")
        XCTAssertNil(result.valuation(prices: [:]))
    }
    func testContributionIsNotInvestmentGain() throws {
        let result = try LedgerEngine.replay([entry(.deposit, 100), entry(.deposit, 50, order: 1)], currency: "EUR")
        XCTAssertEqual(result.valuation(prices: [:])! - result.netContributions, 0)
    }
    func testRejectsOversellAndOverdraft() {
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.sell, 10, quantity: 1)], currency: "EUR"))
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.buy, 10, quantity: 1)], currency: "EUR"))
    }
    func testRejectsDuplicateAndCurrencyMismatch() {
        let deposit = entry(.deposit, 100)
        XCTAssertThrowsError(try LedgerEngine.replay([deposit, deposit], currency: "EUR"))
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.deposit, 10, currency: "USD")], currency: "EUR"))
    }
    func testChronologicalReplay() throws {
        let result = try LedgerEngine.replay([
            entry(.buy, 10, quantity: 1, order: 1), entry(.deposit, 10)
        ], currency: "EUR")
        XCTAssertEqual(result.cash, 0)
    }
    func testNegativeNaNAndUnknownOrderRejected() {
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.deposit, -1)], currency: "EUR"))
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.deposit, .nan)], currency: "EUR"))
        XCTAssertThrowsError(try LedgerEngine.replay([entry(.deposit, 1), entry(.deposit, 2)], currency: "EUR"))
    }
    func testStrictDecimalInput() {
        XCTAssertEqual(DecimalInput.parse("12,34"), Decimal(string: "12.34"))
        XCTAssertEqual(DecimalInput.parse(" 0.125 "), Decimal(string: "0.125"))
        for text in ["1,234.56", "1e3", "-1", "12abc", "1 000", "", "NaN", "1.2.3"] {
            XCTAssertNil(DecimalInput.parse(text), text)
        }
    }
}
