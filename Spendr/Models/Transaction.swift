import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"
}

enum Category: String, Codable, CaseIterable {
    case food = "Food"
    case transport = "Transport"
    case housing = "Housing"
    case health = "Health"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case salary = "Salary"
    case freelance = "Freelance"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .housing: return "house.fill"
        case .health: return "heart.fill"
        case .entertainment: return "gamecontroller.fill"
        case .shopping: return "bag.fill"
        case .salary: return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var type: TransactionType {
        switch self {
        case .salary, .freelance: return .income
        default: return .expense
        }
    }
}

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var type: TransactionType
    var category: Category
    var date: Date
    var note: String

    init(
        title: String,
        amount: Double,
        type: TransactionType,
        category: Category,
        date: Date = .now,
        note: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
    }
}
