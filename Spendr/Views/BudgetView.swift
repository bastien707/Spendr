import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Environment(\.modelContext) private var modelContext

    @State private var showingEditBudget = false
    @State private var incomeInput = ""

    private var currentBudget: Budget? {
        let startOfMonth = Calendar.current.startOfMonth(for: Date())
        return budgets.first { Calendar.current.isDate($0.month, equalTo: startOfMonth, toGranularity: .month) }
    }

    private var monthlyIncome: Double {
        currentBudget?.monthlyIncome ?? 0
    }

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    private var totalExpenses: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Double {
        monthlyIncome - totalExpenses
    }

    private var spentRatio: Double {
        guard monthlyIncome > 0 else { return 0 }
        return min(totalExpenses / monthlyIncome, 1.0)
    }

    private var expensesByCategory: [(category: Category, total: Double)] {
        let expenses = monthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    // Build daily cumulative spending data for the current month
    private var dailySpendingData: [(day: Int, cumulative: Double)] {
        let calendar = Calendar.current
        let expenses = monthTransactions.filter { $0.type == .expense }
            .sorted { $0.date < $1.date }

        var result: [(day: Int, cumulative: Double)] = []
        var running = 0.0
        let today = calendar.component(.day, from: Date())

        for day in 1...today {
            let dayExpenses = expenses.filter {
                calendar.component(.day, from: $0.date) == day
            }
            running += dayExpenses.reduce(0) { $0 + $1.amount }
            result.append((day: day, cumulative: running))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if monthlyIncome == 0 {
                        noBudgetPlaceholder
                    } else {
                        budgetSummaryCard
                        progressSection
                        dailyChart
                        categoryBreakdown
                    }
                }
                .padding()
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        incomeInput = monthlyIncome > 0 ? String(monthlyIncome) : ""
                        showingEditBudget = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingEditBudget) {
                editBudgetSheet
            }
        }
    }

    // MARK: - Subviews

    private var noBudgetPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "eurosign.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No budget set")
                .font(.title2).fontWeight(.semibold)
            Text("Set your monthly income to track how much you have left to spend.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Set Monthly Income") {
                incomeInput = ""
                showingEditBudget = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }

    private var budgetSummaryCard: some View {
        VStack(spacing: 6) {
            Text("Remaining this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(remaining, format: .currency(code: "EUR"))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(remaining >= 0 ? .green : .red)
            HStack(spacing: 4) {
                Text("of")
                Text(monthlyIncome, format: .currency(code: "EUR"))
                    .fontWeight(.medium)
                Text("budget")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Spent", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.red)
                Spacer()
                Text(totalExpenses, format: .currency(code: "EUR"))
                    .fontWeight(.semibold)
                Text("/ \(Int(spentRatio * 100))%")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressColor)
                        .frame(width: geo.size.width * spentRatio, height: 14)
                        .animation(.easeInOut(duration: 0.6), value: spentRatio)
                }
            }
            .frame(height: 14)

            HStack {
                Text(spentRatio >= 1 ? "Over budget!" : "\(Int((1 - spentRatio) * 100))% remaining")
                    .font(.caption)
                    .foregroundStyle(progressColor)
                Spacer()
                Text(monthlyIncome, format: .currency(code: "EUR"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressColor: Color {
        switch spentRatio {
        case ..<0.6: return .green
        case ..<0.85: return .orange
        default: return .red
        }
    }

    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily spending this month")
                .font(.headline)

            if dailySpendingData.isEmpty {
                Text("No expenses recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    // Budget ceiling line
                    RuleMark(y: .value("Budget", monthlyIncome))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(.green.opacity(0.7))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Budget")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                    // Cumulative area
                    ForEach(dailySpendingData, id: \.day) { point in
                        AreaMark(
                            x: .value("Day", point.day),
                            y: .value("Spent", point.cumulative)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [progressColor.opacity(0.4), progressColor.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Spent", point.cumulative)
                        )
                        .foregroundStyle(progressColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...(monthlyIncome * 1.1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let day = value.as(Int.self) {
                                Text("D\(day)").font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses by category")
                .font(.headline)

            if expensesByCategory.isEmpty {
                Text("No expenses yet this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(expensesByCategory, id: \.category) { item in
                    let ratio = monthlyIncome > 0 ? item.total / monthlyIncome : 0
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: item.category.icon)
                                .frame(width: 20)
                                .foregroundStyle(.secondary)
                            Text(item.category.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text(item.total, format: .currency(code: "EUR"))
                                .font(.subheadline).fontWeight(.medium)
                            Text("(\(Int(ratio * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.7))
                                    .frame(width: geo.size.width * min(ratio, 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var editBudgetSheet: some View {
        NavigationStack {
            Form {
                Section("Monthly income") {
                    HStack {
                        Text("€")
                            .foregroundStyle(.secondary)
                        TextField("e.g. 2500", text: $incomeInput)
                            .keyboardType(.decimalPad)
                    }
                }
                Section {
                    Text("This sets your spending baseline for the current month. You can update it any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingEditBudget = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBudget() }
                        .fontWeight(.semibold)
                        .disabled(Double(incomeInput.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveBudget() {
        let value = Double(incomeInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard value > 0 else { return }

        if let existing = currentBudget {
            existing.monthlyIncome = value
        } else {
            let budget = Budget(monthlyIncome: value)
            modelContext.insert(budget)
        }
        showingEditBudget = false
    }
}
