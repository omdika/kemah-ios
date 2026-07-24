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

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(trip.participants.enumerated()), id: \.element.id) { index, participant in
                ParticipantRow(participant: participant, colorIndex: index) {
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
    }

    private var shareText: String {
        "Ringkasan Trip \(trip.name) — \(trip.participants.count) peserta. Cek di Kemah!"
    }
}

struct ParticipantRow: View {
    let participant: Participant
    let colorIndex: Int
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
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSubtle)
        }
        .padding(12)
        .cardStyle(radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }
}
