import Foundation
import SwiftData

@Observable
class TransactionViewModel {
    var transactions: [Transaction] = []

    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var balance: Double {
        totalIncome - totalExpenses
    }

    var expensesByCategory: [(category: Category, total: Double)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func transactionsForCurrentMonth(from all: [Transaction]) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return all.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }
}
