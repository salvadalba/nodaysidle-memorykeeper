import SwiftUI
import SwiftData

struct DuplicateReviewView: View {
    @Query(filter: #Predicate<DuplicateGroup> { !$0.isResolved },
           sort: \DuplicateGroup.createdDate,
           order: .reverse)
    private var duplicateGroups: [DuplicateGroup]

    @State private var selectedGroup: DuplicateGroup?

    var body: some View {
        HSplitView {
            // Groups list
            duplicateGroupsList
                .frame(minWidth: 250, maxWidth: 350)

            // Comparison view
            if let group = selectedGroup {
                DuplicateComparisonView(group: group)
            } else {
                emptySelection
            }
        }
    }

    private var duplicateGroupsList: some View {
        List(selection: $selectedGroup) {
            if duplicateGroups.isEmpty {
                emptyState
            } else {
                ForEach(duplicateGroups, id: \.self) { group in
                    DuplicateGroupRow(group: group)
                        .tag(group)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Duplicates")
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            // Clean library celebration illustration
            CleanLibraryIllustration()
                .frame(width: 180, height: 140)

            VStack(spacing: 10) {
                Text("All Clear!")
                    .font(Typography.sectionSmall)
                    .foregroundStyle(.primary)

                Text("No duplicate photos found.\nYour library is beautifully organized.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .listRowBackground(Color.clear)
    }

    private var emptySelection: some View {
        ContentUnavailableView(
            "Select a Group",
            systemImage: "square.on.square",
            description: Text("Select a duplicate group to compare photos")
        )
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
                resolveGroup()
            }
        } message: {
            Text("The unselected photos will be moved to Trash. This can be undone.")
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
                // Mark as resolved without action
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

    private func resolveGroup() {
        // Mark group as resolved
        group.isResolved = true
        group.resolvedDate = Date()
        try? modelContext.save()
    }
}

struct DuplicatePhotoCard: View {
    let photo: Photo
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Photo
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .padding(8)
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

                // File info would go here
                Text("Photo details")
                    .font(Typography.metadataSmall)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .memoryShadow, radius: isSelected ? 8 : 2)
        .onTapGesture(perform: onTap)
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
