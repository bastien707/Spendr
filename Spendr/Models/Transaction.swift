import Foundation
import SwiftData
import SwiftUI

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
        case .food:          return SFSymbol.Category.food
        case .transport:     return SFSymbol.Category.transport
        case .housing:       return SFSymbol.Category.housing
        case .health:        return SFSymbol.Category.health
        case .entertainment: return SFSymbol.Category.entertainment
        case .shopping:      return SFSymbol.Category.shopping
        case .salary:        return SFSymbol.Category.salary
        case .freelance:     return SFSymbol.Category.freelance
        case .other:         return SFSymbol.Category.other
        }
    }

    var color: Color {
        switch self {
        case .food:          return .orange
        case .transport:     return .blue
        case .housing:       return .purple
        case .health:        return .red
        case .entertainment: return .pink
        case .shopping:      return .teal
        case .salary:        return .green
        case .freelance:     return .indigo
        case .other:         return .gray
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
