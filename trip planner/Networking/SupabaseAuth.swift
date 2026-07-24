//
//  SupabaseAuth.swift
//  trip planner
//
//  Talks to Supabase's plain REST token endpoint (no Supabase SDK, same
//  "plain REST" convention as APIClient): exchanges a Google ID token for a
//  session, and refreshes an existing session's access token. Provider-
//  specific sign-in (GoogleAuth.swift) delegates the exchange step here so
//  the same refresh logic works regardless of how the session was obtained.
//

import Foundation

enum SupabaseAuthError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case let .requestFailed(message):
            return "Gagal berkomunikasi dengan Supabase: \(message)"
        }
    }
}

/// A signed-in session, persisted to Keychain by KeychainSessionStore so the
/// user stays logged in across app launches.
struct StoredSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    /// Refresh a bit before actual expiry to avoid racing an in-flight request.
    var isExpiredOrExpiringSoon: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

private struct SupabaseTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum SupabaseAuth {
    static func exchangeGoogleIDToken(_ idToken: String, nonce: String) async throws -> StoredSession {
        try await tokenRequest(
            grantType: "id_token",
            body: ["provider": "google", "id_token": idToken, "nonce": nonce]
        )
    }

    static func refresh(refreshToken: String) async throws -> StoredSession {
        try await tokenRequest(
            grantType: "refresh_token",
            body: ["refresh_token": refreshToken]
        )
    }

    private static func tokenRequest(grantType: String, body: [String: String]) async throws -> StoredSession {
        let url = AppConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: grantType)])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "unknown error"
            throw SupabaseAuthError.requestFailed(bodyText)
        }

        let decoded = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
        return StoredSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(decoded.expiresIn)
        )
    }
}
