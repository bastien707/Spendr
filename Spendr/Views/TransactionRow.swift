import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            CategoryIcon(
                systemName: transaction.categoryIcon,
                color: transaction.categoryColor,
                size: DS.IconSize.md
            )

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.categoryName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                AmountLabel(amount: transaction.amount, type: transaction.type)
                Text(transaction.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
