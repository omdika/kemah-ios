//
//  Sheets.swift
//  trip planner
//
//  Bottom sheets: Buat Trip Baru, Edit Peran, Undang Teman, and the mocked
//  Share summary. Item / Expense sheets live with their tabs.
//

import SwiftUI

// MARK: - Buat Trip Baru

struct NewTripSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var date = Date()
    @State private var mapLink = ""
    @State private var phone = ""
    @State private var docsLink = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LabeledField(title: "Nama Trip", placeholder: "Camping Kawah Putih", text: $name)
                    LabeledField(title: "Lokasi", placeholder: "Bandung", text: $location)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tanggal").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledField(title: "Link Peta (opsional)", placeholder: "https://maps.google.com/...", text: $mapLink)
                    LabeledField(title: "No. WhatsApp Admin (opsional)", placeholder: "08xxxxxxxxxx", text: $phone, keyboard: .phonePad)
                    LabeledField(title: "Link Dokumentasi (opsional)", placeholder: "https://drive.google.com/...", text: $docsLink)

                    PrimaryButton(title: "Buat Trip", color: store.accent.color) {
                        Task {
                            await store.createTrip(name: name, location: location, date: Formatters.isoDateString(from: date), mapLink: mapLink, phone: phone, docsLink: docsLink, coverUrl: "")
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Buat Trip Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Edit Detail Trip

struct EditTripSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var location: String
    @State private var date: Date
    @State private var mapLink: String
    @State private var phone: String
    @State private var docsLink: String

    init(trip: Trip) {
        _name = State(initialValue: trip.name)
        _location = State(initialValue: trip.location)
        _date = State(initialValue: Formatters.date(fromISODate: trip.date) ?? Date())
        _mapLink = State(initialValue: trip.mapLink ?? "")
        _phone = State(initialValue: trip.phone ?? "")
        _docsLink = State(initialValue: trip.docsLink ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LabeledField(title: "Nama Trip", placeholder: "Camping Kawah Putih", text: $name)
                    LabeledField(title: "Lokasi", placeholder: "Bandung", text: $location)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tanggal").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            // Pinned to UTC to match Formatters.date(fromISODate:)/
                            // isoDateString(from:) exactly — otherwise a device
                            // timezone behind UTC can display/re-save a day earlier.
                            .environment(\.timeZone, TimeZone(identifier: "UTC")!)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledField(title: "Link Peta (opsional)", placeholder: "https://maps.google.com/...", text: $mapLink)
                    LabeledField(title: "No. WhatsApp Admin (opsional)", placeholder: "08xxxxxxxxxx", text: $phone, keyboard: .phonePad)
                    LabeledField(title: "Link Dokumentasi (opsional)", placeholder: "https://drive.google.com/...", text: $docsLink)

                    PrimaryButton(title: "Simpan", color: store.accent.color) {
                        Task {
                            await store.updateActiveTrip(
                                UpdateTripRequest(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    location: location.trimmingCharacters(in: .whitespaces),
                                    date: Formatters.isoDateString(from: date),
                                    mapLink: mapLink,
                                    phone: phone,
                                    docsLink: docsLink
                                ),
                                toast: "Detail trip diperbarui"
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
            .navigationTitle("Edit Detail Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Edit Peran

struct RoleSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    let participant: Participant
    @State private var role: String
    @State private var headcount: Int

    private let presets = ["Koordinator", "PIC Tenda", "PIC Masak", "PIC Tidur", "PIC Tiket", "PIC Dokumentasi"]

    init(participant: Participant) {
        self.participant = participant
        _role = State(initialValue: participant.picForLabel)
        _headcount = State(initialValue: participant.headcount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledField(title: "Peran", placeholder: "PIC ...", text: $role)

                    FlowChips(items: presets, selected: role, accent: store.accent.color) { role = $0 }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Jumlah Orang").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
                        Stepper(value: $headcount, in: 0...20) {
                            Text(headcount == 0 ? "tidak ikut" : "\(headcount) orang").font(.headline)
                        }
                    }

                    PrimaryButton(title: "Simpan", color: store.accent.color) {
                        Task {
                            await store.updateParticipant(participant, role: role, headcount: headcount)
                            dismiss()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Edit Peran · \(participant.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Wrapping preset chips.
struct FlowChips: View {
    let items: [String]
    let selected: String
    var accent: Color = Theme.inkFixed
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selected == item ? accent : Theme.surface)
                        .foregroundStyle(selected == item ? Color.white : Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous)
                                .stroke(Theme.neutralPillBg, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Undang Teman

struct InviteSheet: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var link: String = "Memuat link..."

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(store.accent.color)
                    .padding(.top, 20)
                Text("Bagikan link ini ke teman-temanmu untuk bergabung ke trip.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)

                HStack {
                    Text(link).font(.footnote).lineLimit(1).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = link
                        store.showToast("Link disalin")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .padding(14)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))

                ShareLink(item: link) {
                    Label("Bagikan Link", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(store.accent.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Undang Teman")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Tutup") { dismiss() } } }
            .task {
                if let url = await store.inviteLink() { link = url }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
