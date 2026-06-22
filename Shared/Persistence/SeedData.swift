import Foundation
import SwiftData

/// First-launch seeding of default themes and the budget settings row.
enum SeedData {
    struct CategorySeed {
        let name: String
        let symbol: String
        let hex: String
    }

    static let defaultCategories: [CategorySeed] = [
        .init(name: "Food & Drink", symbol: "fork.knife", hex: "FF6B6B"),
        .init(name: "Groceries", symbol: "cart.fill", hex: "34C759"),
        .init(name: "Transport", symbol: "car.fill", hex: "0A84FF"),
        .init(name: "Home & Rent", symbol: "house.fill", hex: "BF5AF2"),
        .init(name: "Bills", symbol: "bolt.fill", hex: "FFD60A"),
        .init(name: "Shopping", symbol: "bag.fill", hex: "FF9F0A"),
        .init(name: "Health", symbol: "cross.case.fill", hex: "FF375F"),
        .init(name: "Fun", symbol: "film.fill", hex: "5E5CE6"),
        .init(name: "Gifts", symbol: "gift.fill", hex: "FF2D55"),
        .init(name: "Travel", symbol: "airplane", hex: "30B0C7"),
        .init(name: "Other", symbol: "ellipsis.circle.fill", hex: "8E8E93"),
    ]

    /// Ensures default categories and a settings row exist. Safe to call on every
    /// launch — it only writes when the store is empty.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        seedCategoriesIfNeeded(context)
        ensureSettings(context)
        try? context.save()
    }

    @MainActor
    private static func seedCategoriesIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        for (index, seed) in defaultCategories.enumerated() {
            let category = Category(
                name: seed.name,
                symbolName: seed.symbol,
                colorHex: seed.hex,
                sortIndex: index
            )
            context.insert(category)
        }
    }

    @MainActor
    static func ensureSettings(_ context: ModelContext) {
        let descriptor = FetchDescriptor<BudgetSettings>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        context.insert(BudgetSettings())
    }
}
