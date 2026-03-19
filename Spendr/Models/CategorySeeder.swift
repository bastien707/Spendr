import Foundation
import SwiftData

struct CategorySeeder {
    static func seedIfNeeded(context: ModelContext) {
        let key = "hasSeededCategories"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        // If CloudKit already synced categories from another device, skip seeding
        let count = (try? context.fetchCount(FetchDescriptor<UserCategory>())) ?? 0
        if count > 0 {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let defaults: [(String, String, String, TransactionType)] = [
            ("Food",          "fork.knife",          "#FF9500", .expense),
            ("Transport",     "car.fill",            "#007AFF", .expense),
            ("Housing",       "house.fill",          "#AF52DE", .expense),
            ("Health",        "cross.case.fill",     "#FF3B30", .expense),
            ("Entertainment", "popcorn.fill",        "#FF2D55", .expense),
            ("Shopping",      "cart.fill",           "#5AC8FA", .expense),
            ("Salary",        "banknote.fill",       "#34C759", .income),
            ("Freelance",     "laptopcomputer",      "#5856D6", .income),
            ("Other",         "square.grid.2x2.fill","#8E8E93", .expense),
        ]

        for (index, item) in defaults.enumerated() {
            let category = UserCategory(
                name: item.0,
                icon: item.1,
                colorHex: item.2,
                type: item.3,
                isDefault: true,
                sortOrder: index
            )
            context.insert(category)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
