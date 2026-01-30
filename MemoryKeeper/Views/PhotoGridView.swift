import SwiftUI
import SwiftData
import Photos

struct PhotoGridView: View {
    let photos: [Photo]
    @Binding var selectedPhoto: Photo?
    var namespace: Namespace.ID

    @AppStorage("thumbnailSize") private var thumbnailSize = 1
    @AppStorage("gridSpacing") private var gridSpacing: Double = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var focusedIndex: Int = 0
    @State private var showDetail = false
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private var gridItemSize: CGFloat {
        switch thumbnailSize {
        case 0: return 100  // Small
        case 2: return 250  // Large
        default: return 150 // Medium
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: gridItemSize, maximum: gridItemSize + 50), spacing: gridSpacing)]
    }

    private var estimatedColumnsPerRow: Int {
        max(1, Int(800 / gridItemSize))
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                // Only show permission-related empty state if actually not authorized
                if authorizationStatus == .denied || authorizationStatus == .restricted {
                    permissionDeniedState
                } else if authorizationStatus == .notDetermined {
                    requestPermissionState
                } else {
                    // Authorized but no photos yet - show loading or truly empty library state
                    emptyLibraryState
                }
            } else {
                photoGrid
            }
        }
        .onAppear {
            authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
    }

    private var photoGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(Array(photos.enumerated()), id: \.element.assetIdentifier) { index, photo in
                        PhotoThumbnailCell(
                            photo: photo,
                            size: gridItemSize,
                            isSelected: selectedPhoto?.assetIdentifier == photo.assetIdentifier,
                            isFocused: focusedIndex == index,
                            namespace: namespace
                        )
                        .id(index)
                        .onTapGesture {
                            withAnimation(.memorySpring) {
                                selectedPhoto = photo
                                focusedIndex = index
                                showDetail = true
                            }
                        }
                        .onKeyPress(.return) {
                            selectedPhoto = photos[focusedIndex]
                            showDetail = true
                            return .handled
                        }
                    }
                }
                .padding()
            }
            .focusable()
            .gridKeyboardNavigation(
                currentIndex: $focusedIndex,
                itemCount: photos.count,
                columnsPerRow: estimatedColumnsPerRow
            )
            .onChange(of: focusedIndex) { _, newIndex in
                withAnimation(.memorySpringQuick) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let photo = selectedPhoto,
               let index = photos.firstIndex(where: { $0.assetIdentifier == photo.assetIdentifier }) {
                PhotoNavigationView(
                    photos: photos,
                    currentIndex: .init(
                        get: { index },
                        set: { newIndex in
                            if let newPhoto = photos[safe: newIndex] {
                                selectedPhoto = newPhoto
                                focusedIndex = newIndex
                            }
                        }
                    ),
                    isPresented: $showDetail,
                    namespace: namespace
                )
            }
        }
    }

    private var permissionDeniedState: some View {
        VStack(spacing: 40) {
            VintageCameraIllustration()
                .frame(width: 240, height: 200)

            VStack(spacing: 16) {
                Text("Photo Access Required")
                    .font(Typography.heroSmall)
                    .foregroundStyle(Color.memoryTextPrimary)

                Text("MemoryKeeper needs access to your photos. Please grant access in System Settings.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.memoryTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button {
                openPhotoPrivacySettings()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gear")
                    Text("Open System Settings")
                }
                .font(Typography.bodyMedium)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                Text("Your photos stay on your device. Always.")
                    .font(Typography.metadataSmall)
            }
            .foregroundStyle(Color.memoryFaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.memoryWarmLight)
        .accessibilityLabel("Photo access denied")
        .accessibilityHint("Open System Settings to grant photo library access")
    }

    private var requestPermissionState: some View {
        VStack(spacing: 40) {
            VintageCameraIllustration()
                .frame(width: 240, height: 200)

            VStack(spacing: 16) {
                Text("Your Photo Library Awaits")
                    .font(Typography.heroSmall)
                    .foregroundStyle(Color.memoryTextPrimary)

                Text("Grant access to your photos and let us help you rediscover your cherished memories")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.memoryTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button {
                requestPhotoAccess()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                    Text("Grant Photo Access")
                }
                .font(Typography.bodyMedium)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                Text("Your photos stay on your device. Always.")
                    .font(Typography.metadataSmall)
            }
            .foregroundStyle(Color.memoryFaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.memoryWarmLight)
        .accessibilityLabel("Photo library access not yet granted")
        .accessibilityHint("Tap Grant Photo Access to allow access to your photo library")
    }

    private var emptyLibraryState: some View {
        VStack(spacing: 40) {
            VintageCameraIllustration()
                .frame(width: 240, height: 200)

            VStack(spacing: 16) {
                Text("No Photos Yet")
                    .font(Typography.heroSmall)
                    .foregroundStyle(Color.memoryTextPrimary)

                Text("Your photo library appears to be empty. Add some photos to get started!")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.memoryTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.memoryWarmLight)
        .accessibilityLabel("Photo library is empty")
        .accessibilityHint("Add photos to your library to see them here")
    }

    private func openPhotoPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestPhotoAccess() {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                authorizationStatus = status
            }
        }
    }
}

