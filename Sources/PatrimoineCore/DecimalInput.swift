import Foundation

public enum DecimalInput {
    /// Strict French/English input, without ambiguous thousands separators or exponents.
    public static func parse(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: "^[0-9]+([.,][0-9]{1,12})?$", options: .regularExpression) != nil,
              value.filter({ $0.isNumber }).count <= 28 else { return nil }
        return Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }
}
