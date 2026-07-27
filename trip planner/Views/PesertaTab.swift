//
//  PesertaTab.swift
//  trip planner
//
//  Participants list: avatar, name, role + headcount, tap to edit role. Undang
//  Teman button, plus a share-summary button when the trip is completed.
//

import SwiftUI

struct PesertaTab: View {
    @EnvironmentObject private var store: TripStore
    let trip: Trip

    @State private var editing: Participant?
    @State private var showInvite = false
    @State private var deletingParticipant: Participant?
    @State private var showLeaveConfirm = false

    private var isOwner: Bool { store.isOwner }
    private var currentUserId: String? { store.user?.id }

    // True when the signed-in user is in the participant list but not the owner.
    private var canLeave: Bool {
        guard let uid = currentUserId, !isOwner else { return false }
        return trip.participants.contains { $0.userId == uid }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(trip.participants.enumerated()), id: \.element.id) { index, participant in
                ParticipantRow(
                    participant: participant,
                    colorIndex: index,
                    showDelete: isOwner && participant.userId != trip.ownerId,
                    onDelete: { deletingParticipant = participant }
                ) {
                    editing = participant
                }
            }

            Button { showInvite = true } label: {
                Label("Undang Teman", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(store.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            if canLeave {
                Button { showLeaveConfirm = true } label: {
                    Label("Keluar dari Trip", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous).stroke(Color.red.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if trip.status == .selesai {
                ShareLink(item: shareText) {
                    Label("Bagikan Ringkasan Trip", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous).stroke(Theme.neutralPillBg, lineWidth: 1))
                }
            }
        }
        .sheet(item: $editing) { participant in
            RoleSheet(participant: participant)
        }
        .sheet(isPresented: $showInvite) { InviteSheet() }
        .alert("Hapus peserta?", isPresented: Binding(
            get: { deletingParticipant != nil },
            set: { if !$0 { deletingParticipant = nil } }
        )) {
            Button("Hapus", role: .destructive) {
                guard let p = deletingParticipant else { return }
                deletingParticipant = nil
                Task { await store.deleteParticipant(p) }
            }
            Button("Batal", role: .cancel) { deletingParticipant = nil }
        } message: {
            if let p = deletingParticipant {
                Text("\(p.name) dan semua data pribadinya akan dihapus dari trip ini.")
            }
        }
        .alert("Keluar dari trip?", isPresented: $showLeaveConfirm) {
            Button("Keluar", role: .destructive) {
                Task { await store.leaveTrip() }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Kamu akan dihapus dari trip ini beserta semua data pribadimu.")
        }
    }

    private var shareText: String {
        "Ringkasan Trip \(trip.name) — \(trip.participants.count) peserta. Cek di Kemah!"
    }
}

struct ParticipantRow: View {
    let participant: Participant
    let colorIndex: Int
    var showDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: participant.name, colorIndex: colorIndex, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text("\(participant.picForLabel) · \(participant.headcount) orang")
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            if showDelete {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(8)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSubtle)
            }
        }
        .padding(12)
        .cardStyle(radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }
}
