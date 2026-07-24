//
//  SplitBillView.swift
//  trip planner
//
//  Dedicated Split Bill screen. Renders the ported settlement: per-person
//  summary with net-balance pills, and the minimal-transaction transfer list
//  (merged by recipient, expandable to parts, each markable as paid).
//

import SwiftUI

struct SplitBillView: View {
    @EnvironmentObject private var store: TripStore
    @Binding var path: [Route]

    @State private var paid: Set<String> = []
    @State private var expanded: Set<String> = []

    var body: some View {
        Group {
            if let trip = store.activeTrip, let result = store.activeSettlement {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        banner(result)
                        perPersonSection(result)
                        transfersSection(result)
                        ShareLink(item: shareText(result)) {
                            Label("Bagikan Ringkasan", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Theme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                        }
                    }
                    .padding(20)
                }
                .background(Theme.background)
                .task(id: trip.id) {
                    await store.loadSettlement(for: trip)
                }
            } else if let trip = store.activeTrip {
                ProgressView("Menghitung...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                    .task(id: trip.id) {
                        await store.loadSettlement(for: trip)
                    }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Split Bill")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Banner

    private func banner(_ r: SettlementResult) -> some View {
        VStack(spacing: 4) {
            Text("Dibagi \(r.participantCount) orang")
                .font(.subheadline).foregroundStyle(Theme.textMuted)
            Text("\(r.equalShareLabel) / orang")
                .font(.rounded(24, weight: .bold)).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .cardStyle()
    }

    // MARK: Per person

    private func perPersonSection(_ r: SettlementResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ringkasan per Orang").font(.rounded(17, weight: .bold)).foregroundStyle(Theme.textPrimary)
            VStack(spacing: 8) {
                ForEach(r.perPerson) { row in
                    HStack(spacing: 12) {
                        InitialsAvatar(name: row.name, colorIndex: row.colorIndex, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text("Bayar \(Formatters.rp(row.contribution)) · jatah \(Formatters.rp(row.share)) (\(row.headcount) orang)")
                                .font(.caption).foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        balancePill(row.balance)
                    }
                    .padding(12)
                    .cardStyle(radius: 12)
                }
            }
        }
    }

    private func balancePill(_ balance: Double) -> some View {
        let settled = abs(balance) < 1000
        let text = settled ? "Lunas" : (balance > 0 ? "+ \(Formatters.rp(balance))" : "− \(Formatters.rp(-balance))")
        let fg = settled ? Theme.textMuted : (balance > 0 ? Theme.credit : Theme.debit)
        let bg = settled ? Theme.neutralPillBg : (balance > 0 ? Theme.creditSoftBg : Theme.debitSoftBg)
        return Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(bg).foregroundStyle(fg)
            .clipShape(Capsule())
    }

    // MARK: Transfers

    private func transfersSection(_ r: SettlementResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transfer yang Perlu Dilakukan").font(.rounded(17, weight: .bold)).foregroundStyle(Theme.textPrimary)

            if r.transfers.isEmpty {
                Text("Semua sudah lunas. Tidak ada transfer. 🎉")
                    .font(.subheadline).foregroundStyle(Theme.textMuted)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardStyle(radius: 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(r.transfers) { transfer in
                        transferRow(transfer, result: r)
                    }
                }
            }
        }
    }

    private func transferRow(_ t: TransferRow, result: SettlementResult) -> some View {
        let isPaid = paid.contains(t.id)
        let isExpanded = expanded.contains(t.id)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    if isPaid { paid.remove(t.id) } else { paid.insert(t.id) }
                } label: {
                    Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isPaid ? Theme.credit : Theme.textSubtle)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(t.from).font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right").font(.caption2)
                        Text(t.to).font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    if t.hasParts {
                        Text("\(t.parts.count) rincian").font(.caption2).foregroundStyle(Theme.textSubtle)
                    }
                }
                Spacer()
                Text(Formatters.rp(t.total))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                if t.hasParts {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(Theme.textSubtle)
                }
            }
            .strikethrough(isPaid)
            .opacity(isPaid ? 0.5 : 1)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(Array(t.parts.enumerated()), id: \.offset) { _, part in
                        if part.label == "Bagi rata",
                           let debtor = result.perPerson.first(where: { $0.name == t.from }) {
                            poolBreakdownView(debtor, amount: part.amount)
                        } else {
                            HStack {
                                Text(part.label).font(.caption).foregroundStyle(Theme.textMuted)
                                Spacer()
                                Text(Formatters.rp(part.amount))
                                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .cardStyle(radius: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard t.hasParts else { return }
            if isExpanded { expanded.remove(t.id) } else { expanded.insert(t.id) }
        }
    }

    // MARK: Pool breakdown (Level B transparency)

    /// Full per-item attribution for the "Bagi rata" portion of a transfer.
    /// Shows what the debtor owes from the pool, what they already paid in,
    /// and how the net settlement amount is derived.
    private func poolBreakdownView(_ debtor: PerPersonRow, amount: Double) -> some View {
        let oweItems  = debtor.poolDetails.filter { $0.paid == 0 }
        let paidItems = debtor.poolDetails.filter { $0.paid > 0 }
        let totalShare = debtor.poolDetails.reduce(0.0) { $0 + $1.share }
        let totalPaid  = paidItems.reduce(0.0) { $0 + $1.paid }

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption2)
                Text("Pool ongkos bersama — \(debtor.name)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.textSubtle)
            .padding(.bottom, 10)

            // Section A: items this person owes (they didn't pay them)
            if !oweItems.isEmpty {
                Text("Tanggungan dari pool:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSubtle)
                    .padding(.bottom, 4)
                ForEach(Array(oweItems.enumerated()), id: \.offset) { _, detail in
                    HStack(alignment: .firstTextBaseline) {
                        Text(detail.name)
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(Formatters.rp(detail.share))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                            .monospacedDigit()
                    }
                }
            }

            // Section B: items this person paid into pool (credits)
            if !paidItems.isEmpty {
                Text("Sudah dibayar \(debtor.name) ke pool:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSubtle)
                    .padding(.top, 8).padding(.bottom, 4)
                ForEach(Array(paidItems.enumerated()), id: \.offset) { _, detail in
                    HStack(alignment: .firstTextBaseline) {
                        Text(detail.name)
                            .font(.caption)
                            .foregroundStyle(Theme.credit)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("−\(Formatters.rp(detail.paid))")
                            .font(.caption)
                            .foregroundStyle(Theme.credit)
                            .monospacedDigit()
                    }
                }
            }

            // Net summary line
            Divider().padding(.vertical, 8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Formatters.rp(totalShare)) − \(Formatters.rp(totalPaid))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSubtle)
                Spacer()
                Text("= \(Formatters.rp(amount))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.debit)
                    .monospacedDigit()
            }
        }
        .padding(12)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func shareText(_ r: SettlementResult) -> String {
        var lines = ["Split Bill — \(store.activeTrip?.name ?? "Trip")", "Dibagi \(r.participantCount) orang · \(r.equalShareLabel)/orang", ""]
        for t in r.transfers {
            lines.append("\(t.from) → \(t.to): \(Formatters.rp(t.total))")
        }
        return lines.joined(separator: "\n")
    }
}
