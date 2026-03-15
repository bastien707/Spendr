import SwiftUI
import SwiftData

@main
struct SpendrApp: App {
    private let container: ModelContainer
    @State private var authService: AuthService
    @State private var syncService: SyncService

    init() {
        let schema = Schema([Transaction.self, CategoryBudget.self, UserCategory.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let built = try! ModelContainer(for: schema, configurations: [config])

        let context = ModelContext(built)
        CategorySeeder.seedIfNeeded(context: context)

        let auth = AuthService()
        let sync = SyncService(context: built.mainContext, authService: auth)
        self.container = built
        _authService = State(initialValue: auth)
        _syncService = State(initialValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .environment(syncService)
                } else {
                    LoginView()
                }
            }
            .environment(authService)
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    Task { await syncService.wipeAndPullAll() }
                } else {
                    syncService.wipeLocalData()
                }
            }
        }
        .modelContainer(container)
    }
}
