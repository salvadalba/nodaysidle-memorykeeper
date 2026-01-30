import SwiftUI
import SwiftData
import Photos

// MARK: - Memory Card Component

struct MemoryCard: View {
    let memory: Memory
    var onTap: (() -> Void)?

    @State private var isHovered = false
    @State private var cardPhase: MemoryCardPhase = .hidden
    @State private var heroThumbnail: NSImage?
    @State private var secondaryThumbnails: [NSImage] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero photo with rounded corners and warm vignette
            heroPhotoView

            // Caption in New York italic below photo
            if let caption = memory.caption {
                Text(caption.text)
                    .font(Typography.captionItalic)
                    .tracking(Typography.captionTracking)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .animateFontWeight()
            }

            // Date range displayed elegantly
            dateRangeView
        }
        .padding()
        .background(
            Color.memoryWarm.opacity(isHovered ? 1 : 0.7),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(
            color: .memoryShadow,
            radius: isHovered ? 16 : 8,
            y: isHovered ? 8 : 4
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: reduceMotion ? 0 : cardPhase.offset)
        .opacity(reduceMotion ? 1 : cardPhase.opacity)
        .blur(radius: reduceMotion ? 0 : cardPhase.blur)
        .animation(.cardHover, value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap?() }
        .onAppear {
            if !reduceMotion {
                withAnimation(.memorySpringGentle.delay(0.1)) {
                    cardPhase = .appearing
                }
                withAnimation(.memorySpringGentle.delay(0.3)) {
                    cardPhase = .visible
                }
            } else {
                cardPhase = .visible
            }
        }
        .task {
            await loadHeroThumbnails()
        }
        .memoryAccessibility(
            type: memoryTypeName,
            photoCount: memory.photos.count,
            dateRange: formatDateRange(start: memory.startDate, end: memory.endDate)
        )
    }

    private var heroPhotoView: some View {
        ZStack {
            // Background layer
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.memoryWarmDark)
                .aspectRatio(4/3, contentMode: .fit)

            // Hero image with warm vignette overlay
            if let heroImage = heroThumbnail {
                GeometryReader { geo in
                    ZStack {
                        // Main hero image
                        Image(nsImage: heroImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        // Warm nostalgic vignette overlay
                        WarmVignetteOverlay()

                        // Subtle sepia tint for vintage feel
                        Color.memorySepia.opacity(0.08)
                            .blendMode(.multiply)
                    }
                }
                .aspectRatio(4/3, contentMode: .fit)
            } else {
                // Elegant placeholder with stacked photo effect
                MemoryPlaceholderView(photoCount: memory.photos.count)
                    .aspectRatio(4/3, contentMode: .fit)
            }

            // Floating secondary thumbnails (peek effect)
            if !secondaryThumbnails.isEmpty && heroThumbnail != nil {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: -8) {
                            ForEach(Array(secondaryThumbnails.prefix(2).enumerated()), id: \.offset) { index, thumb in
                                Image(nsImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                    .rotationEffect(.degrees(Double(index - 1) * 5))
                            }
                        }
                        .padding(12)
                    }
                    Spacer()
                }
            }

            // Photo count badge with glass effect
            VStack {
                Spacer()
                HStack {
                    // Memory type indicator
                    HStack(spacing: 4) {
                        Image(systemName: memoryTypeIcon)
                            .font(.caption2)
                        Text(memoryTypeName)
                            .font(Typography.tagSmall)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)

                    Spacer()

                    // Photo count
                    Label("\(memory.photos.count)", systemImage: "photo.on.rectangle")
                        .font(Typography.tagSmall)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func loadHeroThumbnails() async {
        guard !memory.photos.isEmpty else { return }

        // Load hero (first photo)
        if let firstPhoto = memory.photos.first {
            heroThumbnail = await loadThumbnail(for: firstPhoto.assetIdentifier, size: CGSize(width: 400, height: 300))
        }

        // Load secondary thumbnails (next 2 photos)
        for photo in memory.photos.dropFirst().prefix(2) {
            if let thumb = await loadThumbnail(for: photo.assetIdentifier, size: CGSize(width: 64, height: 64)) {
                secondaryThumbnails.append(thumb)
            }
        }
    }

    private func loadThumbnail(for identifier: String, size: CGSize) async -> NSImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        var resultImage: NSImage?
        for await image in loadImageStream(asset: asset, targetSize: CGSize(width: size.width * 2, height: size.height * 2), options: options) {
            resultImage = image
        }
        return resultImage
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

                if !isDegraded || isCancelled || hasError {
                    if !hasFinished {
                        hasFinished = true
                        continuation.finish()
                    }
                }
            }
        }
    }

    private var dateRangeView: some View {
        Group {
            if let startDate = memory.startDate {
                HStack(spacing: 6) {
                    Image(systemName: memoryTypeIcon)
                        .foregroundStyle(Color.memoryAccent)

                    Text(formatDateRange(start: startDate, end: memory.endDate) ?? "")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var memoryTypeIcon: String {
        switch memory.type {
        case .onThisDay: return "calendar"
        case .forgotten: return "clock.arrow.circlepath"
        case .collection: return "rectangle.stack"
        }
    }

    private var memoryTypeName: String {
        switch memory.type {
        case .onThisDay: return "On This Day"
        case .forgotten: return "Forgotten"
        case .collection: return "Collection"
        }
    }

    private func formatDateRange(start: Date?, end: Date?) -> String? {
        guard let start else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if let end, !Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        return formatter.string(from: start)
    }
}

// MARK: - Warm Vignette Overlay

struct WarmVignetteOverlay: View {
    var body: some View {
        ZStack {
            // Radial vignette from edges
            RadialGradient(
                colors: [
                    .clear,
                    Color.memorySepia.opacity(0.15),
                    Color.memorySepia.opacity(0.35)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )

            // Bottom gradient for text readability
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Warm color wash
            LinearGradient(
                colors: [
                    Color.memoryGold.opacity(0.08),
                    Color.memoryAccent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
        }
    }
}

// MARK: - Memory Placeholder View (Stacked Photos Effect)

struct MemoryPlaceholderView: View {
    let photoCount: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Warm textured background
                Color.memoryWarmDark

                // Decorative stacked photos effect
                ForEach(0..<min(3, max(1, photoCount)), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.memoryWarm.opacity(0.8 - Double(index) * 0.2))
                        .frame(width: geo.size.width * 0.4, height: geo.size.height * 0.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .rotationEffect(.degrees(Double(index - 1) * 8))
                        .offset(x: CGFloat(index - 1) * 10, y: CGFloat(index - 1) * -5)
                }

                // Center icon
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.memoryGold, Color.memoryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Memory")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.memoryFaded)
                }
            }
        }
    }
}

// MARK: - Memories Feed View with TimelineView

struct MemoriesFeedView: View {
    @Query(sort: \Memory.createdDate, order: .reverse) private var memories: [Memory]
    @State private var selectedMemory: Memory?
    @State private var showSlideshow = false

    var body: some View {
        // TimelineView updates at midnight for new day per spec
        TimelineView(.everyMinute) { context in
            Group {
                if memories.isEmpty {
                    emptyState
                } else {
                    memoryFeed(currentDate: context.date)
                }
            }
        }
        .sheet(isPresented: $showSlideshow) {
            if let memory = selectedMemory {
                MemorySlideshowView(memory: memory, isPresented: $showSlideshow)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
    }

    private func memoryFeed(currentDate: Date) -> some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Today's memory (featured)
                if let todayMemory = memories.first(where: { Calendar.current.isDateInToday($0.createdDate) }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Memory")
                            .font(Typography.sectionSmall)
                            .foregroundStyle(.secondary)

                        MemoryCard(memory: todayMemory) {
                            selectedMemory = todayMemory
                            showSlideshow = true
                        }
                    }
                }

                // Past memories grid
                if memories.count > 1 {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Memories")
                            .font(Typography.sectionSmall)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 20) {
                            ForEach(memories.dropFirst(), id: \.createdDate) { memory in
                                MemoryCard(memory: memory) {
                                    selectedMemory = memory
                                    showSlideshow = true
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            // Vintage photo album illustration
            VintageAlbumIllustration()
                .frame(width: 280, height: 200)

            VStack(spacing: 12) {
                Text("No Memories Yet")
                    .font(Typography.heroSmall)
                    .foregroundStyle(.primary)

                Text("Your cherished moments will appear here once we've explored your photo library")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Button {
                // Trigger memory generation
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Discover Memories")
                }
                .font(Typography.bodyMedium)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.memoryWarmLight)
        .accessibilityLabel("No memories available yet")
        .accessibilityHint("Memories will be generated after your photo library is analyzed")
    }
}

// MARK: - Vintage Album Illustration (Empty State)

struct VintageAlbumIllustration: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background warm glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.memoryGold.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 200)
                .blur(radius: 20)

            // Stacked polaroid-style photos
            ForEach(0..<4, id: \.self) { index in
                PolaroidFrame(index: index)
                    .rotationEffect(.degrees(polaroidRotation(for: index)))
                    .offset(polaroidOffset(for: index))
                    .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1 : 0.9))
                    .opacity(reduceMotion ? 1 : (isAnimating ? 1 : 0))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }

            // Floating sparkle particles
            if !reduceMotion {
                ForEach(0..<5, id: \.self) { index in
                    SparkleParticle(index: index)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(index) * 0.3), value: isAnimating)
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .accessibilityHidden(true)
    }

    private func polaroidRotation(for index: Int) -> Double {
        let rotations = [-12.0, 5.0, -3.0, 8.0]
        return rotations[index % rotations.count]
    }

    private func polaroidOffset(for index: Int) -> CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -40, height: 20),
            CGSize(width: 30, height: -15),
            CGSize(width: -10, height: 0),
            CGSize(width: 50, height: 10)
        ]
        return offsets[index % offsets.count]
    }
}

