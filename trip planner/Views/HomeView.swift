//
//  HomeView.swift
//  trip planner
//
//  Trip list home: greeting header, offline indicator, "Akan Datang" cards,
//  "Riwayat" rows, a floating + button (Buat Trip Baru), and a 2-tab bar.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TripStore
    @Binding var path: [Route]

    @State private var showNewTrip = false
    @State private var selectedTab: HomeTab = .trip

    enum HomeTab { case trip, profil }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            if selectedTab == .trip {
                tripList
            } else {
                ProfileStub()
            }

            floatingButton
            tabBar
        }
        .sheet(isPresented: $showNewTrip) {
            NewTripSheet()
        }
    }

    // MARK: Trip list

    private var tripList: some View {
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                OfflineIndicatorRow(isOffline: $store.isOffline)

                if !store.upcomingTrips.isEmpty {
                    section(title: "Akan Datang") {
                        ForEach(store.upcomingTrips) { trip in
                            Button {
                                Task {
                                    await store.openTrip(id: trip.id)
                                    path.append(.trip(trip.id))
                                }
                            } label: {
                                UpcomingTripCard(trip: trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !store.historyTrips.isEmpty {
                    section(title: "Riwayat") {
                        ForEach(store.historyTrips) { trip in
                            HistoryTripRow(trip: trip) {
                                store.showToast("Ringkasan \"\(trip.name)\" dibagikan")
                            } open: {
                                Task {
                                    await store.openTrip(id: trip.id)
                                    path.append(.trip(trip.id))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Halo, \(store.user?.name ?? "Kamu")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                Text("Trip Kamu")
                    .font(.rounded(32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            InitialsAvatar(name: store.user?.name ?? "K", colorIndex: 0, size: 44)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.rounded(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    // MARK: Floating button

    private var floatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showNewTrip = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(store.accent.color)
                        .clipShape(Circle())
                        .shadow(color: store.accent.color.opacity(0.4), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 78)
            }
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack {
            tabButton(.trip, "Trip", "map.fill")
            tabButton(.profil, "Profil", "person.fill")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func tabButton(_ tab: HomeTab, _ title: String, _ icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selectedTab == tab ? store.accent.color : Theme.textSubtle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming card

struct UpcomingTripCard: View {
    let trip: TripSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImage(url: trip.coverUrl, seed: trip.id)
                .frame(height: 140)
                .clipped()

            VStack(alignment: .leading, spacing: 10) {
                Text(trip.name)
                    .font(.rounded(19, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Label("\(trip.location) · \(Formatters.dateLabel(trip.date))", systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(Theme.textMuted)
                    .labelStyle(.titleAndIcon)

                HStack {
                    Text("\(trip.checklistProgress.checked)/\(trip.checklistProgress.total) siap")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                    if trip.mapLink?.isEmpty == false {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.textSubtle)
                    }
                    if Formatters.waLink(for: trip.phone) != nil {
                        Image(systemName: "message.circle.fill").foregroundStyle(Theme.onlineDot)
                    }
                }
            }
            .padding(14)
        }
        .cardStyle()
    }
}

// MARK: - History row

struct HistoryTripRow: View {
    let trip: TripSummary
    let share: () -> Void
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(url: trip.coverUrl, seed: trip.id)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(Formatters.dateLabel(trip.date))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Button(action: share) {
                Label("Bagikan", systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .cardStyle(radius: 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}

// MARK: - Profile stub

struct ProfileStub: View {
    @EnvironmentObject private var store: TripStore
    var body: some View {
        VStack(spacing: 16) {
            InitialsAvatar(name: store.user?.name ?? "K", colorIndex: 0, size: 72)
            Text(store.user?.name ?? "Kamu").font(.rounded(22, weight: .bold))
            Text(store.user?.email ?? "").font(.footnote).foregroundStyle(Theme.textMuted)
            Button("Keluar") { store.signOut() }
                .foregroundStyle(Theme.debit)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
