//
//  SplitBillCalculator.swift
//  trip planner
//
//  Client-side settlement engine. This is a faithful, line-for-line port of the
//  prototype's `computeTransfers` + `buildTripView` split-bill math (see
//  README.md "Split Bill Logic"). The contract allows computing this client-side
//  since the algorithm is deterministic and side-effect free.
//
//  Rules recap:
//  - Per-Orang items: pooled; each participant's share is proportional to headcount.
//  - Pooled Per-PIC items (pic blank/nil): pooled; split FLATLY by participant count.
//  - Self-paid Per-PIC items (pic == paidBy, non-empty): EXCLUDED from settlement.
//    The person already paid for their own cost; no redistribution to others.
//  - Direct-debt Per-PIC items (pic set and != paidBy): a fixed 1:1 debt, pic owes paidBy.
//  - Settlement = greedy debt simplification over pooled balances, then direct
//    debts appended as-is, then transfers merged by (from, to) pair.
//

import Foundation

// MARK: - Output types

struct SettlementResult: Equatable {
    var perPerson: [PerPersonRow]
    var transfers: [TransferRow]
}

struct PerPersonRow: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var colorIndex: Int
    /// What they actually fronted (pool contributions only, not direct debts).
    var contribution: Double
    /// Their fair share of the pool.
    var share: Double
    var balance: Double
    var headcount: Int
    /// Per-item pool breakdown — powers the "Bagi rata" transparency expansion.
    var poolDetails: [PoolItemDetail]
}

/// One pool item's attribution for a single participant.
struct PoolItemDetail: Equatable, Hashable {
    var name: String
    /// This person's fair share of the item (price/N for Per-PIC, price×hc/totalHc for Per-Orang).
    var share: Double
    /// What this person actually paid for this item (full price if they're the payer, else 0).
    var paid: Double
    /// Source `BudgetItem.id` — lets the UI look up `trip.budgetItems[].images`.
    var budgetItemId: String?
}

struct TransferRow: Identifiable, Equatable {
    var id: String { from + "__" + to }
    var from: String
    var to: String
    var total: Double
    var parts: [TransferPart]
    var hasParts: Bool { !parts.isEmpty }
}

struct TransferPart: Equatable, Hashable {
    var label: String
    var amount: Double
    /// Source `BudgetItem.id`; nil for merged "Bagi rata" parts (no single item applies).
    var budgetItemId: String?
}

// MARK: - Internal balance record

private struct BalanceRecord {
    var name: String
    var contribution: Double
    var headcount: Int
    var share: Double
    var balance: Double
    var colorIndex: Int
    var poolDetails: [PoolItemDetail]
}

// MARK: - Calculator

enum SplitBillCalculator {

    /// The effective payer of an item: `paidBy` when present & non-empty, else `pic`.
    /// Mirrors the prototype's `(it.paidBy || it.pic)`.
    private static func effectivePayer(_ item: BudgetItem) -> String? {
        if let paidBy = item.paidBy, !paidBy.isEmpty { return paidBy }
        return item.pic
    }

    private static func picIsSet(_ item: BudgetItem) -> Bool {
        guard let pic = item.pic, !pic.isEmpty else { return false }
        return true
    }

    /// True when pic == paidBy (non-empty): the person paid for themselves.
    /// Self-paid items are already settled and excluded from all pool/debt calculations.
    private static func isSelfPaid(_ item: BudgetItem) -> Bool {
        guard let pic = item.pic, !pic.isEmpty else { return false }
        return pic == item.paidBy
    }

    /// True when the item is a fixed 1:1 debt (pic set and different from paidBy).
    private static func isDirectDebt(_ item: BudgetItem) -> Bool {
        picIsSet(item) && item.pic != item.paidBy
    }

