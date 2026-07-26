//
//  Components.swift
//  trip planner
//
//  Small reusable views shared across screens: avatars, avatar stacks, the
//  offline indicator, progress bar, pills, toast, and the searchable
//  participant dropdown described in the handoff.
//

import SwiftUI

// MARK: - Avatar

struct InitialsAvatar: View {
    let name: String
    let colorIndex: Int
    var size: CGFloat = 36

    private var initial: String {
        String(name.first.map(String.init) ?? "?").uppercased()
    }

    var body: some View {
        Circle()
            .fill(Theme.avatarColor(index: colorIndex))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.rounded(size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// Overlapping avatar stack. Shows up to `maxShown` avatars; if more exist,
/// appends a "···" pill so the width stays bounded regardless of participant count.
/// Tap (or hover on pointer devices) to reveal the full participant list.
struct AvatarStack: View {
    let names: [String]
    var size: CGFloat = 30
    var maxShown: Int = 3

    @State private var showNames = false

    var body: some View {
        let shown = Array(names.prefix(maxShown))
        let hasMore = names.count > maxShown
        HStack(spacing: -size * 0.35) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, name in
                InitialsAvatar(name: name, colorIndex: index, size: size)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    .zIndex(Double(shown.count - index))
            }
            if hasMore {
                Circle()
                    .fill(Theme.neutralPillBg)
                    .frame(width: size, height: size)
                    .overlay(
                        Text("···")
                            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                            .offset(y: -size * 0.05)
                    )
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
            }
        }
        .onTapGesture { showNames = true }
        // pointer devices (iPadOS + trackpad, Mac Catalyst)
        .help(names.joined(separator: "\n"))
        .popover(isPresented: $showNames) {
            participantTooltip
                .presentationDetents([.height(CGFloat(min(names.count, 8) * 48 + 48))])
                .presentationDragIndicator(.visible)
        }
    }

    private var participantTooltip: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Peserta (\(names.count))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 10) {
                    InitialsAvatar(name: name, colorIndex: index, size: 28)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < names.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .frame(minWidth: 220)
        .background(Theme.background)
    }
}

// MARK: - Offline indicator

struct OfflineIndicatorRow: View {
    @Binding var isOffline: Bool

    var body: some View {
        Button {
            isOffline.toggle()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOffline ? Theme.offlineDot : Theme.onlineDot)
                    .frame(width: 8, height: 8)
                Text(isOffline ? "Mode Offline · data tersimpan di perangkat" : "Tersambung · tersinkron")
                    .font(.footnote)
                    .foregroundStyle(Theme.textMuted)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress bar

struct ProgressBarView: View {
    let value: Double // 0...1
    var tint: Color = Theme.textPrimary
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.neutralPillBg)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tag / pill

struct TagLabel: View {
    let text: String
    var fg: Color = Theme.textMuted
    var bg: Color = Theme.neutralPillBg

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous))
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.textPrimary.opacity(0.92))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.bottom, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension View {
    /// Overlays a bottom toast driven by an optional message binding.
    func toast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let msg = message.wrappedValue {
                ToastView(message: msg)
            }
        }
        .animation(.spring(), value: message.wrappedValue)
    }
}

// MARK: - Searchable participant field

/// Text field with a live-filtered dropdown of participant names. Typing filters;
/// selecting fills + closes; a non-matching typed value is still accepted as-is.
struct SearchableParticipantField: View {
    let title: String
    @Binding var text: String
    let participants: [String]
    var accent: Color = Theme.textPrimary

    @State private var isExpanded = false
    @FocusState private var focused: Bool

    private var matches: [String] {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return participants }
        return participants.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textMuted)

            TextField("Ketik atau pilih nama", text: $text)
                .focused($focused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                .onChange(of: focused) { now in
                    withAnimation { isExpanded = now }
                }

            if isExpanded && !matches.isEmpty {
                VStack(spacing: 0) {
                    ForEach(matches, id: \.self) { name in
                        Button {
                            text = name
                            focused = false
                            withAnimation { isExpanded = false }
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if name != matches.last { Divider() }
                    }
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                        .stroke(Theme.neutralPillBg, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Labeled text field

struct LabeledField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textMuted)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    var color: Color = Theme.inkFixed
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
