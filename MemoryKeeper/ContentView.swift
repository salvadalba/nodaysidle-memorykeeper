import SwiftUI
import SwiftData
import Photos

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Photo.creationDate, order: .reverse) private var photos: [Photo]

    @Namespace private var photoNamespace

    @State private var sidebarSelection: SidebarSelection? = .allPhotos
    @State private var selectedPhoto: Photo?
    @State private var showPhotoDetail = false
    @State private var searchText = ""
    @State private var isLoadingPhotos = false
    @State private var loadingProgress: (current: Int, total: Int) = (0, 0)
    @State private var syncError: String?
    @State private var sortOrder: PhotoSortOrder = .dateDescending
    @State private var analysisStatus: String = ""
    @State private var isAnalyzing = false

    enum PhotoSortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case favoriteFirst = "Favorites First"
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .frame(minWidth: 200)
        } content: {
            contentView
                .frame(minWidth: 400)
                .searchable(text: $searchText, prompt: "Search photos")
                .overlay(alignment: .bottomTrailing) {
                    analysisOverlay
                }
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color.memoryWarmLight.ignoresSafeArea())
        .scrollContentBackground(.hidden) // Hide default scroll backgrounds
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MemoryKeeper main window")
        .task {
            await loadPhotosIfNeeded()
        }
    }

    private func loadPhotosIfNeeded() async {
        // Only load if we have no photos
        guard photos.isEmpty else { return }

        // Check authorization first
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            // Request authorization
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus == .authorized || newStatus == .limited {
                await refreshLibrary()
            }
        } else if status == .authorized || status == .limited {
            await refreshLibrary()
        }
        // If denied/restricted, PhotoGridView will show the empty state with grant access button
    }

    private func refreshLibrary() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                syncError = "Photo library access not granted."
            }
            return
        }

        await MainActor.run {
            isLoadingPhotos = true
            syncError = nil
        }

        do {
            let photoService = PhotoLibraryService()
            let syncService = PhotoSyncService(modelContainer: modelContext.container)

            let assets = try await photoService.fetchAllAssets()

            await MainActor.run {
                loadingProgress = (0, assets.count)
            }

            try syncService.syncAssets(assets) { current, total in
                Task { @MainActor in
                    self.loadingProgress = (current, total)
                }
            }

            await MainActor.run {
                isLoadingPhotos = false
            }

            // Run analysis in background after sync completes
            Task {
                await runPhotoAnalysis(assets: assets)
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
                isLoadingPhotos = false
            }
        }
    }

    private func runPhotoAnalysis(assets: [PHAsset]) async {
        await MainActor.run {
            isAnalyzing = true
            analysisStatus = "Analyzing photos..."
        }

        let visionService = VisionAnalysisService()
        let categorizationService = CategorizationService(
            visionService: visionService,
            modelContainer: modelContext.container
        )
        let duplicateService = DuplicateDetectionService(
            visionService: visionService,
            modelContainer: modelContext.container
        )

        // Categorize photos (limit to avoid long processing)
        let assetsToAnalyze = Array(assets.prefix(100))

        do {
            await MainActor.run {
                analysisStatus = "Categorizing photos..."
            }

            let categories = try await categorizationService.categorizeAssets(assetsToAnalyze) { current, total in
                Task { @MainActor in
                    self.analysisStatus = "Categorizing: \(current)/\(total)"
                }
            }
            try categorizationService.persistAllCategories(categories)

            await MainActor.run {
                analysisStatus = "Detecting duplicates..."
            }

            // Detect duplicates
            let duplicateGroups = try await duplicateService.scanForDuplicates(assets: assetsToAnalyze) { current, total, status in
                Task { @MainActor in
                    self.analysisStatus = "\(status) \(current)/\(total)"
                }
            }
            try duplicateService.persistDuplicateGroups(duplicateGroups)

            await MainActor.run {
                isAnalyzing = false
                analysisStatus = ""
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                analysisStatus = "Analysis failed: \(error.localizedDescription)"
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoadingPhotos {
            loadingView
        } else if let error = syncError {
            errorView(error)
        } else {
            switch sidebarSelection {
            case .allPhotos, .none:
                PhotoGridView(
                    photos: filteredPhotos,
                    selectedPhoto: $selectedPhoto,
                    namespace: photoNamespace
                )
                .navigationTitle("All Photos")
                .toolbar {
                    photoToolbar
                }

            case .memories:
                MemoriesFeedView()
                    .navigationTitle("Memories")

            case .duplicates:
                DuplicateReviewView()
                    .navigationTitle("Duplicates")

            case .category(let name):
                let categoryPhotos = photos.filter { $0.categories.contains { $0.name == name } }
                PhotoGridView(
                    photos: categoryPhotos,
                    selectedPhoto: $selectedPhoto,
                    namespace: photoNamespace
                )
                .navigationTitle(name)
                .toolbar {
                    photoToolbar
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your photos...")
                .font(Typography.sectionSmall)
                .foregroundStyle(Color.memoryTextPrimary)
            if loadingProgress.total > 0 {
                Text("\(loadingProgress.current) of \(loadingProgress.total)")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.memoryTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analysisOverlay: some View {
        Group {
            if isAnalyzing && !analysisStatus.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(analysisStatus)
                        .font(Typography.metadataSmall)
                        .foregroundStyle(Color.memoryTextSecondary)
                }
                .padding(12)
                .background(Color.memoryCardBackground, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .memoryShadow, radius: 4)
                .padding()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.memoryAccent)
            Text("Unable to Load Photos")
                .font(Typography.sectionSmall)
                .foregroundStyle(Color.memoryTextPrimary)
            Text(message)
                .font(Typography.bodySmall)
                .foregroundStyle(Color.memoryTextSecondary)
            Button("Try Again") {
                syncError = nil
                Task {
                    await loadPhotosIfNeeded()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailView: some View {
        if let photo = selectedPhoto {
            PhotoDetailView(
                photo: photo,
                isPresented: .constant(true),
                namespace: photoNamespace
            )
        } else {
            ContentUnavailableView(
                "Select a Photo",
                systemImage: "photo",
                description: Text("Choose a photo from the grid to see details")
            )
            .accessibilityLabel("No photo selected")
            .accessibilityHint("Select a photo from the grid to view its details")
        }
    }

    private var filteredPhotos: [Photo] {
        var result = photos

        // Apply search filter
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { photo in
                // Search by category name
                if photo.categories.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }
                // Search by date (month, year, day names)
                if let date = photo.creationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .long
                    let dateString = formatter.string(from: date).lowercased()
                    if dateString.contains(lowercasedSearch) {
                        return true
                    }
                    // Also check year specifically
                    formatter.dateFormat = "yyyy"
                    if formatter.string(from: date).contains(searchText) {
                        return true
                    }
                    // Check month name
                    formatter.dateFormat = "MMMM"
                    if formatter.string(from: date).lowercased().contains(lowercasedSearch) {
                        return true
                    }
                }
                // Search by favorite status
                if lowercasedSearch == "favorite" || lowercasedSearch == "favorites" {
                    return photo.isFavorite
                }
                // Search by duplicate status
                if lowercasedSearch == "duplicate" || lowercasedSearch == "duplicates" {
                    return photo.duplicateGroup != nil
                }
                return false
            }
        }

        // Apply sort order
        switch sortOrder {
        case .dateDescending:
            result.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .dateAscending:
            result.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .favoriteFirst:
            result.sort { ($0.isFavorite ? 0 : 1) < ($1.isFavorite ? 0 : 1) }
        }

        return result
    }

    @ToolbarContentBuilder
    private var photoToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task {
                    await refreshLibrary()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Scan library for new photos")
            .accessibilityLabel("Scan library")
            .accessibilityHint("Scan your photo library for new photos")
            .disabled(isLoadingPhotos)
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                ForEach(PhotoSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .help("Sort photos")
            .accessibilityLabel("Sort options")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self], inMemory: true)
}
