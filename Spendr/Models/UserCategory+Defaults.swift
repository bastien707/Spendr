import SwiftUI

// Nil-safe accessors for when a category gets deleted.
// Views use these instead of force-unwrapping the optional relationship.

extension Transaction {
    var categoryName: String  { userCategory?.name ?? "Uncategorized" }
    var categoryIcon: String  { userCategory?.icon ?? "questionmark.circle.fill" }
    var categoryColor: Color  { userCategory?.color ?? .gray }
}

extension CategoryBudget {
    var categoryName: String  { userCategory?.name ?? "Uncategorized" }
    var categoryIcon: String  { userCategory?.icon ?? "questionmark.circle.fill" }
    var categoryColor: Color  { userCategory?.color ?? .gray }
}
