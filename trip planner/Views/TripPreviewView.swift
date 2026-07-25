//
//  TripPreviewView.swift
//  trip planner
//
//  Guest-mode preview shown whenever an invite link is opened (before the
//  user has actually joined), regardless of whether they're signed in.
//  Read-only: backed by GET /trips/:id/invite/preview, which deliberately
//  excludes budget/money data and per-item checklist detail. Presented as a
//  fullScreenCover from ContentView, keyed on TripStore.pendingInvite.
//

import SwiftUI

struct TripPreviewView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    /// True from the moment the CTA is tapped until sign-in/join fully
    /// resolves. Freezes the button on a "Memproses..." state instead of
    /// relabeling mid-flight when `store.isAuthenticated` flips partway
    /// through (which otherwise looks like the tap didn't register and
    /// invites a confusing second tap).
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            if let preview = store.invitePreview {
                ScrollView {
                    header(preview)
                    content(preview)
                }
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .bottom) { ctaBar }
            } else if store.isLoadingInvitePreview {
                ProgressView().tint(store.accent.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .alert(
            "Gagal memuat undangan",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private func header(_ preview: TripPreview) -> some View {
        ZStack(alignment: .bottomLeading) {
            CoverImage(url: preview.coverUrl, seed: preview.id)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 6) {
                Text("Kamu diundang gabung")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(preview.name)
                    .font(.rounded(28, weight: .bold))
                    .foregroundStyle(.white)
                Label("\(preview.location) · \(Formatters.dateLabel(preview.date))", systemImage: "mappin.and.ellipse")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .frame(height: 230)
        .clipped()
    }

    // MARK: - Body

    private func content(_ preview: TripPreview) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Peserta (\(preview.participants.count))")
                    .font(.headline)
                AvatarStack(names: preview.participants.map(\.name), size: 34, maxShown: 5)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(preview.participants) { p in
                        Text("\(p.name) · \(p.picForLabel)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Persiapan Checklist")
                        .font(.headline)
                    Spacer()
                    Text("\(preview.checklistProgress.checked)/\(preview.checklistProgress.total) siap")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textMuted)
                }
                ProgressBarView(
                    value: preview.checklistProgress.total > 0
                        ? Double(preview.checklistProgress.checked) / Double(preview.checklistProgress.total)
                        : 0,
                    tint: store.accent.color
                )
                .frame(height: 8)
            }

            Text("Detail budget & checklist lengkap kebuka setelah kamu gabung.")
                .font(.caption)
                .foregroundStyle(Theme.textSubtle)
        }
        .padding(20)
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 10) {
            if isProcessing {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(store.accent.color)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            } else if store.isAuthenticated {
                Button {
                    runProcessing { await store.joinPendingInvite() }
                } label: {
                    Text("Gabung Trip Ini")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(store.accent.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
            } else {
                Button {
                    runProcessing { await store.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                        Text("Lanjutkan dengan Google untuk Gabung")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Theme.surface)
                    .foregroundStyle(Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                            .stroke(Theme.neutralPillBg, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Theme.background)
    }

    private func runProcessing(_ action: @escaping () async -> Void) {
        isProcessing = true
        Task {
            await action()
            isProcessing = false
        }
    }

    // MARK: - Misc

    private var closeButton: some View {
        Button {
            store.pendingInvite = nil
            store.invitePreview = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, .black.opacity(0.35))
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSubtle)
            Text("Undangan tidak ditemukan atau sudah kedaluwarsa.")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
            Button("Tutup") {
                store.pendingInvite = nil
                store.invitePreview = nil
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
