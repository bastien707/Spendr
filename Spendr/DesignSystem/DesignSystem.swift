import SwiftUI

// MARK: - SF Symbols catalog
// Single source of truth for every icon used in the app.
// Never hardcode "systemName" strings in views — always use SFSymbol.x

enum SFSymbol {

    // MARK: Actions
    static let add      = "plus.circle.fill"
    static let edit     = "pencil"
    static let delete   = "trash.fill"
    static let close    = "xmark"
    static let settings = "slider.horizontal.3"

    // MARK: Tab bar
    static let dashboard     = "chart.pie.fill"
    static let transactions  = "list.bullet.rectangle.fill"
    static let budget        = "target"

    // MARK: Transaction types
    static let income  = "arrow.down.left.circle.fill"
    static let expense = "arrow.up.right.circle.fill"

    // MARK: Categories
    enum Category {
        static let food          = "fork.knife"
        static let transport     = "car.fill"
        static let housing       = "house.fill"
        static let health        = "cross.case.fill"
        static let entertainment = "popcorn.fill"
        static let shopping      = "cart.fill"
        static let salary        = "banknote.fill"
        static let freelance     = "laptopcomputer"
        static let other         = "square.grid.2x2.fill"
    }

    // MARK: States
    static let empty       = "tray.fill"
    static let warning     = "exclamationmark.triangle.fill"
    static let success     = "checkmark.circle.fill"
    static let overBudget  = "exclamationmark.circle.fill"
}

// MARK: - Design tokens

enum DS {

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
    }

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
    }

    enum IconSize {
        static let sm: CGFloat = 36
        static let md: CGFloat = 44
        static let lg: CGFloat = 60
    }
}

// MARK: - ViewModifiers

struct CardStyle: ViewModifier {
    var radius: CGFloat = DS.Radius.lg
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - View extensions

extension View {
    func cardStyle(radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(CardStyle(radius: radius))
    }
}

// MARK: - Reusable components

/// Circular icon badge used consistently across category rows and cards.
struct CategoryIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = DS.IconSize.md

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.38))
                .foregroundStyle(color)
        }
    }
}

/// Signed currency text: green + for income, default color – for expenses.
struct AmountLabel: View {
    let amount: Double
    let type: TransactionType
    var font: Font = .subheadline
    var currencyCode: String = "EUR"

    var body: some View {
        Text("\(type == .income ? "+" : "-")\(amount, format: .currency(code: currencyCode))")
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(type == .income ? Color.green : Color.primary)
    }
}

/// Section header with consistent style.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, DS.Spacing.xs)
    }
}

/// Reusable empty / unavailable state.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.lg))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2).fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxHeight: .infinity)
    }
}

/// Animated progress bar with green/orange/red threshold colors.
struct BudgetProgressBar: View {
    let ratio: Double           // 0.0 → 1.0+
    var height: CGFloat = 8

    var color: Color {
        switch ratio {
        case ..<0.6:  return .green
        case ..<0.85: return .orange
        default:      return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(ratio, 1.0), height: height)
                    .animation(.easeInOut(duration: 0.5), value: ratio)
            }
        }
        .frame(height: height)
    }
}
