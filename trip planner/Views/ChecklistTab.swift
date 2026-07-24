//
//  ChecklistTab.swift
//  trip planner
//
//  Packing checklist: overall progress, Perlengkapan Kelompok (with PIC) and
//  Perlengkapan Pribadi (no PIC) sections, per-item toggle/edit/delete, and an
//  add/edit item sheet.
//

import SwiftUI

struct ChecklistTab: View {
    @EnvironmentObject private var store: TripStore
    let trip: Trip
    @Binding var isPersonalSection: Bool  // tells TripDetailView which section is active for FAB

    @State private var editing: ChecklistItem?
    @State private var activeSection: Section = .kelompok

    private enum Section: String, CaseIterable {
        case kelompok = "Kelompok"
        case pribadi  = "Pribadi"
    }

    // Kelompok = items with an assigned PIC; Pribadi = items with no PIC (bring yourself)
    private var kelompok: [ChecklistItem] { trip.items.filter { !($0.pic ?? "").isEmpty } }
    private var pribadi:  [ChecklistItem] { trip.items.filter {  ($0.pic ?? "").isEmpty  } }
    private var kelompokChecked: Int { kelompok.filter(\.checked).count }
    private var pribadiChecked:  Int { pribadi.filter(\.checked).count  }
    private var allChecked: Int  { trip.items.filter(\.checked).count }
    private var progress: Double { trip.items.isEmpty ? 0 : Double(allChecked) / Double(trip.items.count) }

    var body: some View {
        VStack(spacing: 12) {
            progressCard
            sectionPicker
            captionRow
            sectionContent
        }
        .onChange(of: activeSection) { newSection in
            isPersonalSection = (newSection == .pribadi)
        }
        .sheet(item: $editing) { item in
            ItemSheet(trip: trip, existing: item, isPersonal: item.isPersonal)
        }
    }

    // MARK: Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(allChecked)/\(trip.items.count) beres")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.headline).foregroundStyle(store.accent.color)
            }
            ProgressBarView(value: progress, tint: store.accent.color)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: Section picker — white pill on gray track

//    private var sectionPicker: some View {
//        HStack(spacing: 4) {
//            ForEach(Section.allCases, id: \.self) { s in
//                let isActive = activeSection == s
//                Button { activeSection = s } label: {
//                    HStack(spacing: 5) {
//                        Text(s.rawValue)
//                            .font(.subheadline.weight(.semibold))
//                        if s == .pribadi {
//                            Image(systemName: "lock.fill").font(.caption2)
//                        }
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 10)
//                    .background(isActive ? Color.white : Color.clear)
//                    .foregroundStyle(isActive ? store.accent.color : Theme.textMuted)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                    .shadow(color: isActive ? .black.opacity(0.09) : .clear, radius: 4, x: 0, y: 2)
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .padding(4)
//        .background(Theme.surface)
//        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//    }
    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(Section.allCases, id: \.self) { s in
                let isActive = activeSection == s
                Button { activeSection = s } label: {
                    Text(s.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? Theme.surface : Color.clear)
                        .foregroundStyle(isActive ? store.accent.color : Theme.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: isActive ? .black.opacity(0.10) : .clear, radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.neutralPillBg)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: Caption + counter

    private var captionRow: some View {
        let isKelompok = activeSection == .kelompok
        let caption = isKelompok
            ? "Butuh PIC — yang bertanggung jawab bawa"
            : "Dibawa masing-masing peserta sendiri — nggak perlu PIC"
        let checked = isKelompok ? kelompokChecked : pribadiChecked
        let total   = isKelompok ? kelompok.count  : pribadi.count
        return HStack(alignment: .firstTextBaseline) {
            Text(caption)
                .font(.caption).foregroundStyle(Theme.textMuted)
            Spacer()
            Text("\(checked)/\(total)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.textMuted)
        }
    }

    // MARK: Section content

    @ViewBuilder
    private var sectionContent: some View {
        if activeSection == .kelompok {
            itemList(kelompok)
        } else {
            itemList(pribadi)
        }
    }

    private func itemList(_ items: [ChecklistItem]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                ChecklistRow(
                    item: item,
                    accent: store.accent.color,
                    toggle: { Task { await store.toggleItem(item) } },
                    edit: { editing = item },
                    remove: { Task { await store.deleteItem(item) } }
                )
            }
        }
    }
}

// MARK: - Row

struct ChecklistRow: View {
    let item: ChecklistItem
    let accent: Color
    let toggle: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    private var metaLine: String? {
        if item.isPersonal {
            return item.note.isEmpty ? nil : item.note
        }
        var parts: [String] = []
        if let pic = item.pic, !pic.isEmpty { parts.append("PIC: \(pic)") }
        if !item.note.isEmpty { parts.append(item.note) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(item.checked ? accent : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(item.checked ? accent : Theme.neutralPillBg, lineWidth: 1.5)
                        )
                    if item.checked {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.qty > 1 ? "\(item.name) ×\(item.qty)" : item.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? Theme.textSubtle : Theme.textPrimary)
                if let meta = metaLine {
                    Text(meta).font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.textSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .cardStyle(radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
    }
}

// MARK: - Add / Edit sheet

struct ItemSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    let trip: Trip
    let existing: ChecklistItem?

    @State private var isPersonal: Bool
    @State private var name: String
    @State private var qty: String
    @State private var pic: String
    @State private var note: String

    init(trip: Trip, existing: ChecklistItem?, isPersonal: Bool) {
        self.trip = trip
        self.existing = existing
        _isPersonal = State(initialValue: existing?.isPersonal ?? isPersonal)
        _name = State(initialValue: existing?.name ?? "")
        _qty = State(initialValue: String(existing?.qty ?? 1))
        _pic = State(initialValue: existing?.pic ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Tipe", selection: $isPersonal) {
                        Text("Kelompok").tag(false)
                        Text("Pribadi").tag(true)
                    }
                    .pickerStyle(.segmented)

                    LabeledField(title: "Nama Barang", placeholder: "Tenda dome", text: $name)
                    LabeledField(title: "Jumlah", placeholder: "1", text: $qty, keyboard: .numberPad)

                    if !isPersonal {
                        SearchableParticipantField(title: "PIC (penanggung jawab)", text: $pic, participants: trip.participants.map(\.name), accent: store.accent.color)
                    }
                    LabeledField(title: "Catatan (opsional)", placeholder: "cek kelengkapan", text: $note)

                    PrimaryButton(title: existing == nil ? "Tambah" : "Simpan", color: store.accent.color) {
                        Task {
                            await store.saveItem(
                                existing: existing,
                                name: name.trimmingCharacters(in: .whitespaces),
                                qty: Int(qty) ?? 1,
                                pic: isPersonal ? nil : (pic.isEmpty ? nil : pic),
                                note: note,
                                isPersonal: isPersonal
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(existing == nil ? "Tambah Barang" : "Edit Barang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
