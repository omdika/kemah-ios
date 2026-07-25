//
//  ContentView.swift
//  trip planner
//
//  Root view. Gates on auth (Login vs the main NavigationStack) and hosts the
//  toast overlay. Navigation routes: trip detail and the split-bill screen.
//

import SwiftUI
import GoogleSignIn

struct ContentView: View {
    @StateObject private var store = TripStore(repository: AppConfig.makeRepository())
    @State private var path: [Route] = []

    var body: some View {
        Group {
            if store.isRestoringSession {
                Theme.background.ignoresSafeArea()
            } else if store.isAuthenticated {
                NavigationStack(path: $path) {
                    HomeView(path: $path)
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .trip:
                                TripDetailView(path: $path)
                            case .splitBill:
                                SplitBillView(path: $path)
                            }
                        }
                }
            } else {
                LoginView()
            }
        }
        .tint(store.accent.color)
        .environmentObject(store)
        .toast($store.toastMessage)
        .fullScreenCover(item: $store.pendingInvite) { _ in
            TripPreviewView().environmentObject(store)
        }
        .task {
            await store.restoreSession()
        }
        .onOpenURL { url in
            if !GIDSignIn.sharedInstance.handle(url) {
                store.handleIncomingURL(url)
            }
        }
        .onChange(of: store.justJoinedTripId) { tripId in
            guard let tripId else { return }
            store.justJoinedTripId = nil
            // Match HomeView's own trip-tap pattern: fetch the detail before
            // pushing, otherwise TripDetailView pushes with a stale/nil
            // activeTrip and sits on its loading spinner forever — nothing
            // else ever populates it.
            Task {
                await store.openTrip(id: tripId)
                path.append(.trip(tripId))
            }
        }
    }
}

#Preview {
    ContentView()
}
