//
//  TripStore.swift
//  trip planner
//
//  App-wide observable state. Owns the repository, auth state, the trip list +
//  active trip detail, the (mock) offline flag, accent theme, and the toast
//  queue. All mutations go through the repository, then local state is refreshed.
//

import SwiftUI
import Combine

@MainActor
final class TripStore: ObservableObject {
    // Dependencies
    private let repository: KemahRepository

    // Auth
    @Published var user: User?
    @Published var isAuthenticated = false
    /// True while `restoreSession()` is checking Keychain at launch — ContentView
    /// shows a blank/loading state instead of flashing LoginView first.
    @Published private(set) var isRestoringSession = true

    // Data
    @Published var trips: [TripSummary] = []
    @Published var activeTrip: Trip?
    @Published var activeSettlement: SettlementResult?
    @Published private(set) var isLoadingTrips = false
    @Published private(set) var isLoadingDetail = false
    @Published private(set) var isLoadingSettlement = false

    // UI-only state
    @Published var isOffline = true
    @Published var accent: AppAccent = .orange
    @Published var toastMessage: String?
    @Published var errorMessage: String?

    // Invite deep link: set as soon as a link is opened (regardless of auth
    // state) so ContentView can present the read-only guest preview; cleared
    // once the join succeeds. `justJoinedTripId` fires once more right after,
    // so ContentView can push navigation to the newly-joined trip.
    @Published var pendingInvite: PendingInvite?
    @Published var invitePreview: TripPreview?
    @Published private(set) var isLoadingInvitePreview = false
    @Published var justJoinedTripId: String?
    /// Separate from `errorMessage` on purpose: TripPreviewView is presented
    /// as a fullScreenCover *over* LoginView, so both stay live in the
    /// hierarchy at once — two `.alert()`s bound to the same property could
    /// both try to present simultaneously and crash
    /// ("view controller not containing an alert controller").
    @Published var inviteErrorMessage: String?

    private var toastTask: Task<Void, Never>?

    init(repository: KemahRepository) {
        self.repository = repository
    }

    // MARK: - Derived

    var upcomingTrips: [TripSummary] { trips.filter { $0.status == .upcoming } }
    var historyTrips: [TripSummary] { trips.filter { $0.status == .selesai } }

    // MARK: - Split Bill

    func loadSettlement(for trip: Trip) async {
        isLoadingSettlement = true
        defer { isLoadingSettlement = false }
        do {
            let response = try await repository.splitBill(tripId: trip.id)
            activeSettlement = mapSettlement(response, participants: trip.participants)
        } catch {
            // API unavailable — fall back to client-side computation.
            activeSettlement = SplitBillCalculator.compute(
                participants: trip.participants,
                budgetItems: trip.budgetItems
            )
        }
    }

