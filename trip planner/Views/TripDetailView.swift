//
//  TripDetailView.swift
//  trip planner
//
//  Trip detail: cover header with scrim, participant stack, invite + map/chat
//  pills, offline indicator, and a Checklist / Budget / Peserta segmented bar.
//

import SwiftUI
import PhotosUI

struct TripDetailView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Binding var path: [Route]

    @State private var tab: DetailTab = .checklist
    @State private var showInvite = false
    @State private var showBudgetAdd = false
    @State private var showChecklistAdd = false
    @State private var checklistIsPersonal = false
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var isUploadingCover = false

    enum DetailTab: String, CaseIterable {
        case checklist = "Checklist"
        case budget = "Budget"
        case peserta = "Peserta"
    }

    var body: some View {
        Group {
            if let trip = store.activeTrip {
                // ZStack so the back button is a sibling of — not inside — the
                // ScrollView. This ensures: (1) scroll gestures can't steal the
                // tap, (2) the button sits below the Dynamic Island / status bar
                // via its own safe-area inset rather than the ScrollView's.
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        VStack(spacing: 0) {
                            header(trip)
                            VStack(spacing: 16) {
                                OfflineIndicatorRow(isOffline: $store.isOffline)
                                segmented
                                tabContent(trip)
                            }
                            .padding(20)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .background(Theme.background)
                    .safeAreaInset(edge: .bottom) {
                        if tab == .budget {
                            budgetFloatingBar(trip)
                        } else if tab == .checklist {
                            checklistFAB
                        }
                    }

                    backButton
                    coverEditButton
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showInvite) { InviteSheet() }
        .sheet(isPresented: $showBudgetAdd) {
            if let trip = store.activeTrip {
                BudgetItemSheet(trip: trip, existing: nil, initialPersonal: false)
            }
        }
        .sheet(isPresented: $showChecklistAdd) {
            if let trip = store.activeTrip {
                ItemSheet(trip: trip, existing: nil, isPersonal: checklistIsPersonal)
            }
        }
        .onChange(of: coverPickerItem) { newItem in
            guard let newItem else { return }
            Task {
                isUploadingCover = true
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await store.uploadCoverImage(data: data, fileName: "cover.jpg", mimeType: "image/jpeg")
                }
                isUploadingCover = false
                coverPickerItem = nil
            }
        }
    }

    // MARK: Header

    private func header(_ trip: Trip) -> some View {
        ZStack(alignment: .bottomLeading) {
            CoverImage(url: trip.coverUrl, seed: trip.id)
                .frame(height: 230)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Spacer()
                    AvatarStack(names: trip.participants.map(\.name))
                }
                Text(trip.name)
                    .font(.rounded(26, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(trip.location) · \(Formatters.dateLabel(trip.date))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                HStack(spacing: 8) {
                    pill("Undang", "person.badge.plus") { showInvite = true }
                    if let map = trip.mapLink, !map.isEmpty, let url = URL(string: map) {
                        pill("Lihat Peta", "mappin.and.ellipse") { openURL(url) }
                    }
                    if let wa = Formatters.waLink(for: trip.phone) {
                        pill("Chat Admin", "message.fill") { openURL(wa) }
                    }
                }
                .padding(.top, 2)

                if let uploader = trip.coverUploadedByName {
                    Text("Foto cover oleh \(uploader)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(16)
        }
    }

    private var coverEditButton: some View {
        PhotosPicker(selection: $coverPickerItem, matching: .images) {
            ZStack {
                Circle().fill(.black.opacity(0.35))
                if isUploadingCover {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "camera.fill").font(.footnote).foregroundStyle(.white)
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(isUploadingCover)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.3))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.leading, 16)
    }

    private func pill(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.regularMaterial)
                .foregroundStyle(Theme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Segmented

    private var segmented: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(tab == t ? store.accent.color : Color.clear)
                        .foregroundStyle(tab == t ? Color.white : Theme.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func tabContent(_ trip: Trip) -> some View {
        switch tab {
        case .checklist: ChecklistTab(trip: trip, isPersonalSection: $checklistIsPersonal)
        case .budget: BudgetTab(trip: trip)
        case .peserta: PesertaTab(trip: trip)
        }
    }

    // MARK: Checklist FAB

    private var checklistFAB: some View {
        HStack {
            Spacer()
            Button { showChecklistAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(store.accent.color)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Budget floating bar

    private func budgetFloatingBar(_ trip: Trip) -> some View {
        VStack(spacing: 0) {
            // FAB — add expense
            Button { showBudgetAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(store.accent.color)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .padding(.bottom, 12)

            // Split Bill CTA bar
            ZStack {
                store.accent.color
                    .ignoresSafeArea(edges: .bottom)
                Button { path.append(.splitBill) } label: {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.headline.weight(.bold))
                            Text("Split Bill")
                                .font(.headline.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.bold))
                                .opacity(0.8)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 40)
            .shadow(color: store.accent.color.opacity(0.45), radius: 14, x: 0, y: -6)
        }
    }
}
