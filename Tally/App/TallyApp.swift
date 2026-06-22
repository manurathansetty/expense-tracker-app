import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    let container = ModelContainerProvider.shared
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .tint(DS.accent)
                .task {
                    // Seed defaults and publish an initial widget snapshot.
                    SeedData.seedIfNeeded(container.mainContext)
                    LedgerService(context: container.mainContext).refreshSnapshot()
                }
                .onOpenURL { router.handle(url: $0) }
        }
        .modelContainer(container)
    }
}
