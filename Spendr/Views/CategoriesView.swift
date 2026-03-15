import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddCategory = false
    @State private var categoryToEdit: UserCategory?

    private var expenseCategories: [UserCategory] {
        categories.filter { $0.type == .expense }
    }

    private var incomeCategories: [UserCategory] {
        categories.filter { $0.type == .income }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Expense") {
                    ForEach(expenseCategories) { cat in
                        CategoryManagementRow(category: cat)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryToEdit = cat }
                    }
                    .onDelete { offsets in
                        deleteCategories(from: expenseCategories, at: offsets)
                    }
                }

                Section("Income") {
                    ForEach(incomeCategories) { cat in
                        CategoryManagementRow(category: cat)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryToEdit = cat }
                    }
                    .onDelete { offsets in
                        deleteCategories(from: incomeCategories, at: offsets)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: SFSymbol.add)
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(item: $categoryToEdit) { cat in
                AddCategoryView(editing: cat)
            }
        }
    }

    private func deleteCategories(from list: [UserCategory], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

// MARK: - Row

struct CategoryManagementRow: View {
    let category: UserCategory

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            CategoryIcon(systemName: category.icon, color: category.color, size: DS.IconSize.sm)
            Text(category.name)
                .font(.subheadline)
            Spacer()
            if category.isDefault {
                Text("Default")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }
}
