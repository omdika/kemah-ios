//
//  LoginView.swift
//  trip planner
//
//  Auth entry. The prototype shows Google/Facebook/Apple buttons; on iOS these
//  should become real `Sign in with Apple` + Google Sign-In. Here they trigger
//  the store's (mock) sign-in and enter the app.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var store: TripStore

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(spacing: 12) {
                authButton(title: "Lanjutkan dengan Google", system: "g.circle.fill", filled: false)
                authButton(title: "Lanjutkan dengan Facebook", system: "f.circle.fill", filled: false)
                authButton(title: "Masuk dengan Apple", system: "apple.logo", filled: true)

                Text("Dengan masuk, kamu setuju dengan Ketentuan Layanan & Kebijakan Privasi Kemah.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
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

    private func authButton(title: String, system: String, filled: Bool) -> some View {
        Button {
            Task { await store.signIn() }
        } label: {
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
            .background(filled ? Theme.textPrimary : Theme.surface)
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
