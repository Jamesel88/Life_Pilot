import SwiftUI
import PhotosUI

/// A "Photos" form section: a horizontal strip of thumbnails (tap to view
/// full-size, × to remove) plus an "Add photos" picker button. Pure UI
/// over a staged `[Data]` array — the caller decides when/how those bytes
/// become persisted model objects (immediately, or on save).
struct PhotoAttachmentsSection: View {
    @Binding var photosData: [Data]
    @Binding var pickerItems: [PhotosPickerItem]
    @Binding var viewerPhoto: PhotoViewerItem?

    var body: some View {
        Section("Photos") {
            if !photosData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photosData.enumerated()), id: \.offset) { index, data in
                            thumbnail(data, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            PhotosPicker(selection: $pickerItems,
                         maxSelectionCount: 10,
                         matching: .images) {
                Label("Add photos", systemImage: "photo.badge.plus")
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ data: Data, index: Int) -> some View {
        // Decode at thumbnail size (2x for retina) — full-resolution photos
        // would otherwise each hold megabytes of decoded bitmap for a 72pt cell.
        if let image = UIImage(data: data)?
            .preparingThumbnail(of: CGSize(width: 144, height: 144)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture { viewerPhoto = PhotoViewerItem(data: data) }
                .overlay(alignment: .topTrailing) {
                    Button {
                        photosData.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                }
        }
    }
}
