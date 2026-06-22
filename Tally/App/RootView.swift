import SwiftUI
import SwiftData

/// Root tab shell with a prominent center quick-add button.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                LedgerView()
                    .tabItem { Label("Ledger", systemImage: "list.bullet.rectangle.portrait") }
                    .tag(AppRouter.Tab.ledger)

                InsightsView()
                    .tabItem { Label("Insights", systemImage: "chart.pie.fill") }
                    .tag(AppRouter.Tab.insights)

                BudgetView()
                    .tabItem { Label("Budget", systemImage: "target") }
                    .tag(AppRouter.Tab.budget)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppRouter.Tab.settings)
            }

            QuickAddButton {
                Haptics.tap()
                router.openQuickAdd()
            }
            .padding(.bottom, 54) // float just above the tab bar
        }
        .sheet(isPresented: $router.showQuickAdd) {
            QuickAddView(prefillMessage: router.pendingMessageText)
                .onDisappear { router.pendingMessageText = nil }
        }
    }
}

/// The floating + button.
private struct QuickAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(DS.accent)
                        .shadow(color: DS.accent.opacity(0.4), radius: 10, y: 4)
                )
        }
        .accessibilityLabel("Add expense")
    }
}
