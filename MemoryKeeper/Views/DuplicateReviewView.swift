import SwiftUI
import SwiftData
import Photos

struct DuplicateReviewView: View {
    @Query(filter: #Predicate<DuplicateGroup> { !$0.isResolved },
           sort: \DuplicateGroup.createdDate,
           order: .reverse)
    private var duplicateGroups: [DuplicateGroup]

    @State private var selectedGroup: DuplicateGroup?

    var body: some View {
        Group {
            if duplicateGroups.isEmpty {
                // Full-screen empty state when no duplicates
                emptyState
            } else {
                // Split view only when there are duplicates to review
                HSplitView {
                    duplicateGroupsList
                        .frame(minWidth: 250, maxWidth: 350)

                    if let group = selectedGroup {
                        DuplicateComparisonView(group: group)
                    } else {
                        emptySelection
                    }
                }
            }
        }
        .background(Color.memoryWarmLight)
    }

    private var duplicateGroupsList: some View {
        List(selection: $selectedGroup) {
            ForEach(duplicateGroups, id: \.self) { group in
                DuplicateGroupRow(group: group)
                    .tag(group)
            }
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            CleanLibraryIllustration()
                .frame(width: 200, height: 160)

            VStack(spacing: 12) {
                Text("All Clear!")
                    .font(Typography.heroSmall)
                    .foregroundStyle(Color.memoryTextPrimary)

                Text("No duplicate photos found.\nYour library is beautifully organized.")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.memoryTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptySelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.on.square")
                .font(.system(size: 48))
                .foregroundStyle(Color.memoryFaded)
            Text("Select a Group")
                .font(Typography.sectionSmall)
                .foregroundStyle(Color.memoryTextPrimary)
            Text("Select a duplicate group to compare photos")
                .font(Typography.bodySmall)
                .foregroundStyle(Color.memoryTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DuplicateGroupRow: View {
    let group: DuplicateGroup

    var body: some View {
        HStack(spacing: 12) {
            // Representative thumbnail
            ZStack {
                ForEach(Array(group.photos.prefix(3).enumerated().reversed()), id: \.offset) { index, _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(width: 50, height: 50)
                        .offset(x: CGFloat(index * 4), y: CGFloat(index * -4))
                }
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.photos.count) similar photos")
                    .font(Typography.bodyMedium)

                HStack {
                    Text("\(Int(group.averageSimilarity * 100))% similar")
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)

                    if let date = group.photos.first?.creationDate {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(date, style: .date)
                            .font(Typography.metadataSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("\(group.photos.count)")
                .font(Typography.tagLarge)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}

struct DuplicateComparisonView: View {
    let group: DuplicateGroup
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhotos: Set<String> = []
    @State private var showConfirmation = false
    @State private var deleteError: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Photo comparison grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    ForEach(group.photos, id: \.assetIdentifier) { photo in
                        DuplicatePhotoCard(
                            photo: photo,
                            isSelected: selectedPhotos.contains(photo.assetIdentifier),
                            isRecommended: photo == group.representativePhoto
                        ) {
                            toggleSelection(photo)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            actionBar
        }
        .alert("Remove Duplicates?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    await deleteUnselectedPhotos()
                }
            }
        } message: {
            let count = group.photos.count - selectedPhotos.count
            Text("\(count) photo(s) will be moved to Trash. This can be undone in Photos app.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "An error occurred")
        }
    }

    private var header: some View {
        HStack {
            Text("Compare \(group.photos.count) Photos")
                .font(Typography.sectionSmall)

            Spacer()

            Button("Select Best") {
                if let best = group.representativePhoto {
                    selectedPhotos = [best.assetIdentifier]
                }
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    private var actionBar: some View {
        HStack {
            Text("\(selectedPhotos.count) selected to keep")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Skip") {
                skipGroup()
            }
            .buttonStyle(.borderless)

            Button("Keep Selected") {
                if !selectedPhotos.isEmpty {
                    showConfirmation = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPhotos.isEmpty)
        }
        .padding()
    }

    private func toggleSelection(_ photo: Photo) {
        if selectedPhotos.contains(photo.assetIdentifier) {
            selectedPhotos.remove(photo.assetIdentifier)
        } else {
            selectedPhotos.insert(photo.assetIdentifier)
        }
    }

    private func skipGroup() {
        group.isResolved = true
        group.resolvedDate = Date()
        try? modelContext.save()
    }

    private func deleteUnselectedPhotos() async {
        // Get asset identifiers to delete BEFORE modifying anything
        let toDelete = group.photos
            .filter { !selectedPhotos.contains($0.assetIdentifier) }
            .map { $0.assetIdentifier }

        // Mark group as resolved FIRST so it disappears from list immediately
        // This prevents SwiftUI from trying to render while data is changing
        await MainActor.run {
            group.isResolved = true
            group.resolvedDate = Date()
            try? modelContext.save()
        }

        guard !toDelete.isEmpty else {
            return
        }

        // Fetch the PHAssets
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: toDelete, options: nil)
        var assetsToDelete: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assetsToDelete.append(asset)
        }

        guard !assetsToDelete.isEmpty else {
            return
        }

        // Delete from Photos library in background
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            }
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
                showError = true
            }
        }
    }
}

struct DuplicatePhotoCard: View {
    let photo: Photo
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 8) {
            // Photo
            ZStack(alignment: .topTrailing) {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(width: 180, height: 180)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .padding(8)
                    .background(Color.black.opacity(0.3), in: Circle())
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green, lineWidth: 3)
                }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                if isRecommended {
                    Text("Recommended")
                        .font(Typography.tagSmall)
                        .foregroundStyle(.green)
                }

                if let date = photo.creationDate {
                    Text(date, style: .date)
                        .font(Typography.metadataSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .memoryShadow, radius: isSelected ? 8 : 2)
        .onTapGesture(perform: onTap)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [photo.assetIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else {
            await MainActor.run { isLoading = false }
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 360, height: 360)

        for await image in loadImageStream(asset: asset, targetSize: targetSize, options: options) {
            await MainActor.run {
                self.thumbnail = image
                self.isLoading = false
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

// MARK: - Clean Library Illustration

struct CleanLibraryIllustration: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)

            // Organized photo stack
            VStack(spacing: -20) {
                ForEach(0..<3, id: \.self) { index in
                    OrganizedPhotoFrame(index: index)
                        .offset(y: CGFloat(index) * -10)
                        .zIndex(Double(3 - index))
                        .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1 : 0.8))
                        .opacity(reduceMotion ? 1 : (isAnimating ? 1 : 0))
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }

            // Checkmark badge
            Circle()
                .fill(Color.green)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .green.opacity(0.3), radius: 8, y: 2)
                .offset(x: 50, y: -40)
                .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1 : 0))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6).delay(0.4),
                    value: isAnimating
                )

            // Sparkles
            if !reduceMotion {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.memoryGold)
                        .offset(sparkleOffset(for: index))
                        .opacity(isAnimating ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
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

    private func sparkleOffset(for index: Int) -> CGSize {
        let offsets: [CGSize] = [
            CGSize(width: -55, height: -30),
            CGSize(width: 60, height: 20),
            CGSize(width: -40, height: 40)
        ]
        return offsets[index % offsets.count]
    }
}

struct OrganizedPhotoFrame: View {
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.memoryWarm)
            .frame(width: 80, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white, lineWidth: 2)
            )
            .overlay(
                Image(systemName: photoIcon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.memoryAccent.opacity(0.6))
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var photoIcon: String {
        let icons = ["sun.max", "leaf", "heart"]
        return icons[index % icons.count]
    }
}

#Preview {
    DuplicateReviewView()
        .modelContainer(for: [Photo.self, DuplicateGroup.self], inMemory: true)
}
