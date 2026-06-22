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
        RecurringPayment.self,
        SavingsRecord.self,
        Trip.self,
        TripMember.self,
        TripExpense.self,
    ])

    static let shared: ModelContainer = make()

    static func make() -> ModelContainer {
        // Only request the App Group container when the entitlement is actually
        // applied — otherwise SwiftData fatal-errors (it does not throw) on a
        // missing group. Unsigned builds (e.g. tests) fall back to a local store.
        let hasAppGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
        if hasAppGroup {
            let groupConfig = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier)
            )
            if let container = try? ModelContainer(for: schema, configurations: groupConfig) {
                return container
            }
        }

        // App-local store at an explicit URL whose directory we ensure exists.
        let appSupport = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let localURL = appSupport.appendingPathComponent("Tally.store")
        let localConfig = ModelConfiguration(schema: schema, url: localURL)
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
