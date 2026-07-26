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
    @State private var showEditTrip = false
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
                                segmented
                                tabContent(trip)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
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
        .sheet(isPresented: $showEditTrip) {
            if let trip = store.activeTrip {
                EditTripSheet(trip: trip)
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
        ZStack {
            CoverImage(url: trip.coverUrl, seed: trip.id)
                .frame(height: 230)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                )

            // VStack fills the full 230pt header: top row pinned at top,
            // bottom content pinned at bottom via Spacer.
            VStack(spacing: 0) {
                // Top row — clear Dynamic Island (safe-area ≤ 59pt on all iPhones).
                HStack {
                    // Invisible spacer mirrors the back button (leading, ~50pt)
                    // so the avatar stack appears centred between the two buttons.
                    Color.clear.frame(width: 50)
                    Spacer()
                    AvatarStack(names: trip.participants.map(\.name))
                    Spacer()
                    HStack(spacing: 6) {
                        PhotosPicker(selection: $coverPickerItem, matching: .images) {
                            ZStack {
                                Circle().fill(.black.opacity(0.35))
                                if isUploadingCover {
                                    ProgressView().tint(.white).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploadingCover)

                        Button { showEditTrip = true } label: {
                            ZStack {
                                Circle().fill(.black.opacity(0.35))
                                Image(systemName: "pencil")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                // Bottom content: name + location + pills
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.name)
                        .font(.rounded(26, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text("\(trip.location) · \(Formatters.dateLabel(trip.date))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            pill("Undang", "person.badge.plus") { showInvite = true }
                            if let map = trip.mapLink, !map.isEmpty, let url = URL(string: map) {
                                pill("Lokasi", "mappin.and.ellipse") { openURL(url) }
                            }
                            if let wa = Formatters.waLink(for: trip.phone) {
                                pill("Chat", icon: {
                                    Image("ic_whatsapp")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                }) { openURL(wa) }
                            }
                            if let docs = trip.docsLink, !docs.isEmpty, let url = URL(string: docs) {
                                pill("Link", "link") { openURL(url) }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(16)
            }
            .frame(height: 230)
        }
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
        pill(title, icon: { Image(systemName: icon) }, action: action)
    }

    private func pill<Icon: View>(_ title: String, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { icon() }
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
