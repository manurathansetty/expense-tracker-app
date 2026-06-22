import SwiftUI

/// App-wide navigation state. Drives the quick-add sheet (including deep links
/// from the widget and the `tally://add` URL scheme) and the selected tab.
@Observable
final class AppRouter {
    enum Tab: Hashable { case ledger, insights, budget, settings }

    var selectedTab: Tab = .ledger
    var showQuickAdd = false

    /// Bumped when the app detects writes made by another process while it was
    /// backgrounded; used to force `@Query`-backed views to re-fetch.
    var dataRefreshToken = 0

    /// Text handed in by the share extension / Shortcuts to prefill quick-add.
    var pendingMessageText: String?

    init() {
        // Dev affordance: launch into a specific tab for screenshots.
        switch ProcessInfo.processInfo.environment["TALLY_TAB"] {
        case "insights": selectedTab = .insights
        case "budget": selectedTab = .budget
        case "settings": selectedTab = .settings
        default: break
        }
        if ProcessInfo.processInfo.environment["TALLY_QUICKADD"] == "1" {
            showQuickAdd = true
        }
    }

    func openQuickAdd(prefillingMessage text: String? = nil) {
        pendingMessageText = text
        showQuickAdd = true
    }

    /// Handle deep links such as `tally://add` or `tally://add?text=...`.
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
