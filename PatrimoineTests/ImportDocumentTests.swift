import XCTest
import UIKit
@testable import Patrimoine

@MainActor final class ImportDocumentTests: XCTestCase {
    func testCSVReadFromActualLocalFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".csv")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = "Date;Type;Montant;Devise\n2026-01-02;Versement;100;EUR"
        try Data(text.utf8).write(to: url)
        let result = try ImportDocumentReader.read(url)
        XCTAssertEqual(result.csv, text); XCTAssertEqual(result.pdfText, "")
    }
    func testPDFTextExtractionUsesNativeDocument() throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { context in
            context.beginPage()
            ("Releve FICTIF 123.45 EUR" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let result = try ImportDocumentReader.decode(data, isPDF: true)
        XCTAssertTrue(result.pdfText.contains("FICTIF")); XCTAssertEqual(result.csv, "")
    }
    func testBlankOrInvalidPDFRejected() throws {
        let blank = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300)).pdfData { $0.beginPage() }
        XCTAssertThrowsError(try ImportDocumentReader.decode(blank, isPDF: true))
        XCTAssertThrowsError(try ImportDocumentReader.decode(Data("not a PDF".utf8), isPDF: true))
    }
    func testOversizedDocumentAndUTF16() throws {
        XCTAssertThrowsError(try ImportDocumentReader.decode(Data(repeating: 0, count: 5_000_001), isPDF: false))
        let text = "Date;Montant\n2026-01-02;123,45"
        XCTAssertEqual(try ImportDocumentReader.decode(try XCTUnwrap(text.data(using: .utf16)), isPDF: false).csv, text)
    }
}
