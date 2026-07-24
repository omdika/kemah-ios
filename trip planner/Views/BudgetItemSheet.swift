//
//  BudgetItemSheet.swift
//  trip planner
//
//  Add/Edit Expense sheet. A Kelompok / Pribadi toggle picks the expense scope:
//  - Kelompok: Per Orang / Per PIC split, "Dibayar oleh", "Untuk siapa".
//  - Pribadi: a private personal expense (only visible to you, no split bill) —
//    just name, optional qty × unit price, and total.
//

import SwiftUI

struct BudgetItemSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let existing: BudgetItem?

    @State private var isPersonal: Bool
    @State private var splitMode: SplitMode
    @State private var name: String
    @State private var qtyText: String = ""
    @State private var unitText: String = ""
    @State private var jumlah: String
    @State private var paidBy: String
    @State private var untukSiapa: String

    private var participantNames: [String] { trip.participants.map(\.name) }

    init(trip: Trip, existing: BudgetItem?, initialPersonal: Bool = false) {
        self.trip = trip
        self.existing = existing
        _isPersonal = State(initialValue: existing?.isPersonal ?? initialPersonal)
        _splitMode = State(initialValue: existing?.splitMode ?? .orang)
        _name = State(initialValue: existing?.name ?? "")
        _jumlah = State(initialValue: existing.map { String(Int($0.price)) } ?? "")
        _paidBy = State(initialValue: existing?.paidBy ?? "")
        _untukSiapa = State(initialValue: existing?.pic ?? "")
    }

    /// qty × unit price auto-computes the total.
    private func recomputeJumlah() {
        if let q = Int(qtyText), let u = Int(unitText), q > 0, u > 0 {
            jumlah = String(q * u)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Scope", selection: $isPersonal) {
                        Text("Kelompok").tag(false)
                        Text("Pribadi").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isPersonal {
                        Text("Pengeluaran pribadi hanya terlihat olehmu dan tidak masuk split bill.")
                            .font(.caption2).foregroundStyle(Theme.textSubtle)
                    } else {
                        Picker("Split", selection: $splitMode) {
                            Text("Per Orang").tag(SplitMode.orang)
                            Text("Per PIC").tag(SplitMode.pic)
                        }
                        .pickerStyle(.segmented)
                    }

                    LabeledField(title: "Nama Pengeluaran", placeholder: isPersonal ? "Jajan & kopi" : "Bensin & tol", text: $name)

                    HStack(spacing: 12) {
                        LabeledField(title: "Qty (opsional)", placeholder: "1", text: $qtyText, keyboard: .numberPad)
                            .onChange(of: qtyText) { _ in recomputeJumlah() }
                        LabeledField(title: "Harga Satuan", placeholder: "0", text: $unitText, keyboard: .numberPad)
                            .onChange(of: unitText) { _ in recomputeJumlah() }
                    }

                    LabeledField(title: "Jumlah (Rp)", placeholder: "100000", text: $jumlah, keyboard: .numberPad)

                    if !isPersonal {
                        SearchableParticipantField(title: "Dibayar oleh", text: $paidBy, participants: participantNames, accent: store.accent.color)

                        if splitMode == .pic {
                            SearchableParticipantField(title: "Untuk siapa (opsional)", text: $untukSiapa, participants: participantNames, accent: store.accent.color)
                            Text("Kosongkan kalau biaya ini milik si pembayar sendiri.")
                                .font(.caption2).foregroundStyle(Theme.textSubtle)
                        }
                    }

                    PrimaryButton(title: existing == nil ? "Tambah" : "Simpan", color: store.accent.color) {
                        Task {
                            // Use "" (empty string) — not nil — when the intent is to clear pic.
                            // nil in a PATCH body means "don't update this field"; "" means "clear it".
                            let picValue: String? = (!isPersonal && splitMode == .pic)
                                ? untukSiapa.trimmingCharacters(in: .whitespaces)
                                : ""
                            let payer: String? = isPersonal
                                ? (store.user?.name)
                                : (paidBy.trimmingCharacters(in: .whitespaces).isEmpty ? nil : paidBy)
                            await store.saveBudgetItem(
                                existing: existing,
                                name: name.trimmingCharacters(in: .whitespaces),
                                price: Double(jumlah) ?? 0,
                                paidBy: payer,
                                pic: picValue,
                                splitMode: isPersonal ? .orang : splitMode,
                                isPersonal: isPersonal
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (Double(jumlah) ?? 0) <= 0)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(existing == nil ? "Tambah Pengeluaran" : "Edit Pengeluaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
