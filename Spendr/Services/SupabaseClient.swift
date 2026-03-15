import Foundation

// MARK: - Configuration
// Replace these with your actual Supabase project values.
// Found at: supabase.com → your project → Settings → API
enum SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"
    static let anonKey    = "YOUR_ANON_PUBLIC_KEY"
    // Must match the URL scheme registered in Xcode:
    //   TARGETS → Info → URL Types → add URL Scheme "spendr"
    static let redirectURL = "spendr://auth"
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case badURL
    case httpError(statusCode: Int, body: String)
    case noData
    case parseError

    var errorDescription: String? {
        switch self {
        case .badURL:                         return "Invalid Supabase URL — check SupabaseConfig."
        case .httpError(let code, let body):  return "HTTP \(code): \(body)"
        case .noData:                         return "No data received."
        case .parseError:                     return "Failed to parse authentication response."
        }
    }
}

// MARK: - Client

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL: String
    private let anonKey: String
    private let urlSession = URLSession.shared

    let decoder: JSONDecoder
    let encoder: JSONEncoder

    private init() {
        self.baseURL = SupabaseConfig.projectURL
        self.anonKey = SupabaseConfig.anonKey
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Auth requests

    func authRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        accessToken: String? = nil,
        body: Data? = nil
    ) async throws -> T {
        let data = try await rawRequest(
            urlString: "\(baseURL)/auth/v1\(path)",
            method: method,
            accessToken: accessToken,
            body: body
        )
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - REST (data) requests

    func restFetch<T: Decodable>(
        table: String,
        accessToken: String,
        filter: String = ""
    ) async throws -> T {
        let query = filter.isEmpty ? "" : "?\(filter)"
        let data = try await rawRequest(
            urlString: "\(baseURL)/rest/v1/\(table)\(query)",
            method: "GET",
            accessToken: accessToken,
            prefer: "return=representation"
        )
        return try decoder.decode(T.self, from: data)
    }

    func restUpsert(
        table: String,
        accessToken: String,
        conflictColumn: String,
        body: Data
    ) async throws {
        try await rawRequest(
            urlString: "\(baseURL)/rest/v1/\(table)?on_conflict=\(conflictColumn)",
            method: "POST",
            accessToken: accessToken,
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    func restDelete(
        table: String,
        accessToken: String,
        filter: String
    ) async throws {
        try await rawRequest(
            urlString: "\(baseURL)/rest/v1/\(table)?\(filter)",
            method: "DELETE",
            accessToken: accessToken,
            prefer: "return=minimal"
        )
    }

    // MARK: - Private

    @discardableResult
    private func rawRequest(
        urlString: String,
        method: String,
        accessToken: String? = nil,
        body: Data? = nil,
        prefer: String = "return=minimal"
    ) async throws -> Data {
        guard let url = URL(string: urlString) else { throw SupabaseError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(prefer, forHTTPHeaderField: "Prefer")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.noData }
        guard (200...299).contains(http.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.httpError(statusCode: http.statusCode, body: responseBody)
        }
        return data
    }
}
