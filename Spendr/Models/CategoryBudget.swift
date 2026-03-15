import Foundation
import SwiftData

@Model
final class CategoryBudget {
    var id: UUID
    var category: Category
    var monthlyLimit: Double
    var month: Date // start of month

    init(category: Category, monthlyLimit: Double, month: Date = Date()) {
        self.id = UUID()
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.month = Calendar.current.startOfMonth(for: month)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
