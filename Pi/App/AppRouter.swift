import SwiftUI

/// App-wide navigation state. Drives the modal sheets (quick-add, recurring) and
/// the selected tab, including deep links from the widget / `pi://add` URL.
@Observable
final class AppRouter {
    enum Tab: Hashable { case ledger, insights, budget, settings }

    /// A single active sheet — using one `.sheet(item:)` avoids the unreliable
    /// behavior of stacking multiple `.sheet` modifiers on one view.
    enum Sheet: Int, Identifiable {
        case quickAdd, recurring, addTheme, addPerson, addRecurring
        var id: Int { rawValue }
    }

    var selectedTab: Tab = .ledger
    var activeSheet: Sheet?

    /// Bumped when the app detects writes made by another process while it was
    /// backgrounded; used to force `@Query`-backed views to re-fetch.
    var dataRefreshToken = 0

    /// Text handed in by the share extension / Shortcuts to prefill quick-add.
    var pendingMessageText: String?

    init() {
        // Dev affordances for screenshots / deep links.
        switch ProcessInfo.processInfo.environment["TALLY_TAB"] {
        case "insights": selectedTab = .insights
        case "budget": selectedTab = .budget
        case "settings": selectedTab = .settings
        default: break
        }
        if ProcessInfo.processInfo.environment["TALLY_QUICKADD"] == "1" {
            activeSheet = .quickAdd
        }
        if ProcessInfo.processInfo.environment["TALLY_SCREEN"] == "recurring" {
            activeSheet = .recurring
        }
    }

    func openQuickAdd(prefillingMessage text: String? = nil) {
        pendingMessageText = text
        activeSheet = .quickAdd
    }

    /// Handle deep links such as `pi://add` or `pi://add?text=...`.
    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        switch url.host {
        case "add":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value
            openQuickAdd(prefillingMessage: text)
        default:
            break
        }
    }
}
