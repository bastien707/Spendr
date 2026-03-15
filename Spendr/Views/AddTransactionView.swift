import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCategory.sortOrder) private var allCategories: [UserCategory]

    @State private var title = ""
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: UserCategory?
    @State private var date = Date()
    @State private var note = ""

    private var availableCategories: [UserCategory] {
        allCategories.filter { $0.type == type }
    }

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isValid: Bool {
        !title.isEmpty && amount > 0 && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) {
                        if let sel = selectedCategory, sel.type != type {
                            selectedCategory = availableCategories.first
                        }
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(availableCategories) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(Optional(cat))
                        }
                    }
                }

                Section("Date & Note") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = availableCategories.first
                }
            }
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

    private func save() {
        guard let selectedCategory else { return }
        let transaction = Transaction(
            title: title,
            amount: amount,
            type: type,
            category: selectedCategory,
            date: date,
            note: note
        )
        modelContext.insert(transaction)
        dismiss()
    }
}
