//
//  SupabaseAuthService.swift
//  TaxÍs
//
//  Email/password, Apple Sign In, and Google OAuth (via Supabase) auth.
//  All methods store the resulting access token via SupabaseSession so
//  every other service can read it from Keychain.
//

import Foundation
import AuthenticationServices
import CryptoKit

enum SupabaseAuthError: LocalizedError {
    case invalidResponse
    case authFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .authFailed(let message):
            return message
        case .cancelled:
            return "Innskráningu hætt við."
        }
    }
}

final class SupabaseAuthService: NSObject {
    static let shared = SupabaseAuthService()

    private let session: URLSession
    private var webAuthSession: ASWebAuthenticationSession?

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Email / password

    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        try await sendCredentials(path: "signup", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await sendCredentials(
            path: "token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            email: email,
            password: password
        )
    }

    // MARK: - Apple Sign In

    func signInWithApple(identityToken: String, nonce: String) async throws {
        let authURL = try SupabaseConfig.projectURL
            .appendingPathComponent("auth/v1/token")
        guard var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let url = components.url else { throw SupabaseAuthError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "apple",
            "id_token": identityToken,
            "nonce": nonce,
        ])

        let (data, response) = try await session.data(for: request)
        try handleAuthResponse(data: data, response: response)
    }

    // MARK: - Google OAuth (Supabase redirect)

    @MainActor
    func signInWithGoogle() async throws {
        let baseURL = try SupabaseConfig.projectURL
        let authURL = baseURL.appendingPathComponent("auth/v1/authorize")
        guard var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: "taxis://auth/callback"),
        ]
        guard let url = components.url else { throw SupabaseAuthError.invalidResponse }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "taxis"
            ) { result, error in
                if let error = error {
                    let asError = error as? ASWebAuthenticationSessionError
                    if asError?.code == .canceledLogin {
                        continuation.resume(throwing: SupabaseAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: SupabaseAuthError.invalidResponse)
                }
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = webSession
            webSession.start()
        }

        try extractAndStoreToken(from: callbackURL)
    }

    // MARK: - Forgot password

    /// Sends a password-reset email via Supabase Auth. On success the user
    /// receives a magic link; on tap it opens the app via the taxis:// scheme.
    func resetPassword(email: String) async throws {
        let url = try SupabaseConfig.projectURL.appendingPathComponent("auth/v1/recover")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "redirect_to": "taxis://auth/reset-password",
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = (json["msg"] as? String)
                ?? (json["error_description"] as? String)
                ?? (json["error"] as? String)
                ?? "Tókst ekki að senda endursetningarpóst."
            throw SupabaseAuthError.authFailed(message)
        }
    }

    // MARK: - Delete account

    func deleteAccount() async throws {
        let authURL = try SupabaseConfig.projectURL
            .appendingPathComponent("auth/v1/user")
        guard let accessToken = try? SupabaseSession.currentAccessToken() else {
            throw SupabaseAuthError.invalidResponse
        }

        var request = URLRequest(url: authURL)
        request.httpMethod = "DELETE"
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseAuthError.authFailed("Could not delete account.")
        }
    }

    // MARK: - OAuth callback handler

    func handleOAuthCallback(url: URL) {
        try? extractAndStoreToken(from: url)
    }

    // MARK: - Shared helpers

    @discardableResult
    private func sendCredentials(
        path: String,
        query: [URLQueryItem] = [],
        email: String,
        password: String
    ) async throws -> Bool {
        let authURL = try SupabaseConfig.projectURL.appendingPathComponent("auth/v1/\(path)")
        guard var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw SupabaseAuthError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        return try handleAuthResponse(data: data, response: response)
    }

    @discardableResult
    private func handleAuthResponse(data: Data, response: URLResponse) throws -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (json["msg"] as? String)
                ?? (json["error_description"] as? String)
                ?? (json["error"] as? String)
                ?? "Authentication failed (HTTP \(httpResponse.statusCode))."
            throw SupabaseAuthError.authFailed(message)
        }

        guard let accessToken = json["access_token"] as? String else { return false }
        let refreshToken = json["refresh_token"] as? String
        try SupabaseSession.store(accessToken: accessToken, refreshToken: refreshToken)

        if let userDict = json["user"] as? [String: Any],
           let email = userDict["email"] as? String {
            UserDefaults.standard.set(email, forKey: "taxis.profile.email")
        }
        return true
    }

    private func extractAndStoreToken(from url: URL) throws {
        guard let fragment = url.fragment else {
            // Try query params (some providers use ?access_token=)
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let token = components.queryItems?.first(where: { $0.name == "access_token" })?.value else {
                throw SupabaseAuthError.invalidResponse
            }
            try SupabaseSession.store(accessToken: token)
            return
        }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { params[String(parts[0])] = String(parts[1]) }
        }
        guard let token = params["access_token"] else { throw SupabaseAuthError.invalidResponse }
        try SupabaseSession.store(accessToken: token)
    }
}

// MARK: - Presentation context for ASWebAuthenticationSession

extension SupabaseAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

// MARK: - Nonce utilities (Apple Sign In)

extension SupabaseAuthService {
    static func generateNonce(length: Int = 32) -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            bytes.forEach { b in
                guard remaining > 0 else { return }
                if b < charset.count {
                    result.append(charset[charset.index(charset.startIndex, offsetBy: Int(b))])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
