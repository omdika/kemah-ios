//
//  ImageGallery.swift
//  trip planner
//
//  Small square photo entry point (like an avatar) shown in checklist/budget
//  rows and the split-bill breakdown. Empty -> tapping opens the system photo
//  picker directly to add the first photo. Non-empty -> tapping opens a paged
//  full-screen gallery (one photo per page) with uploader attribution and,
//  for the uploader's own photos, a delete option. Anyone in the trip can add
//  a photo; PhotosPicker needs no Info.plist entry or permission prompt.
//

import SwiftUI
import PhotosUI

struct ImageStripButton: View {
    let images: [TripImage]
    var size: CGFloat = 36
    let currentUserId: String?
    let onUpload: (Data) async -> Void
    let onDelete: (String) async -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var showGallery = false

    var body: some View {
        Group {
            if images.isEmpty {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.neutralPillBg, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .frame(width: size, height: size)
                        if isUploading {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.4))
                                .foregroundStyle(Theme.textSubtle)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            } else {
                Button { showGallery = true } label: {
                    ZStack(alignment: .topTrailing) {
                        thumbnail
                        if images.count > 1 {
                            Text("\(images.count)")
                                .font(.system(size: size * 0.28, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                                .offset(x: 5, y: -5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                isUploading = true
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await onUpload(data)
                }
                isUploading = false
                pickerItem = nil
            }
        }
        .sheet(isPresented: $showGallery) {
            ImageGalleryModal(images: images, currentUserId: currentUserId, onUpload: onUpload, onDelete: onDelete)
        }
    }

    private var thumbnail: some View {
        AsyncImage(url: URL(string: images[0].url)) { phase in
            if case .success(let img) = phase {
                img.resizable().scaledToFill()
            } else {
                Rectangle().fill(Theme.neutralPillBg)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Paged gallery modal

struct ImageGalleryModal: View {
    @Environment(\.dismiss) private var dismiss

    let images: [TripImage]
    let currentUserId: String?
    let onUpload: (Data) async -> Void
    let onDelete: (String) async -> Void

    @State private var page = 0
    @State private var pickerItem: PhotosPickerItem?
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            Group {
                if images.isEmpty {
                    Text("Belum ada foto")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $page) {
                        ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                            imagePage(image).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if isBusy {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isBusy)
                }
            }
        }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                isBusy = true
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await onUpload(data)
                }
                isBusy = false
                pickerItem = nil
            }
        }
        .onChange(of: images.count) { newCount in
            if newCount == 0 { dismiss() } else if page >= newCount { page = newCount - 1 }
        }
        .preferredColorScheme(.dark)
    }

    private func imagePage(_ image: TripImage) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: URL(string: image.url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "photo").font(.system(size: 40)).foregroundStyle(.white.opacity(0.4))
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diunggah oleh \(image.uploadedByName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(Formatters.dateTimeLabel(image.createdAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                if image.uploadedBy == currentUserId {
                    Button {
                        Task {
                            isBusy = true
                            await onDelete(image.id)
                            isBusy = false
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .disabled(isBusy)
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.75))
        }
    }
}
