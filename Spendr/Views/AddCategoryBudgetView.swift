import SwiftUI
import SwiftData

struct AddCategoryBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    var availableCategories: [UserCategory] = []
    var editingBudget: CategoryBudget? = nil

    @State private var selectedCategory: UserCategory?
    @State private var limitText: String = ""

    private var isEditing: Bool { editingBudget != nil }

    private var limit: Double {
        Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isValid: Bool {
        limit > 0 && (isEditing || selectedCategory != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isEditing, let budget = editingBudget {
                    Section("Category") {
                        Label(budget.categoryName, systemImage: budget.categoryIcon)
                            .foregroundStyle(.primary)
                    }
                } else {
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(availableCategories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(Optional(cat))
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }

                Section("Monthly limit") {
                    HStack {
                        Text("€").foregroundStyle(.secondary)
                        TextField("e.g. 300", text: $limitText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Text("Expenses in this category will count against this monthly limit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let budget = editingBudget {
                    limitText = String(budget.monthlyLimit)
                } else {
                    selectedCategory = availableCategories.first
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
            budget.needsSync = true
        } else if let selectedCategory {
            let newBudget = CategoryBudget(category: selectedCategory, monthlyLimit: limit)
            modelContext.insert(newBudget)
        }
        Task { await syncService.sync() }
        dismiss()
    }
}
