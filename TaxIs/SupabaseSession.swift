//
//  SupabaseSession.swift
//  TaxÍs
//
//  Single source of truth for the current Supabase session access token,
//  shared by ReceiptExtractionService (calls the receipt-extraction Edge
//  Function) and SupabaseTransactionRepository (calls PostgREST directly).
//  Both need the same short-lived, revocable token — see the security
//  note in ReceiptExtractionService.swift. Wire `store(accessToken:)` to
//  fire whenever your Supabase auth flow (magic link, OAuth, etc.) issues
//  or refreshes a session.
//

import Foundation

enum SupabaseSessionError: LocalizedError {
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "No Supabase session found in the Keychain. Sign in, then call SupabaseSession.store(accessToken:) with the resulting session token."
        }
    }
}

enum SupabaseSession {
    private static let keychainAccount = "com.taxis.supabase-access-token"

    /// Call after a successful sign-in (or token refresh) to persist the
    /// session's access token for use by authenticated API calls.
    static func store(accessToken: String) throws {
        try KeychainHelper.shared.save(accessToken, forAccount: keychainAccount)
    }

    /// Call on sign-out.
    static func clear() throws {
        try KeychainHelper.shared.delete(forAccount: keychainAccount)
    }

    static func currentAccessToken() throws -> String {
        guard let token = try KeychainHelper.shared.read(forAccount: keychainAccount) else {
            throw SupabaseSessionError.missingAccessToken
        }
        return token
    }
}