// MARK: - Photo Thumbnail Cell

struct PhotoThumbnailCell: View {
    let photo: Photo
    let size: CGFloat
    let isSelected: Bool
    let isFocused: Bool
    var namespace: Namespace.ID

    @State private var thumbnail: NSImage?
    @State private var loadPhase: PhotoLoadPhase = .initial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Thumbnail image with phase animation
            thumbnailContent
                .opacity(loadPhase.opacity)
                .scaleEffect(reduceMotion ? 1 : loadPhase.scale)

            // Selection/Focus overlay
            overlayContent

            // Indicators
            indicatorContent
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: isSelected ? .memoryShadowDeep : .memoryShadow, radius: isSelected ? 8 : 2, y: isSelected ? 4 : 1)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .memorySpring, value: isSelected)
        .matchedGeometryEffect(id: photo.assetIdentifier, in: namespace)
        .task {
            await loadThumbnail()
        }
        .photoAccessibility(
            date: photo.creationDate,
            categories: photo.categories.map(\.name),
            isFavorite: photo.isFavorite,
            isDuplicate: photo.duplicateGroup != nil
        )
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
                .animateFontWeight() // Apply font weight animation to any text overlays
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
        }

        if isFocused && !isSelected {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
        }
    }

    @ViewBuilder
    private var indicatorContent: some View {
        VStack {
            HStack {
                // Duplicate indicator
                if photo.duplicateGroup != nil {
                    Image(systemName: "square.on.square")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }

                Spacer()

                // Favorite indicator
                if photo.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            Spacer()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.memoryWarm)
            .frame(width: size, height: size)
            .overlay {
                if loadPhase == .loading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Color.memoryFaded)
                }
            }
    }

    private func loadThumbnail() async {
        loadPhase = .loading

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [photo.assetIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            loadPhase = .loaded
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let targetSize = CGSize(width: size * 2, height: size * 2) // 2x for Retina

        // Use async stream to handle multiple callbacks from PHImageManager
        for await image in loadImageStream(asset: asset, targetSize: targetSize, options: options) {
            await MainActor.run {
                self.thumbnail = image
                withAnimation(reduceMotion ? nil : .memoryEaseOut) {
                    loadPhase = .loaded
                }
            }
        }
    }

    private func loadImageStream(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
        AsyncStream { continuation in
            var hasFinished = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
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

// MARK: - Photo Navigation View

struct PhotoNavigationView: View {
    let photos: [Photo]
    @Binding var currentIndex: Int
    @Binding var isPresented: Bool
    var namespace: Namespace.ID

    var body: some View {
        if let photo = photos[safe: currentIndex] {
            PhotoDetailView(photo: photo, isPresented: $isPresented, namespace: namespace)
                .overlay(alignment: .leading) {
                    if currentIndex > 0 {
                        navigationButton(direction: .previous)
                    }
                }
                .overlay(alignment: .trailing) {
                    if currentIndex < photos.count - 1 {
                        navigationButton(direction: .next)
                    }
                }
                .onKeyPress(.leftArrow) {
                    navigatePrevious()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    navigateNext()
                    return .handled
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Photo \(currentIndex + 1) of \(photos.count)")
        }
    }

    private enum Direction { case previous, next }

    private func navigationButton(direction: Direction) -> some View {
        Button {
            switch direction {
            case .previous: navigatePrevious()
            case .next: navigateNext()
            }
        } label: {
            Image(systemName: direction == .previous ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .padding()
        .accessibilityLabel(direction == .previous ? "Previous photo" : "Next photo")
    }

    private func navigatePrevious() {
        withAnimation(.memorySpring) {
            currentIndex = max(0, currentIndex - 1)
        }
    }

    private func navigateNext() {
        withAnimation(.memorySpring) {
            currentIndex = min(photos.count - 1, currentIndex + 1)
        }
    }
}

// MARK: - Vintage Camera Illustration (Empty State)

struct VintageCameraIllustration: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Warm ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.memoryGold.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 30)

            // Scattered polaroid photos behind camera
            ForEach(0..<3, id: \.self) { index in
                ScatteredPolaroid(index: index)
                    .opacity(reduceMotion ? 1 : (isAnimating ? 1 : 0))
                    .offset(y: reduceMotion ? 0 : (isAnimating ? 0 : 20))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.6).delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }

            // Vintage camera body
            VintageCameraBody()
                .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1 : 0.8))
                .opacity(reduceMotion ? 1 : (isAnimating ? 1 : 0))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
                    value: isAnimating
                )

            // Floating hearts/sparkles
            if !reduceMotion {
                ForEach(0..<4, id: \.self) { index in
                    FloatingHeart(index: index)
                        .opacity(isAnimating ? 0.8 : 0)
                        .animation(
                            .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.4),
                            value: isAnimating
                        )
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .accessibilityHidden(true)
    }
}

