import SwiftUI
import SwiftData

/// Root shell: a thin budget bar on top, the tab content, and a custom bottom
/// bar with a raised center ＋. The bottom bar is attached as a `safeAreaInset`
/// so the system insets every tab's scroll content by the bar's real height —
/// content can never hide behind it.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var writeCounterAtBackground = ExternalChange.current()

    var body: some View {
        @Bindable var router = router

        VStack(spacing: 0) {
            BudgetStripView()

            TabView(selection: $router.selectedTab) {
                tab(LedgerView(), .ledger)
                tab(InsightsView(), .insights)
                tab(BudgetView(), .budget)
                tab(SettingsView(), .settings)
            }
            .id(router.dataRefreshToken)

            // A layout sibling (not an overlay): tab content ends above the bar,
            // so nothing — even short lists — can hide behind it. The fan still
            // draws over the content because this is the last sibling.
            PiTabBar(
                selected: $router.selectedTab,
                onAdd: { Haptics.tap(); router.openQuickAdd() },
                onAction: { handleFan($0) }
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $router.activeSheet, content: sheetContent)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                writeCounterAtBackground = ExternalChange.current()
            case .active:
                LedgerService(context: context).refreshSnapshot()
                if ExternalChange.current() != writeCounterAtBackground {
                    router.dataRefreshToken += 1
                    writeCounterAtBackground = ExternalChange.current()
                }
            @unknown default:
                break
            }
        }
    }

    private func tab<Content: View>(_ content: Content, _ which: AppRouter.Tab) -> some View {
        content
            .tag(which)
            .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .quickAdd:
            QuickAddView(prefillMessage: router.pendingMessageText)
                .onDisappear { router.pendingMessageText = nil }
        case .recurring:
            NavigationStack { RecurringView() }
        case .addTheme:
            CategoryEditView(category: nil)
        case .addPerson:
            EditPayeeView()
        case .addRecurring:
            EditRecurringView(payment: nil)
        }
    }

    private func handleFan(_ action: FanAction) {
        switch action {
        case .expense: router.openQuickAdd()
        case .theme: router.activeSheet = .addTheme
        case .person: router.activeSheet = .addPerson
        case .recurring: router.activeSheet = .addRecurring
        }
    }
}
