import Foundation
import SwiftData

// MARK: - DTOs (Data Transfer Objects for Supabase REST API)
// These are separate from @Model classes to avoid Codable conflicts.

private struct TransactionDTO: Codable {
    var id: String
    var userId: String
    var title: String
    var amount: Double
    var type: String
    var categoryName: String
    var date: Date
    var note: String

    enum CodingKeys: String, CodingKey {
        case id, title, amount, type, date, note
        case userId       = "user_id"
        case categoryName = "category"
    }

    init(from transaction: Transaction, userID: String) {
        self.id           = transaction.id.uuidString.lowercased()
        self.userId       = userID
        self.title        = transaction.title
        self.amount       = transaction.amount
        self.type         = transaction.type.rawValue
        self.categoryName = transaction.userCategory?.name ?? ""
        self.date         = transaction.date
        self.note         = transaction.note
    }
}

private struct BudgetDTO: Codable {
    var id: String
    var userId: String
    var categoryName: String
    var monthlyLimit: Double
    var month: Date

    enum CodingKeys: String, CodingKey {
        case id, month
        case userId       = "user_id"
        case categoryName = "category"
        case monthlyLimit = "monthly_limit"
    }

    init(from budget: CategoryBudget, userID: String) {
        self.id           = budget.id.uuidString.lowercased()
        self.userId       = userID
        self.categoryName = budget.userCategory?.name ?? ""
        self.monthlyLimit = budget.monthlyLimit
        self.month        = budget.month
    }
}

// MARK: - Service

@Observable
final class SyncService {
    private(set) var isSyncing = false
    private(set) var lastSyncError: String?

    private let context: ModelContext
    private let authService: AuthService
    private let client = SupabaseClient.shared

    init(context: ModelContext, authService: AuthService) {
        self.context     = context
        self.authService = authService
    }

    // MARK: - Main sync (push pending local changes)

    func sync() async {
        guard authService.isAuthenticated, !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            try await authService.refreshIfNeeded()
            try await pushPendingTransactions()
            try await pushPendingBudgets()
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Initial load after login (wipe local data, pull all from Supabase)

    func wipeAndPullAll() async {
        guard let session = authService.session else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            try context.delete(model: Transaction.self)
            try context.delete(model: CategoryBudget.self)
            try await pullTransactions(session: session)
            try await pullBudgets(session: session)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Wipe local data on logout

    func wipeLocalData() {
        try? context.delete(model: Transaction.self)
        try? context.delete(model: CategoryBudget.self)
    }

    // MARK: - Remote deletes (called before modelContext.delete in views)

    func deleteTransaction(id: UUID) async {
        guard let session = authService.session else { return }
        try? await client.restDelete(
            table: "transactions",
            accessToken: session.accessToken,
            filter: "id=eq.\(id.uuidString.lowercased())"
        )
    }

    func deleteBudget(id: UUID) async {
        guard let session = authService.session else { return }
        try? await client.restDelete(
            table: "category_budgets",
            accessToken: session.accessToken,
            filter: "id=eq.\(id.uuidString.lowercased())"
        )
    }

    // MARK: - Push

    private func pushPendingTransactions() async throws {
        guard let session = authService.session else { return }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let pending = try context.fetch(descriptor)
        guard !pending.isEmpty else { return }

        let dtos = pending.map { TransactionDTO(from: $0, userID: session.userID) }
        let body = try client.encoder.encode(dtos)
        try await client.restUpsert(
            table: "transactions",
            accessToken: session.accessToken,
            conflictColumn: "id",
            body: body
        )
        pending.forEach { $0.needsSync = false }
    }

    private func pushPendingBudgets() async throws {
        guard let session = authService.session else { return }
        let descriptor = FetchDescriptor<CategoryBudget>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let pending = try context.fetch(descriptor)
        guard !pending.isEmpty else { return }

        let dtos = pending.map { BudgetDTO(from: $0, userID: session.userID) }
        let body = try client.encoder.encode(dtos)
        try await client.restUpsert(
            table: "category_budgets",
            accessToken: session.accessToken,
            conflictColumn: "id",
            body: body
        )
        pending.forEach { $0.needsSync = false }
    }

    // MARK: - Pull

    private func pullTransactions(session: AuthSession) async throws {
        let dtos: [TransactionDTO] = try await client.restFetch(
            table: "transactions",
            accessToken: session.accessToken,
            filter: "user_id=eq.\(session.userID)&order=date.desc"
        )
        let allCategories = try context.fetch(FetchDescriptor<UserCategory>())

        for dto in dtos {
            guard
                let uuid = UUID(uuidString: dto.id),
                let type = TransactionType(rawValue: dto.type)
            else { continue }

            let cat = allCategories.first { $0.name == dto.categoryName }
            let t = Transaction(
                title: dto.title,
                amount: dto.amount,
                type: type,
                category: cat ?? allCategories.first(where: { $0.name == "Other" }) ?? allCategories[0],
                date: dto.date,
                note: dto.note
            )
            t.id        = uuid
            t.ownerID   = dto.userId
            t.needsSync = false
            context.insert(t)
        }
    }

    private func pullBudgets(session: AuthSession) async throws {
        let dtos: [BudgetDTO] = try await client.restFetch(
            table: "category_budgets",
            accessToken: session.accessToken,
            filter: "user_id=eq.\(session.userID)"
        )
        let allCategories = try context.fetch(FetchDescriptor<UserCategory>())

        for dto in dtos {
            guard
                let uuid = UUID(uuidString: dto.id),
                let cat  = allCategories.first(where: { $0.name == dto.categoryName })
            else { continue }

            let b = CategoryBudget(
                category: cat,
                monthlyLimit: dto.monthlyLimit,
                month: dto.month
            )
            b.id        = uuid
            b.ownerID   = dto.userId
            b.needsSync = false
            context.insert(b)
        }
    }
}
