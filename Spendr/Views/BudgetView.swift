import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categoryBudgets: [CategoryBudget]
    @Query(sort: \UserCategory.sortOrder) private var allCategories: [UserCategory]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBudget = false
    @State private var budgetToEdit: CategoryBudget? = nil
    @State private var showingCategories = false

    private var currentBudgets: [CategoryBudget] {
        let start = Calendar.current.startOfMonth(for: Date())
        return categoryBudgets.filter {
            Calendar.current.isDate($0.month, equalTo: start, toGranularity: .month)
        }
    }

    private var monthExpenses: [Transaction] {
        transactions.filter {
            $0.type == .expense &&
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }
    }

    private var totalBudgeted: Double { currentBudgets.reduce(0) { $0 + $1.monthlyLimit } }
    private var totalSpent: Double {
        currentBudgets.compactMap { $0.userCategory }.reduce(0.0) { total, cat in
            total + spent(for: cat)
        }
    }
    private var totalRemaining: Double { totalBudgeted - totalSpent }
    private var globalRatio: Double {
        guard totalBudgeted > 0 else { return 0 }
        return min(totalSpent / totalBudgeted, 1.0)
    }

    private var availableCategories: [UserCategory] {
        let budgetedIDs = Set(currentBudgets.compactMap { $0.userCategory?.id })
        return allCategories.filter { $0.type == .expense && !budgetedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentBudgets.isEmpty {
                    EmptyStateView(
                        icon: SFSymbol.budget,
                        title: "No category budgets",
                        message: "Set a monthly limit per spending category.\nExample: Food → 400€, Transport → 150€.",
                        action: { showingAddBudget = true },
                        actionLabel: "Add a category budget"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            summaryCard
                            categoryList
                        }
                        .padding(DS.Spacing.md)
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCategories = true
                    } label: {
                        Image(systemName: SFSymbol.manageCategories)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: SFSymbol.add)
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
            .sheet(isPresented: $showingCategories) {
                CategoriesView()
            }
        }
    }

    // MARK: - Subviews

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Total remaining")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(totalRemaining, format: .currency(code: "EUR"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(totalRemaining >= 0 ? Color.primary : Color.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    Text("Budget").font(.subheadline).foregroundStyle(.secondary)
                    Text(totalBudgeted, format: .currency(code: "EUR"))
                        .font(.headline).fontWeight(.semibold)
                }
            }

            BudgetProgressBar(ratio: globalRatio, height: 10)

            HStack {
                Text("\(totalSpent, format: .currency(code: "EUR")) spent")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(globalRatio * 100))% of budget used")
                    .font(.caption).foregroundStyle(progressColor(globalRatio))
            }
        }
        .cardStyle(radius: DS.Radius.lg)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: "Categories")

            ForEach(currentBudgets.sorted { ($0.categoryName) < ($1.categoryName) }) { budget in
                if let cat = budget.userCategory {
                    CategoryBudgetRow(budget: budget, spent: spent(for: cat))
                        .contentShape(Rectangle())
                        .onTapGesture { budgetToEdit = budget }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(budget)
                            } label: {
                                Label("Delete", systemImage: SFSymbol.delete)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Helpers

    private func spent(for category: UserCategory) -> Double {
        monthExpenses.filter { $0.userCategory?.id == category.id }.reduce(0) { $0 + $1.amount }
    }

    private func progressColor(_ ratio: Double) -> Color {
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

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                CategoryIcon(
                    systemName: budget.categoryIcon,
                    color: budget.categoryColor,
                    size: DS.IconSize.md
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(budget.categoryName)
                        .font(.subheadline).fontWeight(.medium)
                    Text("\(spent, format: .currency(code: "EUR")) of \(budget.monthlyLimit, format: .currency(code: "EUR"))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    Text(abs(remaining), format: .currency(code: "EUR"))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                    HStack(spacing: 2) {
                        if remaining < 0 {
                            Image(systemName: SFSymbol.overBudget)
                                .font(.caption2).foregroundStyle(Color.red)
                        }
                        Text(remaining >= 0 ? "left" : "over budget")
                            .font(.caption2)
                            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    }
                }
            }

            BudgetProgressBar(ratio: ratio, height: 6)
        }
        .cardStyle(radius: DS.Radius.md)
    }
}
