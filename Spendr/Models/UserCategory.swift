import Foundation
import SwiftData
import SwiftUI

@Model
final class UserCategory {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""
    var colorHex: String = "#8E8E93"
    var type: TransactionType = TransactionType.expense
    var isDefault: Bool = false
    var sortOrder: Int = 0

    @Relationship(inverse: \Transaction.userCategory)
    var transactions: [Transaction]? = []

    @Relationship(inverse: \CategoryBudget.userCategory)
    var budgets: [CategoryBudget]? = []

    init(
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
