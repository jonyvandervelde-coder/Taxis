//
//  SupabaseTransactionRepository.swift
//  TaxÍs
//
//  Persists ExtractedTransaction results to the `transactions` table
//  (taxis_schema.sql) over Supabase's PostgREST API. Every request carries
//  the signed-in user's session access token, so Postgres RLS
//  (auth.uid() = user_id, see taxis_schema.sql) is the actual boundary —
//  this class never assumes access beyond what RLS already grants.
//

import Foundation

enum TransactionRepositoryError: LocalizedError {
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String)
    case emptyResponseBody
    case invalidUserID

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "The server returned a non-HTTP response."
        case .httpError(let statusCode, let body):
            return "Supabase returned HTTP \(statusCode): \(body)"
        case .emptyResponseBody:
            return "Expected a transaction row in the response body but got none."
        case .invalidUserID:
            return "Could not determine the signed-in user's ID from the session token."
        }
    }
}

final class SupabaseTransactionRepository {

    static let shared = SupabaseTransactionRepository()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Public API

    /// Inserts a freshly extracted transaction and returns the persisted
    /// row (with its DB-assigned `id`/`created_at`/`updated_at`). Defaults
    /// to `pending_review`; pass `.confirmed` if the caller already
    /// obtained user confirmation before saving (e.g. auto-confirmed
    /// high-confidence extractions per
    /// ReceiptExtractionService.requiresManualReview).
    func save(
        _ extraction: ExtractedTransaction,
        originalTextHash: String?,
        aiModel: String,
        aiRawResponse: [String: Any],
        status: ExtractionStatus = .pendingReview
    ) async throws -> TransactionRecord {
        let userId = try currentUserId()
        let record = TransactionRecord.pendingRecord(
            userId: userId,
            extraction: extraction,
            originalTextHash: originalTextHash,
            aiModel: aiModel,
            aiRawResponse: aiRawResponse,
            status: status
        )

        let url = try SupabaseConfig.restURL.appendingPathComponent("transactions")
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: record.asInsertPayload(), options: [])

        let data = try await send(request)
        return try firstRow(from: data)
    }

    /// Fetches the signed-in user's transactions, optionally filtered by
    /// status, most recent transaction date first.
    func fetchTransactions(status: ExtractionStatus? = nil) async throws -> [TransactionRecord] {
        guard var components = URLComponents(
            url: try SupabaseConfig.restURL.appendingPathComponent("transactions"),
            resolvingAgainstBaseURL: false
        ) else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        var queryItems = [URLQueryItem(name: "order", value: "transaction_date.desc")]
        if let status {
            queryItems.append(URLQueryItem(name: "extraction_status", value: "eq.\(status.rawValue)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        let request = try authorizedRequest(url: url, method: "GET")
        let data = try await send(request)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return try rows.map { try TransactionRecord(fromPostgRESTRow: $0) }
    }

    /// Marks a transaction confirmed or rejected by the user, stamping
    /// `confirmed_at` when moving to `.confirmed`.
    func updateStatus(id: UUID, to status: ExtractionStatus) async throws -> TransactionRecord {
        guard var components = URLComponents(
            url: try SupabaseConfig.restURL.appendingPathComponent("transactions"),
            resolvingAgainstBaseURL: false
        ) else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]

        guard let url = components.url else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        var request = try authorizedRequest(url: url, method: "PATCH")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        var payload: [String: Any] = ["extraction_status": status.rawValue]
        if status == .confirmed {
            payload["confirmed_at"] = ISO8601DateFormatter().string(from: Date())
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let data = try await send(request)
        return try firstRow(from: data)
    }

    /// Permanently deletes a transaction by ID. The server's RLS policy
    /// ensures a user can only delete their own rows.
    func delete(id: UUID) async throws {
        guard var components = URLComponents(
            url: try SupabaseConfig.restURL.appendingPathComponent("transactions"),
            resolvingAgainstBaseURL: false
        ) else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]

        guard let url = components.url else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        let request = try authorizedRequest(url: url, method: "DELETE")
        _ = try await send(request)
    }

    // MARK: - Request helpers

    private func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        let accessToken = try SupabaseSession.currentAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransactionRepositoryError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw TransactionRepositoryError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
        return data
    }

    private func firstRow(from data: Data) throws -> TransactionRecord {
        guard
            let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = rows.first
        else {
            throw TransactionRepositoryError.emptyResponseBody
        }
        return try TransactionRecord(fromPostgRESTRow: first)
    }

    /// Derives the signed-in user's ID from the JWT access token's `sub`
    /// claim (unverified — this is only used to satisfy `user_id`'s
    /// not-null constraint on insert; Postgres RLS, which independently
    /// re-derives `auth.uid()` from the verified token server-side, is the
    /// actual enforcement boundary).
    private func currentUserId() throws -> UUID {
        let token = try SupabaseSession.currentAccessToken()
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else {
            throw TransactionRepositoryError.invalidUserID
        }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard
            let payloadData = Data(base64Encoded: base64),
            let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let sub = payload["sub"] as? String,
            let userId = UUID(uuidString: sub)
        else {
            throw TransactionRepositoryError.invalidUserID
        }
        return userId
    }
}
