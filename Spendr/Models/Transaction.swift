import Foundation
import SwiftData
import SwiftUI

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"
}

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var type: TransactionType
    var userCategory: UserCategory?
    var date: Date
    var note: String

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
