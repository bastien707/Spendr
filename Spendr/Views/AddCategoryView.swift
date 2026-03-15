import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: UserCategory?

    @State private var name = ""
    @State private var selectedIcon = SFSymbol.categoryPickerIcons[0]
    @State private var selectedColorHex = DS.categoryColorPalette[0]
    @State private var type: TransactionType = .expense

    private var isEditing: Bool { editing != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DS.Spacing.sm) {
                        ForEach(SFSymbol.categoryPickerIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIcon == icon
                                        ? Color(hex: selectedColorHex).opacity(0.2)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .stroke(selectedIcon == icon ? Color(hex: selectedColorHex) : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: DS.Spacing.sm) {
                        ForEach(DS.categoryColorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedColorHex == hex {
                                        Image(systemName: SFSymbol.success)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }

                Section("Preview") {
                    HStack(spacing: DS.Spacing.sm) {
                        CategoryIcon(
                            systemName: selectedIcon,
                            color: Color(hex: selectedColorHex),
                            size: DS.IconSize.md
                        )
                        Text(name.isEmpty ? "Category name" : name)
                            .font(.subheadline)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadEditingState() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func loadEditingState() {
        guard let editing else { return }
        name = editing.name
        selectedIcon = editing.icon
        selectedColorHex = editing.colorHex
        type = editing.type
    }

    private func save() {
        if let editing {
            editing.name = name
            editing.icon = selectedIcon
            editing.colorHex = selectedColorHex
            editing.type = type
        } else {
            let cat = UserCategory(
                name: name,
                icon: selectedIcon,
                colorHex: selectedColorHex,
                type: type
            )
            modelContext.insert(cat)
        }
        dismiss()
    }
}
