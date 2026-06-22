import Foundation

/// Central identifiers shared across the app, widget, and share extension.
enum AppGroup {
    /// The App Group container shared by every target. Must match each target's
    /// `.entitlements` file.
    static let identifier = "group.ai.pageloop.pi"

    /// Custom URL scheme used for deep links (e.g. `pi://add`).
    static let urlScheme = "pi"

    /// `UserDefaults` suite shared across targets (used for the widget snapshot).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// A monotonically increasing counter, stored in the shared App Group, that any
/// process bumps after it writes to the store. The app reads it on foreground to
/// detect writes made while it was backgrounded (by the share extension or the
/// Shortcuts/Siri intents) and refresh its live `@Query` views accordingly —
/// SwiftData does not merge cross-process changes automatically.
enum ExternalChange {
    private static let key = "tally.writeCounter"

    static func bump() {
        let next = AppGroup.defaults.integer(forKey: key) + 1
        AppGroup.defaults.set(next, forKey: key)
    }

    static func current() -> Int {
        AppGroup.defaults.integer(forKey: key)
    }
}
