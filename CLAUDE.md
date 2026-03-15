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

## Swift & SwiftUI Code Conventions

These rules are **mandatory**. Always follow them when reading, writing, or modifying any Swift file in this project.

### A — Property Declaration Order

Inside every `View` struct, always declare properties in this exact order:

```swift
struct MyView: View {
    // 1. @Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 2. @Query
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    // 3. @State
    @State private var showingAddTransaction = false
    @State private var searchText = ""

    // 4. Private computed properties (last)
    private var filtered: [Transaction] { ... }
    private var isValid: Bool { ... }
}
```

### B — View Decomposition

- `body` must only orchestrate layout — no inline logic, no long chains of closures
- Extract subviews as `private var name: some View { ... }`
- Parameterized subviews use `private func name(...) -> some View { ... }`
- If a subview is used in **more than one file**, move it to `DesignSystem.swift`
- Never create a new `.swift` file for a subview used in only one place

```swift
// CORRECT
var body: some View {
    VStack {
        balanceCard
        recentTransactions
    }
}

private var balanceCard: some View {
    // implementation here
}

// WRONG — complex logic inline in body
var body: some View {
    VStack {
        VStack {
            Text(transactions.reduce(0) { $0 + $1.amount }.formatted(.currency(code: "EUR")))
            // ... 20 more lines
        }
    }
}
```

### C — SwiftUI Modifier Ordering

Apply modifiers in this order on any view:

```swift
SomeView()
    // 1. Layout
    .frame(maxWidth: .infinity)
    .padding(.horizontal, DS.Spacing.md)
    // 2. Appearance
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    .foregroundStyle(.primary)
    // 3. Typography
    .font(.headline)
    .fontWeight(.semibold)
    // 4. Interaction
    .onTapGesture { ... }
    .onChange(of: value) { ... }
    .swipeActions { ... }
    // 5. Presentation
    .sheet(isPresented: $showingSheet) { ... }
    .toolbar { ... }
    .navigationTitle("Title")
```

### D — Naming Conventions

| Pattern | Rule | Examples |
|---|---|---|
| Bool state | `isXxx` | `isEditing`, `isValid`, `isEmpty` |
| Bool presentation | `showingXxx` | `showingAddTransaction`, `showingDeleteAlert` |
| `@Query` collections | Plural noun | `transactions`, `categoryBudgets` |
| Computed aggregates | Descriptive noun | `monthTransactions`, `totalIncome`, `filtered` |
| Action functions | Imperative verb | `save()`, `deleteItems()`, `resetForm()` |
| View helper functions | Verb phrase with label | `spent(for:)`, `progressColor(for:)` |
| Types & Enums | PascalCase | `TransactionType`, `CategoryBudget` |
| Design system enums | Short PascalCase | `DS`, `SFSymbol` |

### E — Access Control

Always apply the most restrictive access level possible:

- `@State`, `@Environment`, `@Query` → always `private`
- Subview computed properties → always `private var`
- Helper functions inside a view → always `private func`
- `@Model` properties → **no modifier** (SwiftData requires implicit internal access for persistence)
- `@Observable` ViewModel properties → no modifier (internal, intentional public surface)

```swift
// CORRECT
@Environment(\.modelContext) private var modelContext
@State private var isEditing = false
private var summaryCard: some View { ... }
private func save() { ... }

// WRONG
@State var isEditing = false          // missing private
var summaryCard: some View { ... }    // missing private
```

### F — SwiftData Patterns

```swift
// READ — always via @Query at view level, never inside ViewModel
@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

// WRITE — insert and delete only, never mutate arrays
modelContext.insert(newTransaction)
modelContext.delete(transaction)

// FILTER — prefer @Query predicate over Array.filter for large datasets
@Query(filter: #Predicate<Transaction> { $0.type == .expense })
private var expenses: [Transaction]
```

