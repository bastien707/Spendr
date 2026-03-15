import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var monthlyIncome: Double
    var month: Date // stored as start of month

    init(monthlyIncome: Double, month: Date = Date()) {
        self.id = UUID()
        self.monthlyIncome = monthlyIncome
        self.month = Calendar.current.startOfMonth(for: month)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
