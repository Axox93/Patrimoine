import Foundation
import PDFKit
import PatrimoineCore

enum ImportDocumentReader {
    struct Content: Sendable { let csv: String; let pdfText: String }
    static func decode(_ data: Data, isPDF: Bool) throws -> Content {
        guard data.count <= 5_000_000 else { throw ImportFailure("Document trop volumineux (5 Mo maximum).") }
        if isPDF {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount <= 100,
                  let text = pdf.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.utf8.count <= 1_000_000 else {
                throw ImportFailure("Ce PDF est protégé, scanné, trop long ou sans texte exploitable. Utilisez un CSV de votre établissement.")
            }
            return Content(csv: "", pdfText: text)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw ImportFailure("Encodage non reconnu. Exportez en UTF-8.")
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportFailure("Le fichier CSV est vide.") }
        return Content(csv: text, pdfText: "")
    }
    static func read(_ url: URL) throws -> Content {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
            guard data.count + chunk.count <= 5_000_000 else { throw ImportFailure("Document trop volumineux (5 Mo maximum).") }
            data.append(chunk)
        }
        return try decode(data, isPDF: url.pathExtension.lowercased() == "pdf")
    }
}
