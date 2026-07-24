//
//  APIClient.swift
//  trip planner
//
//  Networking layer that consumes the Kemah REST backend described in
//  API_CONTRACT.md. All endpoints require `Authorization: Bearer <idToken>`.
//  Uses async/await; no Combine, no Firebase/Supabase SDK.
//

import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Belum masuk. Silakan login terlebih dahulu."
        case .invalidURL:
            return "URL tidak valid."
        case .invalidResponse:
            return "Respons server tidak valid."
        case let .http(status, body):
            return "Server error \(status): \(body)"
        case let .decoding(error):
            return "Gagal membaca data: \(error.localizedDescription)"
        case let .transport(error):
            return "Koneksi bermasalah: \(error.localizedDescription)"
        }
    }
}

// MARK: - Token storage

/// Holds the Bearer id-token obtained from the Google/Apple sign-in flow.
/// Kept as an actor-isolated reference so networking stays thread-safe.
protocol TokenProvider: Sendable {
    func currentToken() async -> String?
}

actor InMemoryTokenStore: TokenProvider {
    private var token: String?

    init(initialToken: String? = nil) {
        self.token = initialToken
    }

    func currentToken() async -> String? { token }

    func setToken(_ token: String?) { self.token = token }
}

// MARK: - Client

final class APIClient: Sendable {
    let baseURL: URL
    private let tokenProvider: TokenProvider
    private let session: URLSession
    /// Called once when a request comes back 401. Should refresh the session
    /// and update `tokenProvider` itself (they typically share the same
    /// underlying token store); returns whether the request should be retried.
    private let onUnauthorized: (@Sendable () async -> Bool)?

    init(
        baseURL: URL,
        tokenProvider: TokenProvider,
        session: URLSession = .shared,
        onUnauthorized: (@Sendable () async -> Bool)? = nil
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
        self.onUnauthorized = onUnauthorized
    }

    // MARK: HTTP verbs

    private enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        return encoder
    }

    /// Core request. `Body` is the encodable request payload; `Response` the decoded result.
    private func request<Response: Decodable>(
        _ method: Method,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> Response {
        let data = try await requestData(method, path: path, query: query, body: body, authenticated: authenticated)
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    @discardableResult
    private func requestData(
        _ method: Method,
        path: String,
        query: [URLQueryItem],
        body: Encodable?,
        authenticated: Bool,
        isRetry: Bool = false
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue

        if authenticated {
            guard let token = await tokenProvider.currentToken() else {
                throw APIError.notAuthenticated
            }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try makeEncoder().encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401, authenticated, !isRetry, let onUnauthorized, await onUnauthorized() {
                return try await requestData(method, path: path, query: query, body: body, authenticated: authenticated, isRetry: true)
            }
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(status: http.statusCode, body: bodyText)
        }
        return data
    }

    // MARK: - Users

    func getMe() async throws -> User {
        try await request(.get, path: "me")
    }

    // MARK: - Trips

    func getTrips() async throws -> [TripSummary] {
        let wrapper: TripListResponse = try await request(.get, path: "trips")
        return wrapper.trips
    }

    func getTrip(id: String) async throws -> Trip {
        try await request(.get, path: "trips/\(id)")
    }

    func createTrip(_ body: CreateTripRequest) async throws -> Trip {
        try await request(.post, path: "trips", body: body)
    }

    func updateTrip(id: String, _ body: UpdateTripRequest) async throws -> Trip {
        try await request(.patch, path: "trips/\(id)", body: body)
    }

    func deleteTrip(id: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "trips/\(id)")
    }

    // MARK: - Participants

    func addParticipant(tripId: String, name: String) async throws -> Participant {
        try await request(.post, path: "trips/\(tripId)/participants", body: CreateParticipantRequest(name: name))
    }

    func updateParticipant(tripId: String, participantId: String, _ body: UpdateParticipantRequest) async throws -> Participant {
        try await request(.patch, path: "trips/\(tripId)/participants/\(participantId)", body: body)
    }

    func deleteParticipant(tripId: String, participantId: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "trips/\(tripId)/participants/\(participantId)")
    }

    // MARK: - Checklist items

    func addItem(tripId: String, _ body: CreateItemRequest) async throws -> ChecklistItem {
        try await request(.post, path: "trips/\(tripId)/items", body: body)
    }

    func updateItem(tripId: String, itemId: String, _ body: UpdateItemRequest) async throws -> ChecklistItem {
        try await request(.patch, path: "trips/\(tripId)/items/\(itemId)", body: body)
    }

    func deleteItem(tripId: String, itemId: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "trips/\(tripId)/items/\(itemId)")
    }

    // MARK: - Budget items

    func addBudgetItem(tripId: String, _ body: CreateBudgetItemRequest) async throws -> BudgetItem {
        try await request(.post, path: "trips/\(tripId)/budget-items", body: body)
    }

    func updateBudgetItem(tripId: String, budgetItemId: String, _ body: UpdateBudgetItemRequest) async throws -> BudgetItem {
        try await request(.patch, path: "trips/\(tripId)/budget-items/\(budgetItemId)", body: body)
    }

    func deleteBudgetItem(tripId: String, budgetItemId: String) async throws {
        let _: EmptyResponse = try await request(.delete, path: "trips/\(tripId)/budget-items/\(budgetItemId)")
    }

    // MARK: - Split bill (server-computed)

    func getSplitBill(tripId: String) async throws -> SplitBillResponse {
        try await request(.get, path: "trips/\(tripId)/split-bill")
    }

    // MARK: - Invite

    func createInviteLink(tripId: String) async throws -> InviteLink {
        try await request(.post, path: "trips/\(tripId)/invite/invite-link")
    }

    func join(tripId: String, token: String) async throws -> JoinResponse {
        try await request(.post, path: "trips/\(tripId)/invite/join", body: JoinRequest(token: token))
    }

    // MARK: - Uploads

    func upload(fileData: Data, fileName: String, mimeType: String) async throws -> UploadResult {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appendingPathComponent("uploads")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        guard let token = await tokenProvider.currentToken() else { throw APIError.notAuthenticated }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try makeDecoder().decode(UploadResult.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

// MARK: - Wrapper types

struct TripListResponse: Codable { let trips: [TripSummary] }
struct JoinResponse: Codable { let tripId: String }
struct EmptyResponse: Codable {}

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}

// MARK: - Type-erased Encodable

/// Lets `request(body:)` accept `Encodable` existentials while still encoding concretely.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