struct VintageCameraBody: View {
    var body: some View {
        ZStack {
            // Camera body
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.memorySepia.opacity(0.9), Color.memorySepia],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 100, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.memorySepia.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // Lens
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.memoryFaded, Color.memoryWarmDark, Color.black.opacity(0.8)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.memoryAccent, Color.memoryGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                )
                .overlay(
                    // Lens reflection
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 15, height: 15)
                        .offset(x: -8, y: -8)
                )

            // Viewfinder
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.memoryWarmDark)
                    .frame(width: 20, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.memoryFaded.opacity(0.5))
                            .frame(width: 14, height: 6)
                    )
                Spacer()
            }
            .frame(height: 70)
            .offset(y: -12)

            // Shutter button
            HStack {
                Spacer()
                Circle()
                    .fill(Color.memoryAccent)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.memoryGold, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
            .frame(width: 100)
            .offset(y: -25)
        }
    }
}

struct ScatteredPolaroid: View {
    let index: Int

    private var rotation: Double {
        let rotations = [-25.0, 15.0, -8.0]
        return rotations[index % rotations.count]
    }

    private var offset: CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -70, height: 30),
            CGSize(width: 65, height: 25),
            CGSize(width: -20, height: 50)
        ]
        return offsets[index % offsets.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [Color.memoryWarmDark, Color.memoryFaded.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 28)

            Rectangle()
                .fill(Color.white)
                .frame(width: 36, height: 10)
        }
        .frame(width: 42, height: 48)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
    }
}

struct FloatingHeart: View {
    let index: Int

    private var offset: CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -90, height: -50),
            CGSize(width: 85, height: -40),
            CGSize(width: -75, height: 60),
            CGSize(width: 95, height: 55)
        ]
        return offsets[index % offsets.count]
    }

    private var icon: String {
        let icons = ["heart.fill", "sparkle", "star.fill", "heart"]
        return icons[index % icons.count]
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: CGFloat.random(in: 10...16)))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.memoryAccent, Color.memoryGold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .offset(offset)
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    @Previewable @Namespace var namespace
    PhotoGridView(photos: [], selectedPhoto: .constant(nil), namespace: namespace)
}
