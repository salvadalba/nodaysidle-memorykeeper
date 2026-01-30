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

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .frame(minWidth: 200)
        } content: {
            contentView
                .frame(minWidth: 400)
                .searchable(text: $searchText, prompt: "Search photos")
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color.memoryWarmLight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MemoryKeeper main window")
        .task {
            await loadPhotosIfNeeded()
        }
    }

    private func loadPhotosIfNeeded() async {
        // Only load if we have no photos
        guard photos.isEmpty else { return }
        await refreshLibrary()
    }

    private func refreshLibrary() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            syncError = "Photo library access not granted. Please grant access in System Settings > Privacy & Security > Photos."
            return
        }

        isLoadingPhotos = true
        syncError = nil

        do {
            let photoService = PhotoLibraryService()
            let syncService = PhotoSyncService(modelContainer: modelContext.container)

            let assets = try await photoService.fetchAllAssets()
            loadingProgress = (0, assets.count)

            try syncService.syncAssets(assets) { current, total in
                loadingProgress = (current, total)
            }

            isLoadingPhotos = false
        } catch {
            syncError = error.localizedDescription
            isLoadingPhotos = false
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
        if searchText.isEmpty {
            return photos
        }
        return photos.filter { photo in
            photo.categories.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
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
                Button("By Date") { }
                Button("By Name") { }
                Button("By Category") { }
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
