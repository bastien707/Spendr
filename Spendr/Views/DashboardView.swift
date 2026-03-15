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

    private var expensesByCategory: [(category: UserCategory, total: Double)] {
        let expenses = monthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { $0.userCategory }
        return grouped
            .compactMap { (cat, txns) -> (category: UserCategory, total: Double)? in
                guard let cat else { return nil }
                return (category: cat, total: txns.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    balanceCard
                    incomeExpenseRow
                    if !expensesByCategory.isEmpty {
                        categoryChart
                    }
                    recentTransactions
                }
                .padding(DS.Spacing.md)
            }
            .navigationTitle("Spendr")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: SFSymbol.add)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
        }
    }

    // MARK: - Subviews

    private var balanceCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(balance, format: .currency(code: "EUR"))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.green : Color.red)
            Text("This month")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var incomeExpenseRow: some View {
        HStack(spacing: DS.Spacing.md) {
            miniSummaryCard(title: "Income", amount: totalIncome, icon: SFSymbol.income, color: .green)
            miniSummaryCard(title: "Expenses", amount: totalExpenses, icon: SFSymbol.expense, color: .red)
        }
    }

    private func miniSummaryCard(title: String, amount: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(amount, format: .currency(code: "EUR")).font(.headline).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: DS.Radius.md)
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Spending by Category")

            Chart(expensesByCategory, id: \.category.id) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(item.category.color)
            }
            .frame(height: 220)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(expensesByCategory, id: \.category.id) { item in
                    HStack(spacing: DS.Spacing.sm) {
                        CategoryIcon(systemName: item.category.icon, color: item.category.color, size: DS.IconSize.sm)
                        Text(item.category.name)
                            .font(.subheadline)
                        Spacer()
                        Text(item.total, format: .currency(code: "EUR"))
                            .font(.subheadline).fontWeight(.medium)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Recent")

            if monthTransactions.isEmpty {
                EmptyStateView(icon: SFSymbol.empty, title: "No transactions yet", message: "Tap + to record your first one.")
                    .frame(height: 120)
            } else {
                ForEach(monthTransactions.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .cardStyle()
    }
}
