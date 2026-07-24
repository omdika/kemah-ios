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

    /// Placeholder Bearer value for the backend's `SKIP_AUTH=true` dev mode, where the
    /// token's contents are ignored and every request is treated as the backend's
    /// configured `DEV_USER_ID`. APIClient still requires a non-nil token to send a
    /// request at all (see `authenticated` requests), so this stands in until real
    /// Google/Apple sign-in is wired up.
    static let skipAuthDevToken = "dev-skip-auth"

    static func makeRepository() -> KemahRepository {
        if useMock {
            return MockRepository()
        } else {
            // TODO: after Google/Apple sign-in, call tokenStore.setToken(idToken)
            // and drop the skipAuthDevToken seed once SKIP_AUTH=false in prod.
            let tokenStore = InMemoryTokenStore(initialToken: skipAuthDevToken)
            let client = APIClient(baseURL: baseURL, tokenProvider: tokenStore)
            return APIRepository(client: client)
        }
    }
}
