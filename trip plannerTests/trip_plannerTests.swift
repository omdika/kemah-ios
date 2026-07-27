//
//  trip_plannerTests.swift
//  trip plannerTests
//

import Testing
import Foundation
@testable import trip_planner

struct trip_plannerTests {

    @Test func example() async throws {
        // placeholder — real tests below
    }

}

// MARK: - v1.7.0 Tests: ownerId / userId / deleteParticipant / leaveTrip / isOwner

struct V170ModelTests {

    // MARK: ownerId — TripSummary

    @Test("TripSummary decodes ownerId when present")
    func tripSummaryOwnerIdPresent() throws {
        let json = """
        {
          "id":"t1","name":"Test","location":"L","date":"2026-01-01",
          "status":"upcoming","budgetTarget":0,"budgetMode":"auto",
          "participantCount":1,"checklistProgress":{"checked":0,"total":0},
          "ownerId":"u_irma"
        }
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(TripSummary.self, from: json)
        #expect(summary.ownerId == "u_irma")
    }

    @Test("TripSummary ownerId defaults nil when absent — backward compat")
    func tripSummaryOwnerIdAbsent() throws {
        let json = """
        {
          "id":"t1","name":"Test","location":"L","date":"2026-01-01",
          "status":"upcoming","budgetTarget":0,"budgetMode":"auto",
          "participantCount":1,"checklistProgress":{"checked":0,"total":0}
        }
        """.data(using: .utf8)!
        let summary = try JSONDecoder().decode(TripSummary.self, from: json)
        #expect(summary.ownerId == nil)
    }

    // MARK: ownerId — Trip

    @Test("Trip decodes ownerId when present")
    func tripOwnerIdPresent() throws {
        let json = """
        {
          "id":"t1","name":"T","location":"L","date":"2026-01-01",
          "status":"upcoming","budgetTarget":0,"budgetMode":"auto",
          "ownerId":"u_irma",
          "participants":[],"items":[],"budgetItems":[]
        }
        """.data(using: .utf8)!
        let trip = try JSONDecoder().decode(Trip.self, from: json)
        #expect(trip.ownerId == "u_irma")
    }

    @Test("Trip ownerId defaults nil when absent — backward compat")
    func tripOwnerIdAbsent() throws {
        let json = """
        {
          "id":"t1","name":"T","location":"L","date":"2026-01-01",
          "status":"upcoming","budgetTarget":0,"budgetMode":"auto",
          "participants":[],"items":[],"budgetItems":[]
        }
        """.data(using: .utf8)!
        let trip = try JSONDecoder().decode(Trip.self, from: json)
        #expect(trip.ownerId == nil)
    }

    // MARK: userId — Participant

    @Test("Participant decodes userId when present")
    func participantUserIdPresent() throws {
        let json = """
        {"id":"p1","userId":"u_irma","name":"Irma","picForLabel":"PIC","headcount":1}
        """.data(using: .utf8)!
        let p = try JSONDecoder().decode(Participant.self, from: json)
        #expect(p.userId == "u_irma")
    }

    @Test("Participant userId defaults nil when absent — backward compat")
    func participantUserIdAbsent() throws {
        let json = """
        {"id":"p1","name":"Irma","picForLabel":"PIC","headcount":1}
        """.data(using: .utf8)!
        let p = try JSONDecoder().decode(Participant.self, from: json)
        #expect(p.userId == nil)
    }
}

// MARK: - MockRepository: deleteParticipant

struct V170DeleteParticipantTests {

    @Test("deleteParticipant removes participant from trip")
    func removesParticipant() async throws {
        let mock = await MockRepository()
        let tripBefore = try await mock.trip(id: "t1")
        #expect(tripBefore.participants.contains { $0.id == "p_yuki" })

        try await mock.deleteParticipant(tripId: "t1", participantId: "p_yuki")

        let tripAfter = try await mock.trip(id: "t1")
        #expect(!tripAfter.participants.contains { $0.id == "p_yuki" })
    }

    @Test("deleteParticipant cascades personal checklist items of deleted participant")
    func cascadesPersonalChecklistItems() async throws {
        let mock = await MockRepository()
        // Irma's personal checklist items: i12, i13, i14 (visible to Irma = currentUser)
        let tripBefore = try await mock.trip(id: "t1")
        #expect(tripBefore.items.contains { $0.id == "i12" })
        #expect(tripBefore.items.contains { $0.id == "i13" })
        #expect(tripBefore.items.contains { $0.id == "i14" })

        try await mock.deleteParticipant(tripId: "t1", participantId: "p_irma")

        let tripAfter = try await mock.trip(id: "t1")
        #expect(!tripAfter.items.contains { $0.id == "i12" })
        #expect(!tripAfter.items.contains { $0.id == "i13" })
        #expect(!tripAfter.items.contains { $0.id == "i14" })
    }

    @Test("deleteParticipant cascades personal budget items of deleted participant")
    func cascadesPersonalBudgetItems() async throws {
        let mock = await MockRepository()
        // Irma's personal budget: bp1 ("Jajan & kopi"), bp2 ("Oleh-oleh keluarga")
        let tripBefore = try await mock.trip(id: "t1")
        #expect(tripBefore.budgetItems.contains { $0.id == "bp1" })
        #expect(tripBefore.budgetItems.contains { $0.id == "bp2" })

        try await mock.deleteParticipant(tripId: "t1", participantId: "p_irma")

        let tripAfter = try await mock.trip(id: "t1")
        #expect(!tripAfter.budgetItems.contains { $0.id == "bp1" })
        #expect(!tripAfter.budgetItems.contains { $0.id == "bp2" })
    }

    @Test("deleteParticipant does not remove group items")
    func doesNotRemoveGroupItems() async throws {
        let mock = await MockRepository()

        try await mock.deleteParticipant(tripId: "t1", participantId: "p_irma")

        let tripAfter = try await mock.trip(id: "t1")
        // Group checklist items must survive
        #expect(tripAfter.items.contains { $0.id == "i1" })   // Tenda dome
        #expect(tripAfter.items.contains { $0.id == "i7" })   // Bahan makanan
        // Group budget items must survive
        #expect(tripAfter.budgetItems.contains { $0.id == "b1" }) // Tenda dome budget
        #expect(tripAfter.budgetItems.contains { $0.id == "b3" }) // Kompor portable
    }
}

// MARK: - MockRepository: leaveTrip

struct V170LeaveTripTests {

    @Test("leaveTrip throws HTTP 403 when caller is trip owner")
    func ownerCannotLeave() async {
        let mock = await MockRepository()
        // currentUser is "u_irma" who owns t1 (ownerId: "u_irma")
        do {
            try await mock.leaveTrip(tripId: "t1")
            Issue.record("Expected leaveTrip to throw for owner, but it succeeded")
        } catch APIError.http(let status, _) {
            #expect(status == 403)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - TripStore: isOwner

struct V170IsOwnerTests {

    @MainActor
    @Test("isOwner returns false when no active trip")
    func isOwnerFalseWhenNoTrip() async {
        let store = TripStore(repository: MockRepository())
        await store.signIn()
        // No trip opened
        #expect(store.isOwner == false)
    }

    @MainActor
    @Test("isOwner returns true when signed-in user matches trip ownerId")
    func isOwnerTrueWhenMatches() async {
        let store = TripStore(repository: MockRepository())
        await store.signIn()
        await store.openTrip(id: "t1")  // t1.ownerId == "u_irma", user.id == "u_irma"
        #expect(store.isOwner == true)
    }
}
