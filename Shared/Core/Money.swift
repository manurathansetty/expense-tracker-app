import Foundation

/// Money is stored as integer **minor units** (paise / cents) to avoid the
/// floating-point drift you get from storing currency as `Double`.
///
/// `Money` is a thin value type around that integer plus an ISO-4217 currency
/// code, with helpers to parse user input and format for display.
struct Money: Equatable, Hashable, Sendable {
    var minorUnits: Int
    var currencyCode: String

    init(minorUnits: Int, currencyCode: String = Money.defaultCurrencyCode) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    static let defaultCurrencyCode = "INR"

    /// Number of minor units in one major unit (assumes 2 for supported
    /// currencies; covers INR/USD/EUR/GBP and most others).
    static let minorUnitsPerMajor = 100

    var majorValue: Double {
        Double(minorUnits) / Double(Money.minorUnitsPerMajor)
    }

    // MARK: Formatting

    /// Currency-formatted string, e.g. "₹1,250.00".
    func formatted(showFraction: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = showFraction ? 2 : 0
        formatter.minimumFractionDigits = showFraction ? 2 : 0
        let number = NSNumber(value: majorValue)
        return formatter.string(from: number) ?? "\(symbol)\(majorValue)"
    }

    /// Compact form that drops the ".00" when the amount is whole.
    func formattedCompact() -> String {
        let whole = minorUnits % Money.minorUnitsPerMajor == 0
        return formatted(showFraction: !whole)
    }

    var symbol: String {
        let locale = Locale(identifier: "en_US@currency=\(currencyCode)")
        return locale.currencySymbol ?? currencyCode
    }

    static func symbol(for currencyCode: String) -> String {
        let locale = Locale(identifier: "en_US@currency=\(currencyCode)")
        return locale.currencySymbol ?? currencyCode
    }

    // MARK: Parsing

    /// Parse a free-text amount like "1,250.50", "₹1250", or "Rs. 99" into minor
    /// units. Returns `nil` when no number can be found.
    static func minorUnits(fromUserInput input: String) -> Int? {
        // Strip everything except digits, separators and a leading sign.
        let allowed = CharacterSet(charactersIn: "0123456789.,-")
        let cleaned = String(input.unicodeScalars.filter { allowed.contains($0) })
        guard !cleaned.isEmpty else { return nil }

        // Decide which of "." / "," is the decimal separator: the right-most one
        // that leaves 1-2 trailing digits is treated as the decimal point.
        let normalized = normalizeDecimalSeparators(cleaned)
        guard let value = Double(normalized) else { return nil }
        return Int((value * Double(minorUnitsPerMajor)).rounded())
    }

    private static func normalizeDecimalSeparators(_ s: String) -> String {
        let lastDot = s.lastIndex(of: ".")
        let lastComma = s.lastIndex(of: ",")

        func decimalIndex() -> String.Index? {
            switch (lastDot, lastComma) {
            case let (d?, c?): return d > c ? d : c
            case let (d?, nil): return d
            case let (nil, c?): return c
            default: return nil
            }
        }

        guard let decIdx = decimalIndex() else {
            return s.filter { $0.isNumber || $0 == "-" }
        }

        // Treat the chosen separator as the decimal point only if 1-2 digits follow.
        let fractionDigits = s.distance(from: s.index(after: decIdx), to: s.endIndex)
        let integerPart = s[..<decIdx].filter { $0.isNumber || $0 == "-" }
        let fractionPart = s[s.index(after: decIdx)...].filter { $0.isNumber }

        if fractionDigits >= 1 && fractionDigits <= 2 {
            return "\(integerPart).\(fractionPart)"
        } else {
            // Separator was a grouping mark — no fractional part.
            return integerPart + fractionPart
        }
    }
}
