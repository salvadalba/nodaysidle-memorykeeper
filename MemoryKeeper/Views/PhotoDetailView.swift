import SwiftUI
import SwiftData
import Photos

struct PhotoDetailView: View {
    let photo: Photo
    @Binding var isPresented: Bool
    var namespace: Namespace.ID

    @State private var showMetadata = true
    @State private var fullImage: NSImage?
    @State private var isLoading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with blur
                Color.black.opacity(0.95)
                    .ignoresSafeArea()

                // Main image with matched geometry
                imageView
                    .matchedGeometryEffect(id: photo.assetIdentifier, in: namespace)
                    .frame(maxWidth: geometry.size.width * 0.9, maxHeight: geometry.size.height * 0.85)

                // Controls overlay with material backgrounds
                VStack {
                    topBar
                    Spacer()
                    if showMetadata {
                        metadataBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onTapGesture {
            withAnimation(.memoryEaseOut) {
                showMetadata.toggle()
            }
        }
        .gesture(dismissGesture)
        .onExitCommand {
            isPresented = false
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .task {
            await loadFullImage()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo detail view")
        .accessibilityHint("Swipe down or press Escape to close")
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                if value.translation.height > 100 {
                    withAnimation(.memorySpring) {
                        isPresented = false
                    }
                }
            }
    }

    @ViewBuilder
    private var imageView: some View {
        Group {
            if let fullImage {
                Image(nsImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.memoryFaded)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation(.memorySpring) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close")
            .accessibilityHint("Close photo detail view")

            Spacer()

            HStack(spacing: 16) {
                if photo.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Favorite")
                }

                if photo.duplicateGroup != nil {
                    Image(systemName: "square.on.square")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Has duplicates")
                }
            }
        }
        .padding()
        .background {
            if showMetadata {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

    private var metadataBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date and time
            if let date = photo.creationDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.memoryAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(date, style: .date)
                            .font(Typography.bodyMedium)
                        Text(date, style: .time)
                            .font(Typography.metadataSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Taken on \(date.formatted(date: .long, time: .shortened))")
            }

            // Location
            if let lat = photo.latitude, let lon = photo.longitude {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.memoryAccent)

                    Text(String(format: "%.4f, %.4f", lat, lon))
                        .font(Typography.metadataSmall)
                }
                .accessibilityLabel("Location coordinates: \(String(format: "%.4f latitude, %.4f longitude", lat, lon))")
            }

            // Categories
            if !photo.categories.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Color.memoryAccent)

                    FlowLayout(spacing: 6) {
                        ForEach(photo.categories.prefix(5), id: \.name) { category in
                            Text(category.name)
                                .font(Typography.tagSmall)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.memoryAccent.opacity(0.2), in: Capsule())
                        }
                    }
                }
                .accessibilityLabel("Categories: \(photo.categories.map(\.name).joined(separator: ", "))")
            }
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }

    private func loadFullImage() async {
        isLoading = true

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [photo.assetIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            isLoading = false
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        // Request full size image
        let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        fullImage = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }

        isLoading = false
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets

        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for size in sizes {
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
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
