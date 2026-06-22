import SwiftUI
import SwiftData

/// Root shell: a persistent budget strip on top, the tab content, and a custom
/// notched bottom bar with a raised center ＋ (tap to add, hold to fan out).
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var writeCounterAtBackground = ExternalChange.current()

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                BudgetStripView()
                tabs
            }

            PiTabBar(
                selected: $router.selectedTab,
                onAdd: { Haptics.tap(); router.openQuickAdd() },
                onAction: { handleFan($0) },
                forceOpen: ProcessInfo.processInfo.environment["TALLY_FAN"] == "1"
            )
            .padding(.bottom, 2)
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

    private var tabs: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        )) {
            tab(LedgerView(), .ledger)
            tab(InsightsView(), .insights)
            tab(BudgetView(), .budget)
            tab(SettingsView(), .settings)
        }
        .id(router.dataRefreshToken)
    }

    private func tab<Content: View>(_ content: Content, _ which: AppRouter.Tab) -> some View {
        content
            .tag(which)
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 94) }
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
