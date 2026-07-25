//
//  BudgetTab.swift
//  trip planner
//
//  Budget tab. The group budget card + "Pengeluaran Kelompok" list feed the
//  split bill. "Pengeluaran Pribadi" is a separate, private section (only the
//  logged-in user's own personal expenses) with no split — just a shareable
//  summary. Personal expenses are excluded from the group total and split bill.
//

import SwiftUI

struct BudgetTab: View {
    @EnvironmentObject private var store: TripStore
    let trip: Trip

    @State private var editing: BudgetItem?
    @State private var showTargetSheet = false

    private var groupItems: [BudgetItem] { trip.budgetItems.filter { !$0.isPersonal } }
    private var personalItems: [BudgetItem] { trip.budgetItems.filter { $0.isPersonal } }

    private var spent: Double { groupItems.reduce(0) { $0 + $1.price } }
    private var personalTotal: Double { personalItems.reduce(0) { $0 + $1.price } }
    private var isAuto: Bool { trip.budgetMode == .auto }
    private var target: Double { isAuto ? spent : trip.budgetTarget }
    private var pct: Double {
        if isAuto { return spent > 0 ? 1 : 0 }
        return trip.budgetTarget > 0 ? min(1, spent / trip.budgetTarget) : 0
    }
    private var isOver: Bool { !isAuto && trip.budgetTarget > 0 && spent > trip.budgetTarget }

    var body: some View {
        VStack(spacing: 16) {
            budgetCard
            groupExpenseSection
            personalExpenseSection
        }
        .sheet(item: $editing) { item in
            BudgetItemSheet(trip: trip, existing: item)
        }
        .sheet(isPresented: $showTargetSheet) {
            BudgetTargetSheet(current: trip.budgetTarget)
        }
    }

    // MARK: Budget card

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Total Budget").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                modeToggle
            }

            Text(Formatters.rp(target))
                .font(.rounded(24, weight: .bold))
                .foregroundStyle(.white)

            ProgressBarView(value: pct, tint: .white, height: 6)
                .opacity(0.95)

            HStack {
                Text("Terpakai \(Formatters.rp(spent))")
                    .font(.footnote).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(Int((pct * 100).rounded()))%")
                    .font(.footnote.weight(.bold)).foregroundStyle(.white)
            }

            if isOver {
                Label("Melebihi budget \(Formatters.rp(spent - trip.budgetTarget))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            if !isAuto {
                Button { showTargetSheet = true } label: {
                    Label("Edit Target", systemImage: "pencil")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [store.accent.color, store.accent.color.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            modeButton("Otomatis", active: isAuto) { Task { await store.updateActiveTrip(UpdateTripRequest(budgetMode: .auto)) } }
            modeButton("Manual", active: !isAuto) { Task { await store.updateActiveTrip(UpdateTripRequest(budgetMode: .manual)) } }
        }
        .padding(3)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
    }

    private func modeButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(active ? Color.white : Color.clear)
                .foregroundStyle(active ? store.accent.color : .white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Group expenses

    private var groupExpenseSection: some View {
        VStack(spacing: 10) {
            Text("Pengeluaran Kelompok")
                .font(.rounded(17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                ForEach(groupItems) { item in
                    ExpenseRow(item: item,
                               currentUserId: store.user?.id,
                               edit: { editing = item },
                               remove: { Task { await store.deleteBudgetItem(item) } },
                               uploadImage: { data in await store.uploadBudgetItemImage(item, data: data, fileName: "photo.jpg", mimeType: "image/jpeg") },
                               deleteImage: { imageId in await store.deleteBudgetItemImage(item, imageId: imageId) })
                }
            }
        }
    }

    // MARK: Personal expenses (private, no split)

    private var personalExpenseSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("Pengeluaran Pribadi")
                    .font(.rounded(17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Theme.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text("Hanya terlihat olehmu · tidak dibagi ke peserta lain")
                .font(.caption).foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                ForEach(personalItems) { item in
                    ExpenseRow(item: item,
                               currentUserId: store.user?.id,
                               edit: { editing = item },
                               remove: { Task { await store.deleteBudgetItem(item) } },
                               uploadImage: { data in await store.uploadBudgetItemImage(item, data: data, fileName: "photo.jpg", mimeType: "image/jpeg") },
                               deleteImage: { imageId in await store.deleteBudgetItemImage(item, imageId: imageId) })
                }
            }

            if !personalItems.isEmpty {
                HStack {
                    Text("Total pribadi").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(Formatters.rp(personalTotal)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
                }
                .padding(12)
                .cardStyle(radius: 12)

                ShareLink(item: personalSummaryText) {
                    Label("Bagikan Ringkasan", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.accent.color)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var personalSummaryText: String {
        var lines = ["Pengeluaran pribadiku — \(trip.name)", ""]
        for item in personalItems {
            lines.append("• \(item.name): \(Formatters.rp(item.price))")
        }
        lines.append("")
        lines.append("Total: \(Formatters.rp(personalTotal))")
        return lines.joined(separator: "\n")
    }


}

// MARK: - Expense row

struct ExpenseRow: View {
    let item: BudgetItem
    let currentUserId: String?
    let edit: () -> Void
    let remove: () -> Void
    let uploadImage: (Data) async -> Void
    let deleteImage: (String) async -> Void

    private var payerLine: String {
        if item.isPersonal { return "Pengeluaran pribadi" }
        let paidBy = item.paidBy ?? "?"
        if let pic = item.pic, !pic.isEmpty, pic != item.paidBy {
            return "Dibayar \(paidBy) untuk \(pic)"
        }
        return "Dibayar \(paidBy)"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
                Text(payerLine).font(.caption).foregroundStyle(Theme.textMuted)
                if item.isPersonal {
                    TagLabel(text: "Pribadi", fg: Color(hex: "7A3EA0"), bg: Color(hex: "EEE3F6"))
                } else {
                    TagLabel(
                        text: item.splitMode == .pic ? "Per PIC" : "Per Orang",
                        fg: item.splitMode == .pic ? Color(hex: "7A3EA0") : Color(hex: "2E7A52"),
                        bg: item.splitMode == .pic ? Color(hex: "EEE3F6") : Color(hex: "E1F2EA")
                    )
                }
            }
            Spacer()
            ImageStripButton(
                images: item.images, size: 32, currentUserId: currentUserId,
                onUpload: uploadImage, onDelete: deleteImage
            )
            VStack(alignment: .trailing, spacing: 8) {
                Text(Formatters.rp(item.price)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
                Button(action: remove) {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.textSubtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .cardStyle(radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }
}

// MARK: - Edit target sheet

struct BudgetTargetSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var value: String

    init(current: Double) { _value = State(initialValue: current > 0 ? String(Int(current)) : "") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LabeledField(title: "Target Budget (Rp)", placeholder: "1200000", text: $value, keyboard: .numberPad)
                PrimaryButton(title: "Simpan", color: store.accent.color) {
                    Task {
                        await store.updateActiveTrip(UpdateTripRequest(budgetTarget: Double(value) ?? 0), toast: "Target budget diperbarui")
                        dismiss()
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Edit Target Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } } }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }
}