    private func mapSettlement(_ response: SplitBillResponse, participants: [Participant]) -> SettlementResult {
        let colorMap = Dictionary(uniqueKeysWithValues: participants.enumerated().map { ($1.name, $0) })
        return SettlementResult(
            participantCount: response.participantCount,
            equalShareLabel: response.equalShareLabel,
            perPerson: response.perPerson.map { p in
                PerPersonRow(
                    name: p.name,
                    colorIndex: colorMap[p.name] ?? 0,
                    contribution: p.contribution,
                    share: p.share,
                    balance: p.balance,
                    headcount: p.headcount,
                    poolDetails: p.poolDetails.map { PoolItemDetail(name: $0.name, share: $0.share, paid: $0.paid) }
                )
            },
            transfers: response.transfers.map { t in
                TransferRow(
                    from: t.from,
                    to: t.to,
                    total: t.total,
                    parts: t.parts.map { TransferPart(label: $0.label, amount: $0.amount) }
                )
            }
        )
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    // MARK: - Auth

    func signIn() async {
        do {
            user = try await repository.me()
            isAuthenticated = true
            await loadTrips()
            await consumePendingInviteIfAny()
        } catch {
            errorMessage = error.localizedDescription
            // In mock mode `me()` always succeeds; still enter the app for the demo.
            isAuthenticated = true
            await loadTrips()
            await consumePendingInviteIfAny()
        }
    }

    /// Plain LoginView entry point — errors surface via `errorMessage`.
    func signInWithGoogle() async {
        await performGoogleSignIn { self.errorMessage = $0 }
    }

    /// TripPreviewView entry point — same sign-in, but errors go to
    /// `inviteErrorMessage` instead (see its doc comment for why this is a
    /// separate property rather than reusing `errorMessage`).
    func signInWithGoogleForInvite() async {
        await performGoogleSignIn { self.inviteErrorMessage = $0 }
    }

    private func performGoogleSignIn(reportError: @escaping (String?) -> Void) async {
        reportError(nil)
        do {
            let session = try await GoogleAuth.signIn()
            KeychainSessionStore.save(session)
            await AppConfig.tokenStore.setToken(session.accessToken)
            user = try await repository.me()
            isAuthenticated = true
            await loadTrips()
            await consumePendingInviteIfAny()
        } catch {
            reportError(error.localizedDescription)
        }
    }

    /// Call once at app launch (see ContentView.task). Restores a Keychain-
    /// persisted session — refreshing it first if it's expired or close to
    /// it — so the user doesn't have to sign in again after closing the app.
    /// Leaves `isAuthenticated == false` (falls through to LoginView) if there's
    /// no stored session or it can no longer be refreshed.
    func restoreSession() async {
        defer { isRestoringSession = false }

        guard var session = KeychainSessionStore.load() else { return }
        do {
            if session.isExpiredOrExpiringSoon {
                session = try await SupabaseAuth.refresh(refreshToken: session.refreshToken)
                KeychainSessionStore.save(session)
            }
            await AppConfig.tokenStore.setToken(session.accessToken)
            user = try await repository.me()
            isAuthenticated = true
            await loadTrips()
            await consumePendingInviteIfAny()
        } catch {
            // Refresh token itself is no longer valid (expired/revoked) — the
            // stored session is dead, fall back to LoginView.
            KeychainSessionStore.clear()
        }
    }

    // MARK: - Invite deep link

    /// Parses an incoming invite URL, whether it arrived via the `kemah://`
    /// custom scheme (works today, no domain needed) or the `https://kemah.app/...`
    /// Universal Link shape from API_CONTRACT.md (works once that domain hosts
    /// an apple-app-site-association file — same parsing either way).
    static func parseInviteURL(_ url: URL) -> PendingInvite? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        let pathParts = components.path.split(separator: "/").map(String.init)

        let tripId: String?
        if url.scheme == "kemah", components.host == "join" {
            tripId = pathParts.first
        } else if let joinIndex = pathParts.firstIndex(of: "join"), pathParts.count > joinIndex + 1 {
            tripId = pathParts[joinIndex + 1]
        } else {
            tripId = nil
        }

        guard let tripId, let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            return nil
        }
        return PendingInvite(tripId: tripId, token: token)
    }

    /// Call from `.onOpenURL`. Always shows the read-only guest preview first,
    /// regardless of auth state — joining only happens when the user
    /// explicitly taps the preview's CTA (see `joinPendingInvite`).
    func handleIncomingURL(_ url: URL) {
        guard let invite = Self.parseInviteURL(url) else { return }
        pendingInvite = invite
        Task { await loadInvitePreview() }
    }

    func loadInvitePreview() async {
        guard let invite = pendingInvite else { return }
        isLoadingInvitePreview = true
        defer { isLoadingInvitePreview = false }
        do {
            invitePreview = try await repository.previewInvite(tripId: invite.tripId, token: invite.token)
        } catch {
            // Bad/expired token, trip gone, etc. — nothing sensible to preview.
            inviteErrorMessage = error.localizedDescription
            pendingInvite = nil
        }
    }

    /// Tapped from the preview sheet by an already-authenticated user (no
    /// Google round-trip needed — see LoginView/TripPreviewView for the
    /// signed-out path, which joins via `consumePendingInviteIfAny` instead).
    func joinPendingInvite() async {
        guard let invite = pendingInvite else { return }
        await join(invite)
    }

    private func consumePendingInviteIfAny() async {
        guard let invite = pendingInvite else { return }
        await join(invite)
    }

    private var isJoiningInvite = false

    private func join(_ invite: PendingInvite) async {
        guard !isJoiningInvite else { return }
        isJoiningInvite = true
        defer { isJoiningInvite = false }

        do {
            let tripId = try await repository.joinTrip(tripId: invite.tripId, token: invite.token)
            pendingInvite = nil
            invitePreview = nil
            await loadTrips()
            justJoinedTripId = tripId
            showToast("Berhasil gabung ke trip")
        } catch {
            inviteErrorMessage = error.localizedDescription
        }
    }

    func signOut() {
        KeychainSessionStore.clear()
        Task { await AppConfig.tokenStore.setToken(AppConfig.skipAuthDevToken) }
        isAuthenticated = false
        user = nil
        trips = []
        activeTrip = nil
    }

    // MARK: - Trips

    func loadTrips() async {
        isLoadingTrips = true
        defer { isLoadingTrips = false }
        do {
            trips = try await repository.trips()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openTrip(id: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            activeTrip = try await repository.trip(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTrip(name: String, location: String, date: String, mapLink: String, phone: String, coverUrl: String) async {
        do {
            let trip = try await repository.createTrip(
                CreateTripRequest(name: name, location: location, date: date, mapLink: mapLink, phone: phone, coverUrl: coverUrl)
            )
            await loadTrips()
            activeTrip = trip
            showToast("Trip \"\(trip.name)\" dibuat")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateActiveTrip(_ body: UpdateTripRequest, toast: String? = nil) async {
        guard let id = activeTrip?.id else { return }
        do {
            activeTrip = try await repository.updateTrip(id: id, body)
            await loadTrips()
            if let toast { showToast(toast) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Participants

    func addParticipant(name: String) async {
        guard let id = activeTrip?.id else { return }
        do {
            _ = try await repository.addParticipant(tripId: id, name: name)
            await refreshActive()
            showToast("\(name) ditambahkan")
        } catch { errorMessage = error.localizedDescription }
    }

    func updateParticipant(_ participant: Participant, role: String, headcount: Int) async {
        guard let id = activeTrip?.id else { return }
        do {
            _ = try await repository.updateParticipant(
                tripId: id, participantId: participant.id,
                UpdateParticipantRequest(picForLabel: role, headcount: headcount)
            )
            await refreshActive()
            showToast("Peran \(participant.name) diperbarui")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Checklist

    func toggleItem(_ item: ChecklistItem) async {
        guard let id = activeTrip?.id else { return }
        do {
            _ = try await repository.updateItem(tripId: id, itemId: item.id, UpdateItemRequest(checked: !item.checked))
            await refreshActive()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveItem(existing: ChecklistItem?, name: String, qty: Int, pic: String?, note: String, isPersonal: Bool) async {
        guard let id = activeTrip?.id else { return }
        do {
            if let existing {
                _ = try await repository.updateItem(
                    tripId: id, itemId: existing.id,
                    UpdateItemRequest(name: name, qty: qty, pic: pic, note: note, isPersonal: isPersonal)
                )
            } else {
                _ = try await repository.addItem(
                    tripId: id,
                    CreateItemRequest(name: name, qty: qty, pic: pic, note: note, isPersonal: isPersonal)
                )
            }
            await refreshActive()
            showToast(existing == nil ? "Barang ditambahkan" : "Barang diperbarui")
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteItem(_ item: ChecklistItem) async {
        guard let id = activeTrip?.id else { return }
        do {
            try await repository.deleteItem(tripId: id, itemId: item.id)
            await refreshActive()
            showToast("Barang dihapus")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Budget

    func saveBudgetItem(existing: BudgetItem?, name: String, price: Double, paidBy: String?, pic: String?, splitMode: SplitMode, isPersonal: Bool) async {
        guard let id = activeTrip?.id else { return }
        do {
            if let existing {
                _ = try await repository.updateBudgetItem(
                    tripId: id, budgetItemId: existing.id,
                    UpdateBudgetItemRequest(name: name, price: price, paidBy: paidBy, pic: pic, splitMode: splitMode, isPersonal: isPersonal)
                )
            } else {
                _ = try await repository.addBudgetItem(
                    tripId: id,
                    CreateBudgetItemRequest(name: name, price: price, paidBy: paidBy, pic: pic, splitMode: splitMode, isPersonal: isPersonal)
                )
            }
            await refreshActive()
            showToast(existing == nil ? "Pengeluaran ditambahkan" : "Pengeluaran diperbarui")
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteBudgetItem(_ item: BudgetItem) async {
        guard let id = activeTrip?.id else { return }
        do {
            try await repository.deleteBudgetItem(tripId: id, budgetItemId: item.id)
            await refreshActive()
            showToast("Pengeluaran dihapus")
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Invite

    func inviteLink() async -> String? {
        guard let id = activeTrip?.id else { return nil }
        do { return try await repository.inviteLink(tripId: id).url }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    // MARK: - Helpers

    private func refreshActive() async {
        guard let id = activeTrip?.id else { return }
        do {
            activeTrip = try await repository.trip(id: id)
            await loadTrips()
        } catch { errorMessage = error.localizedDescription }
    }
}
