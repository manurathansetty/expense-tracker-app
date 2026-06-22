import Foundation
import SwiftData

/// A spending "theme" — what an expense was for. Each carries an SF Symbol and a
/// color, and optionally an envelope allocation (a percentage of expendable
/// income budgeted to this theme).
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "tag.fill"
    var colorHex: String = "5E5CE6"
    var sortIndex: Int = 0
    var isArchived: Bool = false

    /// Optional envelope budget: percentage (0–100) of expendable income.
    var allocationPercent: Double?

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(
        name: String,
        symbolName: String = "tag.fill",
        colorHex: String = "5E5CE6",
        sortIndex: Int = 0,
        allocationPercent: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.allocationPercent = allocationPercent
    }
}
