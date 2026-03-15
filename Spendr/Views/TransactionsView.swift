import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddTransaction = false
    @State private var selectedFilter: TransactionType? = nil
    @State private var searchText = ""

    private var filtered: [Transaction] {
        transactions.filter { t in
            let matchesType = selectedFilter == nil || t.type == selectedFilter
            let matchesSearch = searchText.isEmpty || t.title.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("Add your first transaction with the + button.")
                    )
                } else {
                    List {
                        ForEach(groupedByDate, id: \.0) { date, items in
                            Section(header: Text(date, style: .date).font(.subheadline)) {
                                ForEach(items) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete { indexSet in
                                    deleteItems(items: items, at: indexSet)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
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

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            Text("All").tag(Optional<TransactionType>.none)
            Text("Income").tag(Optional<TransactionType>.some(.income))
            Text("Expenses").tag(Optional<TransactionType>.some(.expense))
        }
        .pickerStyle(.segmented)
    }

    private var groupedByDate: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func deleteItems(items: [Transaction], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}
