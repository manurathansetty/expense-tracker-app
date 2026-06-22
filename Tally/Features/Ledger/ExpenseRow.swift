import SwiftUI

/// One row in the ledger: glyph, note/category, person, time, and signed amount.
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            GlyphBadge(
                symbolName: expense.category?.symbolName ?? expense.direction.symbolName,
                colorHex: expense.category?.colorHex ?? "8E8E93"
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.xs) {
                    Text(expense.date, format: .dateTime.hour().minute())
                    if let payee = expense.payee {
                        Text("· \(payee.name)")
                    }
                    if expense.source == .message {
                        Image(systemName: "text.bubble")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text(amountString)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if !expense.note.isEmpty { return expense.note }
        if let category = expense.category { return category.name }
        return expense.direction.label
    }

    private var amountString: String {
        let value = expense.money.formattedCompact()
        return expense.direction == .owedToMe ? "+\(value)" : value
    }

    private var amountColor: Color {
        expense.direction == .owedToMe ? Color(hex: "34C759") : .primary
    }
}
