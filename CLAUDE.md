# CLAUDE.md — Spendr Codebase Guide

This file provides AI assistants with everything needed to understand, navigate, and contribute to the Spendr iOS app.

---

## Project Overview

**Spendr** is a native iOS personal finance tracking app built with SwiftUI and SwiftData. It lets users log income/expense transactions, set monthly category budgets, and visualize spending patterns with charts.

- **Platform**: iOS 17+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Persistence**: SwiftData (local SQLite, no external API)
- **Charts**: Apple Charts framework
- **No package manager** (no CocoaPods, no SPM dependencies — all frameworks are Apple built-ins)

---

## Repository Structure

```
Spendr/
├── .github/
│   ├── workflows/ci.yml             # CI pipeline (build + test on push/PR)
│   └── pull_request_template.md     # PR checklist template
├── Spendr/                          # All source files
│   ├── SpendrApp.swift              # @main entry point; registers SwiftData models
│   ├── ContentView.swift            # Root TabView (Dashboard / Transactions / Budget)
│   ├── Models/
│   │   ├── Transaction.swift        # Transaction @Model + TransactionType + Category enums
│   │   └── CategoryBudget.swift     # CategoryBudget @Model + Calendar extension
│   ├── ViewModels/
│   │   └── TransactionViewModel.swift  # @Observable ViewModel with computed aggregates
│   ├── Views/
│   │   ├── DashboardView.swift      # Monthly summary + pie chart + recent transactions
│   │   ├── TransactionsView.swift   # Searchable, filterable, grouped transaction list
│   │   ├── BudgetView.swift         # Per-category monthly budget management
│   │   ├── AddTransactionView.swift # Form to create a transaction
│   │   ├── AddCategoryBudgetView.swift  # Form to create or edit a budget
│   │   └── TransactionRow.swift     # Reusable list row component
│   └── DesignSystem/
│       └── DesignSystem.swift       # All shared tokens, icons, and UI components
└── Spendr.xcodeproj/                # Xcode project (no manual edits needed)
```

---

## Data Models

### Transaction (`Spendr/Models/Transaction.swift`)

```swift
@Model final class Transaction {
    var id: UUID
    var title: String
    var amount: Double         // Always positive; sign is determined by `type`
    var type: TransactionType  // .income or .expense
    var category: Category
    var date: Date
    var note: String
}
```

### CategoryBudget (`Spendr/Models/CategoryBudget.swift`)

```swift
@Model final class CategoryBudget {
    var id: UUID
    var category: Category
    var monthlyLimit: Double
    var month: Date            // Stored as first day of the month (startOfMonth)
}
```

### Category Enum

Defined in `Transaction.swift`. Each case has:
- `icon: String` — SF Symbol name (via `SFSymbol` catalog in DesignSystem)
- `color: Color` — semantic color for that category
- `type: TransactionType` — `.expense` or `.income`

Expense categories: `.food`, `.transport`, `.housing`, `.health`, `.entertainment`, `.shopping`, `.other`
Income categories: `.salary`, `.freelance`

---

## Design System (`Spendr/DesignSystem/DesignSystem.swift`)

All shared UI primitives live here. **Always use these instead of hardcoding values.**

| Token | Values |
|---|---|
| `DS.Radius` | `.sm` (12), `.md` (16), `.lg` (20) |
| `DS.Spacing` | `.xs` (4), `.sm` (8), `.md` (16), `.lg` (20), `.xl` (24) |
| `DS.IconSize` | `.sm` (36), `.md` (44), `.lg` (60) |

### Reusable Components

| Component | Purpose |
|---|---|
| `CardStyle` | ViewModifier — `ultraThinMaterial` card background |
| `CategoryIcon` | Circular icon badge using category color |
| `AmountLabel` | Signed currency display (green `+` for income, red `-` for expense) |
| `SectionHeader` | Consistent section title text style |
| `EmptyStateView` | Unified empty state with optional CTA button |
| `BudgetProgressBar` | Animated progress bar; green <60%, orange 60–85%, red >85% |