struct PolaroidFrame: View {
    let index: Int

    private let colors: [Color] = [.memoryWarmDark, .memoryAccent.opacity(0.3), .memoryGold.opacity(0.4), .memoryFaded]

    var body: some View {
        VStack(spacing: 0) {
            // Photo area
            RoundedRectangle(cornerRadius: 2)
                .fill(colors[index % colors.count])
                .frame(width: 50, height: 40)
                .overlay(
                    Image(systemName: photoIcon(for: index))
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color.memorySepia.opacity(0.5))
                )

            // White border bottom (polaroid style)
            Rectangle()
                .fill(Color.white)
                .frame(width: 50, height: 14)
        }
        .frame(width: 56, height: 64)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.memoryFaded.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func photoIcon(for index: Int) -> String {
        let icons = ["sun.max", "leaf", "heart", "star"]
        return icons[index % icons.count]
    }
}

struct SparkleParticle: View {
    let index: Int

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: CGFloat.random(in: 8...14)))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.memoryGold, Color.memoryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .offset(sparkleOffset)
    }

    private var sparkleOffset: CGSize {
        let positions: [CGSize] = [
            CGSize(width: -80, height: -40),
            CGSize(width: 90, height: -30),
            CGSize(width: -60, height: 50),
            CGSize(width: 70, height: 60),
            CGSize(width: 0, height: -60)
        ]
        return positions[index % positions.count]
    }
}

