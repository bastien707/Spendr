import SwiftUI
import SwiftData

struct AddCategoryBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // For adding a new budget
    var availableCategories: [Category] = []

    // For editing an existing budget
    var editingBudget: CategoryBudget? = nil

    @State private var selectedCategory: Category = .food
    @State private var limitText: String = ""

    private var isEditing: Bool { editingBudget != nil }

    private var limit: Double {
        Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isValid: Bool { limit > 0 }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing, let budget = editingBudget {
                    Section("Category") {
                        Label(budget.category.rawValue, systemImage: budget.category.icon)
                            .foregroundStyle(.primary)
                    }
                } else {
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(availableCategories, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }

                Section("Monthly limit") {
                    HStack {
                        Text("€")
                            .foregroundStyle(.secondary)
                        TextField("e.g. 300", text: $limitText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Text("Expenses in this category will count against this monthly limit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let budget = editingBudget {
                    limitText = String(budget.monthlyLimit)
                } else if let first = availableCategories.first {
                    selectedCategory = first
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let budget = editingBudget {
            budget.monthlyLimit = limit
        } else {
            let newBudget = CategoryBudget(
                category: selectedCategory,
                monthlyLimit: limit
            )
            modelContext.insert(newBudget)
        }
        dismiss()
    }
}
