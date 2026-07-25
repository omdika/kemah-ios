//
//  Repository.swift
//  trip planner
//
//  Abstraction over the data source. `APIRepository` talks to the real FastAPI
//  backend via APIClient (API_CONTRACT.md). `MockRepository` is an in-memory
//  store seeded from the prototype so the app runs in the simulator without a
//  backend. Swap between them in AppConfig.
//

import Foundation

protocol KemahRepository: Sendable {
    func me() async throws -> User
    func trips() async throws -> [TripSummary]
    func trip(id: String) async throws -> Trip
    func createTrip(_ body: CreateTripRequest) async throws -> Trip
    func updateTrip(id: String, _ body: UpdateTripRequest) async throws -> Trip
    func deleteTrip(id: String) async throws

    func addParticipant(tripId: String, name: String) async throws -> Participant
    func updateParticipant(tripId: String, participantId: String, _ body: UpdateParticipantRequest) async throws -> Participant
    func deleteParticipant(tripId: String, participantId: String) async throws

    func addItem(tripId: String, _ body: CreateItemRequest) async throws -> ChecklistItem
    func updateItem(tripId: String, itemId: String, _ body: UpdateItemRequest) async throws -> ChecklistItem
    func deleteItem(tripId: String, itemId: String) async throws

    func addBudgetItem(tripId: String, _ body: CreateBudgetItemRequest) async throws -> BudgetItem
    func updateBudgetItem(tripId: String, budgetItemId: String, _ body: UpdateBudgetItemRequest) async throws -> BudgetItem
    func deleteBudgetItem(tripId: String, budgetItemId: String) async throws

    func inviteLink(tripId: String) async throws -> InviteLink
    func joinTrip(tripId: String, token: String) async throws -> String
    func previewInvite(tripId: String, token: String) async throws -> TripPreview

    func splitBill(tripId: String) async throws -> SplitBillResponse
}

// MARK: - Real backend

final class APIRepository: KemahRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func me() async throws -> User { try await client.getMe() }
    func trips() async throws -> [TripSummary] { try await client.getTrips() }
    func trip(id: String) async throws -> Trip { try await client.getTrip(id: id) }
    func createTrip(_ body: CreateTripRequest) async throws -> Trip { try await client.createTrip(body) }
    func updateTrip(id: String, _ body: UpdateTripRequest) async throws -> Trip { try await client.updateTrip(id: id, body) }
    func deleteTrip(id: String) async throws { try await client.deleteTrip(id: id) }

    func addParticipant(tripId: String, name: String) async throws -> Participant {
        try await client.addParticipant(tripId: tripId, name: name)
    }
    func updateParticipant(tripId: String, participantId: String, _ body: UpdateParticipantRequest) async throws -> Participant {
        try await client.updateParticipant(tripId: tripId, participantId: participantId, body)
    }
    func deleteParticipant(tripId: String, participantId: String) async throws {
        try await client.deleteParticipant(tripId: tripId, participantId: participantId)
    }

    func addItem(tripId: String, _ body: CreateItemRequest) async throws -> ChecklistItem {
        try await client.addItem(tripId: tripId, body)
    }
    func updateItem(tripId: String, itemId: String, _ body: UpdateItemRequest) async throws -> ChecklistItem {
        try await client.updateItem(tripId: tripId, itemId: itemId, body)
    }
    func deleteItem(tripId: String, itemId: String) async throws {
        try await client.deleteItem(tripId: tripId, itemId: itemId)
    }

    func addBudgetItem(tripId: String, _ body: CreateBudgetItemRequest) async throws -> BudgetItem {
        try await client.addBudgetItem(tripId: tripId, body)
    }
    func updateBudgetItem(tripId: String, budgetItemId: String, _ body: UpdateBudgetItemRequest) async throws -> BudgetItem {
        try await client.updateBudgetItem(tripId: tripId, budgetItemId: budgetItemId, body)
    }
    func deleteBudgetItem(tripId: String, budgetItemId: String) async throws {
        try await client.deleteBudgetItem(tripId: tripId, budgetItemId: budgetItemId)
    }

    func inviteLink(tripId: String) async throws -> InviteLink {
        try await client.createInviteLink(tripId: tripId)
    }

    func joinTrip(tripId: String, token: String) async throws -> String {
        try await client.join(tripId: tripId, token: token).tripId
    }

    func previewInvite(tripId: String, token: String) async throws -> TripPreview {
        try await client.previewInvite(tripId: tripId, token: token)
    }

    func splitBill(tripId: String) async throws -> SplitBillResponse {
        try await client.getSplitBill(tripId: tripId)
    }
}