// MARK: - Ken Burns Effect

struct KenBurnsModifier: ViewModifier {
    let isActive: Bool
    let duration: Double
    let photoIndex: Int

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .onAppear {
                startKenBurnsAnimation()
            }
            .onChange(of: photoIndex) { _, _ in
                resetAndStartAnimation()
            }
    }

    private func startKenBurnsAnimation() {
        guard isActive else { return }

        // Randomize the Ken Burns direction
        let directions: [(scale: CGFloat, offset: CGSize)] = [
            (1.15, CGSize(width: 20, height: 15)),   // Zoom in, pan right-down
            (1.12, CGSize(width: -25, height: 10)),  // Zoom in, pan left-down
            (1.18, CGSize(width: 15, height: -20)),  // Zoom in, pan right-up
            (1.14, CGSize(width: -15, height: -15)), // Zoom in, pan left-up
        ]

        let direction = directions[photoIndex % directions.count]

        // Start slightly zoomed
        scale = 1.0
        offset = .zero

        // Animate to end state
        withAnimation(.easeInOut(duration: duration)) {
            scale = direction.scale
            offset = direction.offset
        }
    }

    private func resetAndStartAnimation() {
        scale = 1.0
        offset = .zero
        startKenBurnsAnimation()
    }
}

extension View {
    func kenBurnsEffect(isActive: Bool, duration: Double = 6.0, photoIndex: Int = 0) -> some View {
        modifier(KenBurnsModifier(isActive: isActive, duration: duration, photoIndex: photoIndex))
    }
}

