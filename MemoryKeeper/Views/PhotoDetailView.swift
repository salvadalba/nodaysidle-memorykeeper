import SwiftUI
import SwiftData
import Photos

struct PhotoDetailView: View {
    let photo: Photo
    @Binding var isPresented: Bool
    var namespace: Namespace.ID

    @State private var fullImage: NSImage?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            // Solid background
            Color.memoryWarm
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close button
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.memoryTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])

                    Spacer()

                    if photo.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding()

                // Main image area
                Spacer()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading photo...")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.memoryTextSecondary)
                    }
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.memoryAccent)
                        Text(error)
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.memoryTextSecondary)
                    }
                } else if let image = fullImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .memoryShadowDeep, radius: 12, y: 6)
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.memoryFaded)
                        Text("Unable to load photo")
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.memoryTextSecondary)
                    }
                }

                Spacer()

                // Bottom metadata
                if let date = photo.creationDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.memoryAccent)
                        Text(date, style: .date)
                            .font(Typography.bodySmall)
                        Text("•")
                            .foregroundStyle(Color.memoryFaded)
                        Text(date, style: .time)
                            .font(Typography.metadataSmall)
                    }
                    .foregroundStyle(Color.memoryTextSecondary)
                    .padding()
                    .background(Color.memoryCardBackground, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        loadError = nil

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [photo.assetIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            await MainActor.run {
                loadError = "Photo not found in library"
                isLoading = false
            }
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        // Request a reasonable size
        let targetSize = CGSize(width: 2000, height: 2000)

        // Use AsyncStream to handle multiple callbacks from PHImageManager
        for await image in loadImageStream(asset: asset, targetSize: targetSize, options: options) {
            await MainActor.run {
                fullImage = image
                isLoading = false
            }
        }

        // If stream completed without setting an image, show error
        await MainActor.run {
            if fullImage == nil {
                loadError = "Failed to load image"
            }
            isLoading = false
        }
    }

    private func loadImageStream(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
        AsyncStream { continuation in
            var hasFinished = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil

                if let image = image {
                    continuation.yield(image)
                }

                // Finish the stream when we get the final image or an error
                if !isDegraded || isCancelled || hasError {
                    if !hasFinished {
                        hasFinished = true
                        continuation.finish()
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    PhotoDetailView(
        photo: Photo(assetIdentifier: "preview"),
        isPresented: .constant(true),
        namespace: namespace
    )
}
