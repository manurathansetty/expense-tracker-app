import Foundation
import SwiftData

/// Builds the single `ModelContainer` shared by every target.
///
/// It first tries the App Group container so the widget and share extension see
/// the same data. If the App Group entitlement isn't applied (e.g. an unsigned
/// build), it falls back to an app-local store so the main app still works, and
/// finally to an in-memory store as a last resort.
enum ModelContainerProvider {
    static let schema = Schema([
        Expense.self,
        Category.self,
        Payee.self,
        BudgetSettings.self,
        Commitment.self,
    ])

    static let shared: ModelContainer = make()

    static func make() -> ModelContainer {
        let groupConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        if let container = try? ModelContainer(for: schema, configurations: groupConfig) {
            return container
        }

        let localConfig = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: localConfig) {
            return container
        }

        do {
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memoryConfig)
        } catch {
            fatalError("Unable to create a ModelContainer: \(error)")
        }
    }
}
