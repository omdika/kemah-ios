//
//  LoginView.swift
//  trip planner
//
//  Auth entry. Google Sign-In is real (TripStore.signInWithGoogle); Apple is
//  still a mocked stub pending a paid Apple Developer account (needed for the
//  Sign in with Apple capability). Facebook was removed — no clean native
//  Supabase integration path (see conversation notes) and no real demand yet.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: TripStore

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(spacing: 12) {
                authButton(title: "Lanjutkan dengan Google", system: "g.circle.fill", filled: false) {
                    Task { await store.signInWithGoogle() }
                }
                authButton(title: "Masuk dengan Apple", system: "apple.logo", filled: true) {
                    Task { await store.signIn() }
                }

                Text("Dengan masuk, kamu setuju dengan Ketentuan Layanan & Kebijakan Privasi Kemah.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .alert(
            "Gagal masuk",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "EA6A2E"), Color(hex: "8E44AD")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "tent.2.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.18))
                    .padding(24)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Kemah")
                    .font(.rounded(48, weight: .bold))
                    .foregroundStyle(.white)
                Text("Rencanain trip kemah bareng, tanpa ribet bagi-bagi tugas & patungan.")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(24)
        }
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .ignoresSafeArea(edges: .top)
    }

    private func authButton(title: String, system: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: system)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(filled ? Theme.inkFixed : Theme.surface)
            .foregroundStyle(filled ? Color.white : Theme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                    .stroke(filled ? Color.clear : Theme.neutralPillBg, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