// MARK: - Memory Slideshow View with Ken Burns Effect

struct MemorySlideshowView: View {
    let memory: Memory
    @Binding var isPresented: Bool

    @State private var currentIndex = 0
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var currentThumbnail: NSImage?
    @State private var isLoadingImage = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect() // Longer for Ken Burns

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep black background
                Color.black.ignoresSafeArea()

                // Current photo with Ken Burns effect
                if let photo = memory.photos[safe: currentIndex] {
                    photoView(for: photo, in: geometry.size)
                        .id(currentIndex)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.easeIn(duration: 0.8)),
                                removal: .opacity.animation(.easeOut(duration: 0.5))
                            )
                        )
                }

                // Cinematic letterbox bars (subtle)
                VStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: geometry.size.height * 0.05)
                    Spacer()
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: geometry.size.height * 0.05)
                }
                .allowsHitTesting(false)

                // Caption overlay with material background
                if showControls, let caption = memory.caption {
                    VStack {
                        Spacer()
                        captionOverlay(caption.text)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Progress bar
                VStack {
                    Spacer()
                    progressBar
                        .opacity(showControls ? 1 : 0.3)
                }

                // Controls with ultra thin material
                if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
            }
        }
        .onReceive(timer) { _ in
            if isPlaying && !memory.photos.isEmpty {
                advanceSlide()
            }
        }
        .onTapGesture {
            withAnimation(.memoryEaseOut) {
                showControls.toggle()
            }
        }
        .onExitCommand {
            isPresented = false
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.space) {
            isPlaying.toggle()
            return .handled
        }
        .task {
            await loadCurrentImage()
        }
        .onChange(of: currentIndex) { _, _ in
            Task {
                await loadCurrentImage()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Memory slideshow, \(currentIndex + 1) of \(memory.photos.count) photos")
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)

                // Progress
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.memoryGold, Color.memoryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressFraction, height: 3)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 40)
        .padding(.bottom, 100)
    }

    private var progressFraction: CGFloat {
        guard memory.photos.count > 1 else { return 1 }
        return CGFloat(currentIndex + 1) / CGFloat(memory.photos.count)
    }

    private func photoView(for photo: Photo, in size: CGSize) -> some View {
        ZStack {
            if let thumbnail = currentThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .kenBurnsEffect(
                        isActive: !reduceMotion && isPlaying,
                        duration: 6.0,
                        photoIndex: currentIndex
                    )

                // Cinematic vignette overlay
                CinematicVignette()
            } else {
                // Loading state
                VStack(spacing: 16) {
                    if isLoadingImage {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.memoryFaded)
                    }

                    if let date = photo.creationDate {
                        Text(date, style: .date)
                            .font(Typography.captionMedium)
                            .tracking(Typography.captionTracking)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .accessibilityLabel("Photo \(currentIndex + 1)")
    }

    private func loadCurrentImage() async {
        guard let photo = memory.photos[safe: currentIndex] else { return }
        isLoadingImage = true

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            isLoadingImage = false
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        for await image in loadSlideshowImageStream(asset: asset, options: options) {
            currentThumbnail = image
        }

        isLoadingImage = false
    }

    private func loadSlideshowImageStream(asset: PHAsset, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
        AsyncStream { continuation in
            var hasFinished = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1920, height: 1080),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil

                if let image = image {
                    continuation.yield(image)
                }

                if !isDegraded || isCancelled || hasError {
                    if !hasFinished {
                        hasFinished = true
                        continuation.finish()
                    }
                }
            }
        }
    }

    private func captionOverlay(_ text: String) -> some View {
        Text(text)
            .font(Typography.captionLargeItalic)
            .tracking(Typography.captionTracking)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 120)
            .accessibilityLabel("Caption: \(text)")
    }

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close slideshow")

                Spacer()

                // Date display
                if let photo = memory.photos[safe: currentIndex], let date = photo.creationDate {
                    Text(date, style: .date)
                        .font(Typography.tagLarge)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Progress indicator
                Text("\(currentIndex + 1) / \(memory.photos.count)")
                    .font(Typography.tagLarge)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Bottom playback controls
            HStack(spacing: 48) {
                Button {
                    previousSlide()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Previous photo")
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.4 : 1)

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                }
                .accessibilityLabel(isPlaying ? "Pause slideshow" : "Play slideshow")

                Button {
                    nextSlide()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Next photo")
                .disabled(currentIndex == memory.photos.count - 1)
                .opacity(currentIndex == memory.photos.count - 1 ? 0.4 : 1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.3), radius: 20, y: 5)
            .padding(.bottom, 50)
        }
        .buttonStyle(.plain)
    }

    private func advanceSlide() {
        withAnimation(.easeInOut(duration: 0.8)) {
            currentIndex = (currentIndex + 1) % memory.photos.count
        }
    }

    private func previousSlide() {
        withAnimation(.memorySpring) {
            currentIndex = currentIndex > 0 ? currentIndex - 1 : memory.photos.count - 1
        }
    }

    private func nextSlide() {
        withAnimation(.memorySpring) {
            currentIndex = (currentIndex + 1) % memory.photos.count
        }
    }
}

