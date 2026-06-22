import Foundation

/// The result of parsing a bank/UPI alert. Any field may be missing — the UI
/// fills the gaps and lets the user confirm.
struct ParsedTransaction: Equatable, Sendable {
    var amountMinor: Int?
    var currencyCode: String
    var direction: Direction
    var merchant: String?
    var raw: String

    var hasAmount: Bool { amountMinor != nil }
}

/// Extracts an amount, direction and merchant from transaction text such as a
/// bank SMS or UPI alert. Pure and side-effect free so it can run inside the
/// share extension, the Shortcuts intent, and unit tests alike.
enum TransactionParser {

    static func parse(_ text: String) -> ParsedTransaction {
        let lower = text.lowercased()
        let currency = detectCurrency(lower)
        let amount = detectAmountMinor(in: text, looseIntegerAllowed: hasTransactionKeyword(lower))
        let direction = detectDirection(lower)
        let merchant = detectMerchant(in: text)

        return ParsedTransaction(
            amountMinor: amount,
            currencyCode: currency,
            direction: direction,
            merchant: merchant,
            raw: text
        )
    }

    // MARK: Currency

    private static func detectCurrency(_ lower: String) -> String {
        // Match the rupee token "Rs"/"Rs." only at a word boundary (so "cars.com"
        // or "burgers." don't count), either standalone or followed by an amount.
        let rupeeToken = lower.range(of: #"(?:^|[^a-z])rs\.?\s*\d"#, options: .regularExpression) != nil
            || lower.range(of: #"(?:^|[^a-z])rs\b"#, options: .regularExpression) != nil
        if lower.contains("₹") || lower.contains("inr") || rupeeToken {
            return "INR"
        }
        if lower.contains("usd") || lower.contains("$") { return "USD" }
        if lower.contains("eur") || lower.contains("€") { return "EUR" }
        if lower.contains("gbp") || lower.contains("£") { return "GBP" }
        return Money.defaultCurrencyCode
    }

    // MARK: Amount

    private static func detectAmountMinor(in text: String, looseIntegerAllowed: Bool) -> Int? {
        // Prefer a number that sits next to a currency token.
        let currencyPatterns = [
            #"(?:₹|rs\.?|inr|usd|\$|eur|€|gbp|£)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr)"#,
        ]
        for pattern in currencyPatterns {
            if let captured = firstCapture(pattern, in: text, options: [.caseInsensitive]),
               let minor = Money.minorUnits(fromUserInput: captured) {
                return minor
            }
        }
        // A decimal-shaped number always looks monetary.
        if let captured = firstCapture(#"\b([0-9][0-9,]*\.[0-9]{2})\b"#, in: text),
           let minor = Money.minorUnits(fromUserInput: captured) {
            return minor
        }
        // A bare integer after "for"/"of" is only trusted when a transaction
        // keyword anchors the intent — avoids picking up OTP windows / promo codes.
        if looseIntegerAllowed,
           let captured = firstCapture(#"(?:for|of)\s+([0-9][0-9,]*)"#, in: text, options: [.caseInsensitive]),
           let minor = Money.minorUnits(fromUserInput: captured) {
            return minor
        }
        return nil
    }

    private static func hasTransactionKeyword(_ lower: String) -> Bool {
        let keywords = ["debited", "debit", "spent", "paid", "sent", "withdrawn",
                        "purchase", "payment", "deducted", "credited", "credit",
                        "received", "refund", "deposit"]
        return keywords.contains { lower.contains($0) }
    }

    // MARK: Direction

    private static func detectDirection(_ lower: String) -> Direction {
        let debit = ["debited", "debit", "spent", "paid", "sent", "withdrawn",
                     "purchase", "payment of", "deducted"]
        let credit = ["credited", "received", "refund", "deposit", "credit of"]

        if debit.contains(where: { lower.contains($0) }) { return .paid }
        if credit.contains(where: { lower.contains($0) }) { return .owedToMe }
        return .paid
    }

    // MARK: Merchant

    private static func detectMerchant(in text: String) -> String? {
        let patterns = [
            #"(?:vpa)\s+([A-Za-z0-9@._\-]{2,40})"#,
            #"\bat\s+([A-Za-z0-9][A-Za-z0-9 &.'_\-]{1,30})"#,
            #"\bto\s+([A-Za-z0-9@][A-Za-z0-9 &.'_@\-]{1,30})"#,
        ]
        for pattern in patterns {
            if let captured = firstCapture(pattern, in: text, options: [.caseInsensitive]) {
                return cleanMerchant(captured)
            }
        }
        return nil
    }

    private static func cleanMerchant(_ raw: String) -> String? {
        // Stop at filler words / sentence boundaries that often trail a merchant.
        let stopWords = [" on ", " ref ", " upi ", " via ", " a/c ", " for ", " info "]
        var value = raw
        let lower = value.lowercased()
        var cutoff = value.endIndex
        for word in stopWords {
            if let range = lower.range(of: word) {
                cutoff = min(cutoff, value.index(value.startIndex,
                                                 offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound)))
            }
        }
        value = String(value[value.startIndex..<cutoff])
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-_"))
        return value.isEmpty ? nil : value
    }

    // MARK: Regex helper

    private static func firstCapture(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
