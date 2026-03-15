import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var viewModel = TransactionViewModel()

    private var monthTransactions: [Transaction] {
        viewModel.transactionsForCurrentMonth(from: transactions)
    }

    private var totalIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double { totalIncome - totalExpenses }

    private var expensesByCategory: [(category: Category, total: Double)] {
        let expenses = monthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    incomeExpenseRow
                    if !expensesByCategory.isEmpty {
                        categoryChart
                    }
                    recentTransactions
                }
                .padding()
            }
            .navigationTitle("Spendr")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(balance, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? .green : .red)
            Text("This month")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var incomeExpenseRow: some View {
        HStack(spacing: 16) {
            summaryCard(title: "Income", amount: totalIncome, color: .green, icon: "arrow.down.circle.fill")
            summaryCard(title: "Expenses", amount: totalExpenses, color: .red, icon: "arrow.up.circle.fill")
        }
    }

    private func summaryCard(title: String, amount: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            Chart(expensesByCategory, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Category", item.category.rawValue))
            }
            .frame(height: 220)

            VStack(spacing: 8) {
                ForEach(expensesByCategory, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .frame(width: 20)
                        Text(item.category.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Text(item.total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)

            if monthTransactions.isEmpty {
                Text("No transactions yet. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(monthTransactions.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