    static func compute(participants: [Participant], budgetItems: [BudgetItem]) -> SettlementResult {
        // Personal expenses are private and never part of the split.
        let groupItems = budgetItems.filter { !$0.isPersonal }
        let sharedItems = groupItems.filter { $0.splitMode != .pic }
        let picAllItems = groupItems.filter { $0.splitMode == .pic }
        let picDirectItems = picAllItems.filter { isDirectDebt($0) }
        // Self-paid items (pic == paidBy) are excluded: the person already covered their own cost.
        let picItems = picAllItems.filter { !isDirectDebt($0) && !isSelfPaid($0) }

        let sharedSpent = sharedItems.reduce(0) { $0 + $1.price }
        let picSpent = picItems.reduce(0) { $0 + $1.price }
        let totalHeadcount = max(participants.reduce(0) { $0 + max($1.headcount, 1) }, 1)
        let participantCount = max(participants.count, 1)
        let picSharePerPerson = picSpent / Double(participantCount)

        let balances: [BalanceRecord] = participants.enumerated().map { index, p in
            let headcount = max(p.headcount, 1)

            // Per-item pool breakdown for this person.
            // Per-PIC pooled: flat share = price / participantCount (headcount ignored).
            let picPoolDetails: [PoolItemDetail] = picItems.map { item in
                PoolItemDetail(
                    name: item.name,
                    share: item.price / Double(participantCount),
                    paid: effectivePayer(item) == p.name ? item.price : 0,
                    budgetItemId: item.id
                )
            }
            // Per-Orang pooled: proportional share = price × headcount / totalHeadcount.
            let orangPoolDetails: [PoolItemDetail] = sharedItems.map { item in
                PoolItemDetail(
                    name: item.name,
                    share: item.price * Double(headcount) / Double(totalHeadcount),
                    paid: effectivePayer(item) == p.name ? item.price : 0,
                    budgetItemId: item.id
                )
            }

            let contributionOrang = sharedItems
                .filter { effectivePayer($0) == p.name }
                .reduce(0) { $0 + $1.price }
            let contributionPic = picItems
                .filter { effectivePayer($0) == p.name }
                .reduce(0) { $0 + $1.price }
            let shareOrang = sharedSpent * (Double(headcount) / Double(totalHeadcount))
            let share = shareOrang + picSharePerPerson
            let contribution = contributionOrang + contributionPic
            return BalanceRecord(
                name: p.name,
                contribution: contribution,
                headcount: headcount,
                share: share,
                balance: contribution - share,
                colorIndex: index,
                poolDetails: picPoolDetails + orangPoolDetails
            )
        }

        let perPerson = balances.map { b in
            PerPersonRow(
                name: b.name,
                colorIndex: b.colorIndex,
                contribution: b.contribution,
                share: b.share,
                balance: b.balance,
                headcount: b.headcount,
                poolDetails: b.poolDetails
            )
        }

        // Pooled settlement transfers ("Bagi rata").
        let poolTransfers = computeTransfers(balances).map {
            RawTransfer(from: $0.from, to: $0.to, amount: $0.amount, label: "Bagi rata", budgetItemId: nil)
        }

        // Direct debts appended as-is.
        let directTransfers = picDirectItems.map { item in
            RawTransfer(
                from: item.pic ?? "",
                to: item.paidBy ?? (effectivePayer(item) ?? ""),
                amount: item.price,
                label: item.name,
                budgetItemId: item.id
            )
        }

        // Merge by (from, to) pair, preserving insertion order.
        var order: [String] = []
        var groups: [String: TransferRow] = [:]
        for tr in poolTransfers + directTransfers {
            let key = tr.from + "__" + tr.to
            if groups[key] == nil {
                groups[key] = TransferRow(from: tr.from, to: tr.to, total: 0, parts: [])
                order.append(key)
            }
            groups[key]?.total += tr.amount
            groups[key]?.parts.append(TransferPart(label: tr.label, amount: tr.amount, budgetItemId: tr.budgetItemId))
        }
        let transfers = order.compactMap { groups[$0] }

        return SettlementResult(
            perPerson: perPerson,
            transfers: transfers
        )
    }

    // MARK: - Greedy debt simplification (port of `computeTransfers`)

    private struct RawTransfer {
        var from: String
        var to: String
        var amount: Double
        var label: String
        var budgetItemId: String? = nil
    }

    private struct Party {
        var name: String
        var amt: Double
    }

    private static func computeTransfers(_ balances: [BalanceRecord]) -> [RawTransfer] {
        var debtors = balances
            .filter { $0.balance < -500 }
            .map { Party(name: $0.name, amt: -$0.balance) }
            .sorted { $0.amt > $1.amt }
        var creditors = balances
            .filter { $0.balance > 500 }
            .map { Party(name: $0.name, amt: $0.balance) }
            .sorted { $0.amt > $1.amt }

        var transfers: [RawTransfer] = []
        var di = 0
        var ci = 0
        while di < debtors.count && ci < creditors.count {
            let amt = min(debtors[di].amt, creditors[ci].amt)
            if amt > 500 {
                transfers.append(RawTransfer(from: debtors[di].name, to: creditors[ci].name, amount: amt, label: "Bagi rata"))
            }
            debtors[di].amt -= amt
            creditors[ci].amt -= amt
            if debtors[di].amt <= 500 { di += 1 }
            if creditors[ci].amt <= 500 { ci += 1 }
        }
        return transfers
    }
}
