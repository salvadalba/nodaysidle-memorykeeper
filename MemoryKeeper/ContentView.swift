import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Photo.creationDate, order: .reverse) private var photos: [Photo]

    @Namespace private var photoNamespace

    @State private var sidebarSelection: SidebarSelection? = .allPhotos
    @State private var selectedPhoto: Photo?
    @State private var showPhotoDetail = false
    @State private var searchText = ""

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
    }

    @ViewBuilder
    private var contentView: some View {
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
                // TODO: Trigger library scan
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Scan library for new photos")
            .accessibilityLabel("Scan library")
            .accessibilityHint("Scan your photo library for new photos")
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
