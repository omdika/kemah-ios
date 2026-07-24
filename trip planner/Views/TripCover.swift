//
//  TripCover.swift
//  trip planner
//
//  Cover photo view shared by the Home card and the Trip Detail header. Loads
//  `coverUrl` when present; otherwise renders a deterministic gradient
//  placeholder keyed off the trip id (same trip -> same placeholder everywhere).
//

import SwiftUI

struct CoverImage: View {
    let url: String?
    let seed: String

    private var gradient: LinearGradient {
        let palette: [[Color]] = [
            [Color(hex: "EA6A2E"), Color(hex: "8E44AD")],
            [Color(hex: "2E9E6B"), Color(hex: "1E6091")],
            [Color(hex: "3D7EE0"), Color(hex: "6C3FB5")],
            [Color(hex: "CE5F5A"), Color(hex: "E08A2E")],
        ]
        let idx = abs(seed.hashValue) % palette.count
        return LinearGradient(colors: palette[idx], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url), !url.isEmpty {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        gradient.overlay(alignment: .bottomTrailing) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.22))
                .padding(16)
        }
    }
}
