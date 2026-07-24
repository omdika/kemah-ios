//
//  GoogleAuth.swift
//  trip planner
//
//  Native Google Sign-In, then exchange the resulting ID token for a Supabase
//  session via Supabase's plain REST token endpoint (no Supabase SDK — same
//  "plain REST" convention as APIClient). The returned access_token is what
//  gets fed into AppConfig.tokenStore and sent as `Authorization: Bearer`.
//
//  Requires the GoogleSignIn-iOS package (File > Add Package Dependencies...
//  https://github.com/google/GoogleSignIn-iOS) and a URL Type / URL scheme
//  registered for the iOS OAuth client's REVERSED_CLIENT_ID (Target > Info >
//  URL Types). Neither of those can be done from a text edit — see the
//  accompanying setup notes.
//

import Foundation
import GoogleSignIn
import UIKit

enum GoogleAuthError: LocalizedError {
    case noIDToken
    case noPresentingViewController
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noIDToken:
            return "Google tidak mengembalikan ID token."
        case .noPresentingViewController:
            return "Tidak ada layar aktif untuk menampilkan Google Sign-In."
        case let .tokenExchangeFailed(message):
            return "Gagal tukar token dengan Supabase: \(message)"
        }
    }
}

enum GoogleAuth {
    /// From Google Cloud Console -> APIs & Services -> Credentials.
    static let iOSClientID = "763614853578-g9og9okjgm96ua5kcbn8g9t05s99qctv.apps.googleusercontent.com"
    static let webClientID = "763614853578-q77qa8ih2aiert1ofc0g0tpja3tud151.apps.googleusercontent.com"

    struct SupabaseSession: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    /// Call once at app launch (see trip_plannerApp.init).
    static func configure() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iOSClientID,
            serverClientID: webClientID
        )
    }

    @MainActor
    static func signIn() async throws -> SupabaseSession {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            throw GoogleAuthError.noPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.noIDToken
        }

        return try await exchangeWithSupabase(idToken: idToken)
    }

    private static func exchangeWithSupabase(idToken: String) async throws -> SupabaseSession {
        let url = AppConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["provider": "google", "id_token": idToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GoogleAuthError.tokenExchangeFailed(body)
        }

        return try JSONDecoder().decode(SupabaseSession.self, from: data)
    }
}
