//
//  TripCover.swift
//  trip planner
//
//  Cover photo view shared by the Home card and the Trip Detail header. Loads
//  `coverUrl` when present; otherwise renders a deterministic gradient
//  placeholder keyed off the trip id (same trip -> same placeholder everywhere).
//
//  Images are cached in a process-wide NSCache so navigating from list to detail
//  shows the cover instantly without a second network round-trip.
//

import SwiftUI
import Combine

// MARK: - Shared in-memory cache

final class CoverImageCache {
    static let shared = CoverImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 60 }

    func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func store(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}

// MARK: - Per-view loader (ObservableObject for iOS 16)

@MainActor
private final class CoverLoader: ObservableObject {
    @Published var image: UIImage?
    private var loadedURL: String?

    func load(_ urlString: String) {
        guard urlString != loadedURL else { return }
        loadedURL = urlString

        // Cache hit — no network needed
        if let cached = CoverImageCache.shared.image(for: urlString) {
            image = cached
            return
        }

        image = nil
        guard let url = URL(string: urlString) else { return }

        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            CoverImageCache.shared.store(uiImage, for: urlString)
            self.image = uiImage
        }
    }
}

// MARK: - View

struct CoverImage: View {
    let url: String?
    let seed: String

    @StateObject private var loader = CoverLoader()

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
            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .onAppear { startLoad() }
        .onChange(of: url) { _ in startLoad() }
    }

    private func startLoad() {
        guard let url, !url.isEmpty else { return }
        loader.load(url)
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
