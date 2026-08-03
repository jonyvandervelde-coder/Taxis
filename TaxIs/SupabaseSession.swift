import Foundation

enum SupabaseSessionError: LocalizedError {
    case missingAccessToken
    case missingRefreshToken
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:  return "No session found. Please sign in."
        case .missingRefreshToken: return "Session expired. Please sign in again."
        case .refreshFailed(let msg): return "Token refresh failed: \(msg)"
        }
    }
}

enum SupabaseSession {
    private static let accessKey  = "com.taxis.supabase-access-token"
    private static let refreshKey = "com.taxis.supabase-refresh-token"

    static func store(accessToken: String, refreshToken: String? = nil) throws {
        try KeychainHelper.shared.save(accessToken, forAccount: accessKey)
        if let rt = refreshToken {
            try KeychainHelper.shared.save(rt, forAccount: refreshKey)
        }
    }

    static func clear() throws {
        try KeychainHelper.shared.delete(forAccount: accessKey)
        try KeychainHelper.shared.delete(forAccount: refreshKey)
    }

    static func currentAccessToken() throws -> String {
        guard let token = try KeychainHelper.shared.read(forAccount: accessKey) else {
            throw SupabaseSessionError.missingAccessToken
        }
        guard !isExpired(token) else {
            throw SupabaseSessionError.missingAccessToken
        }
        return token
    }

    /// Returns true if the JWT's `exp` claim is within 60 seconds of now.
    static func isExpired(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: "."); guard parts.count == 3 else { return true }
        var b64 = String(parts[1])
        let rem = b64.count % 4
        if rem != 0 { b64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }
        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow < 60
    }

    /// Exchange the stored refresh token for a new access + refresh token pair.
    /// Stores the new tokens and returns the new access token.
    static func refresh() async throws -> String {
        guard let refreshToken = try KeychainHelper.shared.read(forAccount: refreshKey) else {
            throw SupabaseSessionError.missingRefreshToken
        }

        let authURL = try SupabaseConfig.projectURL
            .appendingPathComponent("auth/v1/token")
        guard var comps = URLComponents(url: authURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseSessionError.refreshFailed("bad URL")
        }
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = comps.url else { throw SupabaseSessionError.refreshFailed("bad URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            // Refresh rejected — clear stale tokens so the app gates on sign-in
            try? clear()
            throw SupabaseSessionError.missingRefreshToken
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccess = json["access_token"] as? String else {
            throw SupabaseSessionError.refreshFailed("unexpected response")
        }
        let newRefresh = json["refresh_token"] as? String
        try store(accessToken: newAccess, refreshToken: newRefresh)
        return newAccess
    }
}