### SFSymbol Catalog

Use `SFSymbol.<name>.rawValue` for all icon strings. Never hardcode SF Symbol strings outside the catalog.

---

## Key Patterns & Conventions

### SwiftData Usage

```swift
// Inject context
@Environment(\.modelContext) private var modelContext

// Reactive queries
@Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]

// Insert / delete
modelContext.insert(newItem)
modelContext.delete(item)
```

### ViewModel Pattern

`TransactionViewModel` is `@Observable`. It receives a `[Transaction]` array and exposes:
- `totalIncome`, `totalExpenses`, `balance`
- `expensesByCategory` — grouped dict sorted by total
- `transactionsForCurrentMonth()` — filters by calendar month

### Month Scoping

All budget and dashboard data is scoped to the **current calendar month** using `Calendar.current.startOfMonth(for:)` (extension on `Calendar` in `CategoryBudget.swift`).

### Form Validation

Views expose a computed `isValid: Bool` property. The Save/Add button is disabled when `!isValid`. Validation rules:
- Transaction: `title` non-empty AND `amount > 0`
- Budget: `monthlyLimit > 0`

### Currency

Currency is hardcoded to **EUR** throughout. Format amounts with:
```swift
amount.formatted(.currency(code: "EUR"))
```
For decimal text input, replace commas with periods before parsing:
```swift
Double(amountString.replacingOccurrences(of: ",", with: "."))
```

### View Decomposition

Large views use **private computed properties** to extract subviews (not separate files). Keep view files self-contained unless a component is shared across multiple views.

---

## Development Workflow

### Building & Running

Open `Spendr.xcodeproj` in Xcode. There is no CLI build wrapper — use Xcode directly.

For CI / scripted builds:
```bash
# Build
xcodebuild build \
  -project Spendr.xcodeproj \
  -scheme Spendr \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcpretty

# Test
xcodebuild test \
  -project Spendr.xcodeproj \
  -scheme Spendr \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcpretty
```

### CI/CD

Defined in `.github/workflows/ci.yml`. Runs on:
- Push to `main`
- Pull requests targeting `main`

Steps: checkout → select Xcode 15.4 → build → test (on macOS 14 runner, iPhone 15 simulator).

In-progress CI runs are cancelled automatically when a new push arrives on the same branch.

### Branching Strategy

- `main` is the protected trunk branch.
- Feature branches: `claude/<feature-name>` or descriptive kebab-case names.
- Open a PR against `main`; CI must pass before merging.

### Pull Requests

Use the template at `.github/pull_request_template.md`. Required sections:
- Summary of changes
- Testing checklist (simulator build, device test, regression)
- Screenshots for UI changes

---

## Adding New Features — Checklist

When adding a new feature, follow these steps in order:

1. **Model changes** → update or create `@Model` class in `Spendr/Models/`
2. **Register model** → add to `.modelContainer(for: [...])` in `SpendrApp.swift` if new
3. **ViewModel** → add computed properties to `TransactionViewModel` if aggregation logic is needed
4. **Design tokens** → add new icons to `SFSymbol` enum; add colors to `Category` or a new token
5. **Views** → build UI in `Spendr/Views/`; extract reusable pieces to `DesignSystem.swift`
6. **Tab bar** → add a new tab to `ContentView.swift` only if the feature is a top-level destination

---

## What NOT to Do

- Do not add third-party dependencies unless absolutely necessary; prefer Apple frameworks.
- Do not hardcode SF Symbol strings — always use `SFSymbol.<name>.rawValue`.
- Do not hardcode spacing, radius, or icon sizes — use `DS.Spacing`, `DS.Radius`, `DS.IconSize`.
- Do not use Core Data — this project uses SwiftData.
- Do not target iOS < 17 — the app uses SwiftData and modern SwiftUI APIs that require iOS 17+.
- Do not add a backend or network layer without explicit discussion; the app is intentionally offline-only.
- Do not add `Codable` conformance to SwiftData `@Model` classes without careful consideration (SwiftData manages serialization).
