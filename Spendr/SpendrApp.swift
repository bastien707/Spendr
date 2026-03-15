import SwiftUI
import SwiftData

@main
struct SpendrApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Transaction.self, CategoryBudget.self, UserCategory.self])
        let config = ModelConfiguration(
            "Spendr",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        container = try! ModelContainer(for: schema, configurations: [config])

        let context = ModelContext(container)
        CategorySeeder.seedIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
