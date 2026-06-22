import Foundation

/// Central identifiers shared across the app, widget, and share extension.
enum AppGroup {
    /// The App Group container shared by every target. Must match each target's
    /// `.entitlements` file.
    static let identifier = "group.ai.pageloop.tally"

    /// Custom URL scheme used for deep links (e.g. `tally://add`).
    static let urlScheme = "tally"

    /// `UserDefaults` suite shared across targets (used for the widget snapshot).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