Rules:
- `@Query` is declared at the **view level only** — never inside a ViewModel or helper
- One `ModelContainer` in `SpendrApp.swift` — never instantiate another
- Never call `try? modelContext.save()` manually — SwiftData auto-saves

### G — No Business Logic in Views

| Logic type | Where it lives |
|---|---|
| Date arithmetic, month boundaries | `Calendar` extensions (`CategoryBudget.swift`) |
| Aggregates (totals, grouping, balance) | `TransactionViewModel` |
| Filtering beyond simple `@Query` | ViewModel computed property |
| Currency / date formatting | Inline `.formatted()` call in view (acceptable) |
| Form validation | `private var isValid: Bool` computed property in the view |

Views only **display** data — they never compute derived business values from scratch.

### H — MARK Section Structure

Every View file must use these MARK comments in this order:

```swift
struct MyView: View {

    // ... properties ...

    // MARK: - Body
    var body: some View { ... }

    // MARK: - Subviews
    private var subviewName: some View { ... }

    // MARK: - Helpers
    private func helperName() { ... }
}
```

Omit a section only if it has zero content. `// MARK: - Body` is always required.

### I — Anti-Patterns

Never do any of the following:

| Anti-pattern | Correct alternative |
|---|---|
| Hardcoded color literal (`.red`, `Color(hex:)`) | `category.color` or a semantic system color |
| Hardcoded SF Symbol string (`"plus.circle.fill"`) | `SFSymbol.add` from the catalog |
| Hardcoded spacing number (`.padding(16)`) | `DS.Spacing.md` |
| Hardcoded corner radius (`.cornerRadius(12)`) | `DS.Radius.sm` |
| `Core Data` (`NSManagedObject`, `NSFetchRequest`) | SwiftData (`@Model`, `@Query`) |
| `UserDefaults` for model data | SwiftData |
| `DispatchQueue.main.async { }` | SwiftUI/SwiftData dispatch automatically |
| Force-unwrap `someOptional!` | `guard let`, `if let`, or `?? defaultValue` |
| `AnyView(...)` type erasure | `@ViewBuilder` or `Group { if ... }` |
| Third-party dependency for built-in capability | Apple framework (Charts, SwiftData, etc.) |

### J — Git & Branching (Trunk-Based Development)

This project uses **trunk-based development**. The rules are:

- `main` is the single long-lived branch — it must always be in a deployable state
- All work happens on short-lived branches cut from `main`: `claude/<feature>` or `kebab-case-feature`
- Branches are merged to `main` via PR — **never commit directly to `main`**
- CI (build + test) must pass before any merge
- Delete the feature branch immediately after merging
- No long-lived `dev`, `staging`, `release`, or `hotfix` branches

**Commit message format** — conventional commits, imperative present tense:

```
feat: add spending chart to dashboard
fix: correct budget progress bar threshold
docs: update CLAUDE.md with SwiftData patterns
refactor: extract CategoryIcon into DesignSystem
test: add unit tests for TransactionViewModel
chore: update Xcode project settings
```

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

## Build Verification (Mandatory)

After **every code change** (new files, modified files, refactors), you **must**:

1. Build the project:
   ```bash
   xcodebuild build \
     -project Spendr.xcodeproj \
     -scheme Spendr \
     -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
     CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
   ```
2. If the build **fails**, read the error output, identify the root cause, and fix it immediately
3. Repeat until the build succeeds — do not consider a task complete until it compiles

---

## Hard Constraints

These are absolute limits regardless of context:

- **iOS 17+ only** — the app uses SwiftData and modern SwiftUI APIs; never lower the deployment target
- **No network layer** — the app is intentionally offline-only; do not add URLSession, Alamofire, or any HTTP client without explicit discussion
- **No third-party packages** — all needed frameworks (Charts, SwiftData, SwiftUI) are Apple built-ins
- **No `Codable` on `@Model` classes** — SwiftData manages serialization; adding `Codable` causes conflicts
