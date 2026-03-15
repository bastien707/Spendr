import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categoryBudgets: [CategoryBudget]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBudget = false
    @State private var budgetToEdit: CategoryBudget? = nil

    // Only budgets for the current month
    private var currentBudgets: [CategoryBudget] {
        let start = Calendar.current.startOfMonth(for: Date())
        return categoryBudgets.filter {
            Calendar.current.isDate($0.month, equalTo: start, toGranularity: .month)
        }
    }

    // Expenses for the current month
    private var monthExpenses: [Transaction] {
        transactions.filter {
            $0.type == .expense &&
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }
    }

    // Total budgeted across all categories
    private var totalBudgeted: Double {
        currentBudgets.reduce(0) { $0 + $1.monthlyLimit }
    }

    // Total spent in budgeted categories this month
    private var totalSpent: Double {
        currentBudgets.reduce(0) { $0 + spent(for: $1.category) }
    }

    private var totalRemaining: Double { totalBudgeted - totalSpent }

    private var globalRatio: Double {
        guard totalBudgeted > 0 else { return 0 }
        return min(totalSpent / totalBudgeted, 1.0)
    }

    // Categories not yet budgeted (only expense categories)
    private var availableCategories: [Category] {
        let budgeted = Set(currentBudgets.map(\.category))
        return Category.allCases.filter { $0.type == .expense && !budgeted.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentBudgets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summaryCard
                            categoryList
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(availableCategories.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddCategoryBudgetView(availableCategories: availableCategories)
            }
            .sheet(item: $budgetToEdit) { budget in
                AddCategoryBudgetView(editingBudget: budget)
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No category budgets")
                .font(.title2).fontWeight(.semibold)
            Text("Set a monthly limit per spending category.\nExample: Food → 400€, Transport → 150€.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add a category budget") {
                showingAddBudget = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity)
    }

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total remaining")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(totalRemaining, format: .currency(code: "EUR"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(totalRemaining >= 0 ? Color.primary : Color.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Budget")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(totalBudgeted, format: .currency(code: "EUR"))
                        .font(.headline).fontWeight(.semibold)
                }
            }

            // Global progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressColor(ratio: globalRatio))
                        .frame(width: geo.size.width * globalRatio, height: 10)
                        .animation(.easeInOut(duration: 0.5), value: globalRatio)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(totalSpent, format: .currency(code: "EUR")) spent")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(globalRatio * 100))% of budget used")
                    .font(.caption).foregroundStyle(progressColor(ratio: globalRatio))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(currentBudgets.sorted { $0.category.rawValue < $1.category.rawValue }) { budget in
                CategoryBudgetRow(
                    budget: budget,
                    spent: spent(for: budget.category)
                )
                .contentShape(Rectangle())
                .onTapGesture { budgetToEdit = budget }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        modelContext.delete(budget)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func spent(for category: Category) -> Double {
        monthExpenses
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    private func progressColor(ratio: Double) -> Color {
        switch ratio {
        case ..<0.6:  return .green
        case ..<0.85: return .orange
        default:      return .red
        }
    }
}

// MARK: - Category Budget Row

struct CategoryBudgetRow: View {
    let budget: CategoryBudget
    let spent: Double

    private var remaining: Double { budget.monthlyLimit - spent }
    private var ratio: Double { min(spent / max(budget.monthlyLimit, 1), 1.0) }

    private var progressColor: Color {
        switch ratio {
        case ..<0.6:  return .green
        case ..<0.85: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(progressColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: budget.category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(progressColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.category.rawValue)
                        .font(.subheadline).fontWeight(.medium)
                    Text("\(spent, format: .currency(code: "EUR")) spent of \(budget.monthlyLimit, format: .currency(code: "EUR"))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining >= 0 ? remaining : abs(remaining), format: .currency(code: "EUR"))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                    Text(remaining >= 0 ? "left" : "over budget")
                        .font(.caption2)
                        .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                }
            }

            // Per-category progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * ratio, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: ratio)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
