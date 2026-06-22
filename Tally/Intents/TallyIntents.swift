import AppIntents
import SwiftData
import Foundation

/// Logs a parsed bank/UPI message. This is the action the Shortcuts automation
/// calls: it receives the message text, parses it, and records the expense.
struct LogTransactionFromTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description = IntentDescription(
        "Parses a bank or UPI message and logs the expense in π."
    )

    @Parameter(title: "Message Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainerProvider.shared.mainContext
        SeedData.ensureSettings(context)

        let parsed = TransactionParser.parse(text)
        guard let minor = parsed.amountMinor else {
            return .result(dialog: "I couldn't find an amount in that message.")
        }

        // The automation logs silently rather than blocking, but we flag entries
        // that breach the ceiling so the overspend is auditable in the app.
        let service = LedgerService(context: context)
        let breached = service.settings().enforceBlocker
            && service.wouldBreachCeiling(addingMinor: minor, direction: parsed.direction)

        let expense = Expense(
            amountMinor: minor,
            currencyCode: parsed.currencyCode,
            note: parsed.merchant ?? "",
            date: .now,
            direction: parsed.direction,
            source: .message,
            rawMessage: text,
            didOverrideBlocker: breached
        )
        service.insert(expense)

        let money = Money(minorUnits: minor, currencyCode: parsed.currencyCode)
        return .result(dialog: breached
            ? "Logged \(money.formatted()) — you're now over your monthly limit."
            : "Logged \(money.formatted()).")
    }
}

/// Quickly add an expense by voice or from Shortcuts.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Quickly log an expense in π.")

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Note", default: "")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainerProvider.shared.mainContext
        SeedData.ensureSettings(context)

        let service = LedgerService(context: context)
        let settings = service.settings()
        let minor = Int((amount * Double(Money.minorUnitsPerMajor)).rounded())
        let breached = settings.enforceBlocker
            && service.wouldBreachCeiling(addingMinor: minor, direction: .paid)

        let expense = Expense(
            amountMinor: minor,
            currencyCode: settings.currencyCode,
            note: note,
            source: .manual,
            didOverrideBlocker: breached
        )
        service.insert(expense)

        let money = Money(minorUnits: minor, currencyCode: settings.currencyCode)
        return .result(dialog: breached
            ? "Added \(money.formatted()) — over your monthly limit."
            : "Added \(money.formatted()).")
    }
}

/// Exposes the intents to Siri and Spotlight with spoken phrases.
struct TallyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log a spend in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "indianrupeesign.circle"
        )
        AppShortcut(
            intent: LogTransactionFromTextIntent(),
            phrases: [
                "Log a transaction in \(.applicationName)",
            ],
            shortTitle: "Log Transaction",
            systemImageName: "text.bubble"
        )
    }
}
