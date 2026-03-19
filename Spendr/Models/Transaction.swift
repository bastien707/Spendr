import Foundation
import SwiftData
import SwiftUI

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"
}

@Model
final class Transaction {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0
    var type: TransactionType = TransactionType.expense
    var userCategory: UserCategory?
    var date: Date = Date()
    var note: String = ""

    init(
        title: String,
        amount: Double,
        type: TransactionType,
        category: UserCategory,
        date: Date = .now,
        note: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.type = type
        self.userCategory = category
        self.date = date
        self.note = note
    }
}
