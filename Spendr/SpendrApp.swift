import SwiftUI
import SwiftData

@main
struct SpendrApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Transaction.self, CategoryBudget.self])
    }
}
