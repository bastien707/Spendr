import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: SFSymbol.dashboard)
                }

            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: SFSymbol.transactions)
                }

            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: SFSymbol.budget)
                }
        }
    }
}
