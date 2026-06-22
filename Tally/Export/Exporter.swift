import Foundation

/// Builds CSV / JSON exports of the ledger and writes them to temporary files for
/// sharing. Everything stays on-device until the user explicitly shares it.
enum Exporter {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func csv(_ expenses: [Expense]) -> String {
        var rows = ["date,amount,currency,direction,source,theme,person,note"]
        let sorted = expenses.sorted { $0.date > $1.date }
        for e in sorted {
            let fields = [
                isoFormatter.string(from: e.date),
                String(format: "%.2f", e.money.majorValue),
                e.currencyCode,
                e.direction.rawValue,
                e.source.rawValue,
                e.category?.name ?? "",
                e.payee?.name ?? "",
                e.note,
            ].map(escapeCSV)
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    struct ExportRow: Codable {
        var date: String
        var amountMinor: Int
        var currency: String
        var direction: String
        var source: String
        var theme: String?
        var person: String?
        var note: String
    }

    static func json(_ expenses: [Expense]) -> Data {
        let rows = expenses.sorted { $0.date > $1.date }.map { e in
            ExportRow(
                date: isoFormatter.string(from: e.date),
                amountMinor: e.amountMinor,
                currency: e.currencyCode,
                direction: e.direction.rawValue,
                source: e.source.rawValue,
                theme: e.category?.name,
                person: e.payee?.name,
                note: e.note
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(rows)) ?? Data()
    }

    /// Write `contents` to a temp file and return its URL (nil on failure).
    static func writeTempFile(named name: String, contents: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try contents.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
