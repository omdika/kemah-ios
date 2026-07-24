//
//  AppConfig.swift
//  trip planner
//
//  Wires up the repository. Flip `useMock` to false and set `baseURL` once the
//  FastAPI backend (API_CONTRACT.md) is reachable.
//

import Foundation

enum AppConfig {
    /// When true, the app runs fully offline against seeded in-memory data.
    static let useMock = false

    /// Base URL of the Kemah REST backend. Trailing slash matters for path joins.
    static let baseURL = URL(string: "https://kemah-sg-763614853578.asia-southeast2.run.app/")!

    /// Supabase project URL + publishable key, used only for the Google ID-token ->
    /// Supabase session exchange (see Networking/GoogleAuth.swift). This is the
    /// *publishable* key (safe to embed client-side, not the backend's secret key).
    static let supabaseURL = URL(string: "https://jfqwztqnuftubuxbgrul.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_O0B3yQ0e23F4b9H1Atvjtw_Kfu-6fx4"

    /// Placeholder Bearer value for the backend's `SKIP_AUTH=true` dev mode, where the
    /// token's contents are ignored and every request is treated as the backend's
    /// configured `DEV_USER_ID`. Used until a real sign-in replaces it via `tokenStore`.
    static let skipAuthDevToken = "dev-skip-auth"

    /// Shared token store: APIClient reads from it, and a real sign-in flow
    /// (GoogleAuth.signIn) writes the resulting Supabase session token into it.
    static let tokenStore = InMemoryTokenStore(initialToken: skipAuthDevToken)

    static func makeRepository() -> KemahRepository {
        if useMock {
            return MockRepository()
        } else {
            let client = APIClient(baseURL: baseURL, tokenProvider: tokenStore)
            return APIRepository(client: client)
        }
    }
}