// MARK: - Cinematic Vignette (for Slideshow)

struct CinematicVignette: View {
    var body: some View {
        ZStack {
            // Edge vignette
            RadialGradient(
                colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.7)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 600
            )

            // Subtle film grain texture (simulated)
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)

            // Warm color grade
            LinearGradient(
                colors: [
                    Color.memoryGold.opacity(0.05),
                    .clear,
                    Color.memoryAccent.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Caption Editor

struct CaptionEditorView: View {
    @Bindable var caption: Caption
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool

    let maxLength = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a caption...", text: $caption.text, axis: .vertical)
                .font(Typography.captionMedium)
                .tracking(Typography.captionTracking)
                .lineLimit(3...5)
                .focused($isFocused)
                .onChange(of: caption.text) { _, newValue in
                    if newValue.count > maxLength {
                        caption.text = String(newValue.prefix(maxLength))
                    }
                    caption.isAutoGenerated = false
                    caption.editedDate = Date()
                }
                .accessibilityLabel("Caption text field")
                .accessibilityHint("Edit the memory caption")

            HStack {
                Text("\(caption.text.count)/\(maxLength)")
                    .font(Typography.metadataSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(caption.text.count) of \(maxLength) characters used")

                Spacer()

                if !caption.isAutoGenerated {
                    Button("Regenerate") {
                        // Would trigger caption regeneration
                    }
                    .font(Typography.tagSmall)
                    .buttonStyle(.borderless)
                    .accessibilityHint("Generate a new automatic caption")
                }
            }
        }
        .padding()
        .background(Color.memoryWarmLight, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Safe Array Subscript (if not defined elsewhere)

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Memory Card") {
    MemoryCard(memory: Memory(type: .onThisDay))
        .frame(width: 320)
        .padding()
}

#Preview("Memories Feed") {
    MemoriesFeedView()
        .modelContainer(for: [Memory.self, Photo.self, Caption.self], inMemory: true)
}
