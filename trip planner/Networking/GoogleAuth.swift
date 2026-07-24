//
//  GoogleAuth.swift
//  trip planner
//
//  Native Google Sign-In, then exchanges the resulting ID token for a
//  Supabase session via SupabaseAuth. The returned session gets persisted
//  (KeychainSessionStore) and fed into AppConfig.tokenStore by the caller
//  (TripStore.signInWithGoogle).
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
import CryptoKit

enum GoogleAuthError: LocalizedError {
    case noIDToken
    case noPresentingViewController

    var errorDescription: String? {
        switch self {
        case .noIDToken:
            return "Google tidak mengembalikan ID token."
        case .noPresentingViewController:
            return "Tidak ada layar aktif untuk menampilkan Google Sign-In."
        }
    }
}

enum GoogleAuth {
    /// From Google Cloud Console -> APIs & Services -> Credentials.
    static let iOSClientID = "763614853578-g9og9okjgm96ua5kcbn8g9t05s99qctv.apps.googleusercontent.com"
    static let webClientID = "763614853578-q77qa8ih2aiert1ofc0g0tpja3tud151.apps.googleusercontent.com"

    /// Call once at app launch (see trip_plannerApp.init).
    static func configure() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iOSClientID,
            serverClientID: webClientID
        )
    }

    @MainActor
    static func signIn() async throws -> StoredSession {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            throw GoogleAuthError.noPresentingViewController
        }

        // Supabase's id_token grant validates the token's `nonce` claim by default.
        // Google hashes the nonce it's given (SHA256) into that claim, so we send the
        // hashed value to GIDSignIn and the raw value to Supabase, which hashes it
        // the same way to compare.
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: nil,
            nonce: hashedNonce
        )
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.noIDToken
        }

        return try await SupabaseAuth.exchangeGoogleIDToken(idToken, nonce: rawNonce)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}
