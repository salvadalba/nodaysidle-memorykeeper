import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case allPhotos
    case memories
    case duplicates
    case category(String)
}

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(filter: #Predicate<DuplicateGroup> { !$0.isResolved }) private var unresolvedDuplicates: [DuplicateGroup]
    @Query private var memories: [Memory]

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Photos", systemImage: "photo.on.rectangle")
                    .tag(SidebarSelection.allPhotos)

                Label {
                    HStack {
                        Text("Memories")
                        Spacer()
                        if !memories.isEmpty {
                            Text("\(memories.count)")
                                .font(Typography.tagSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
                .tag(SidebarSelection.memories)

                Label {
                    HStack {
                        Text("Duplicates")
                        Spacer()
                        if !unresolvedDuplicates.isEmpty {
                            Text("\(unresolvedDuplicates.count)")
                                .font(Typography.tagSmall)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                } icon: {
                    Image(systemName: "square.on.square")
                }
                .tag(SidebarSelection.duplicates)
            }

            Section("Categories") {
                ForEach(categories, id: \.name) { category in
                    Label {
                        HStack {
                            Text(category.name)
                            Spacer()
                            Text("\(category.photos.count)")
                                .font(Typography.tagSmall)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: iconName(for: category.name))
                    }
                    .tag(SidebarSelection.category(category.name))
                }

                if categories.isEmpty {
                    Text("No categories yet")
                        .foregroundStyle(Color.memoryTextSecondary)
                        .font(Typography.bodySmall)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MemoryKeeper")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Sidebar")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    // Trigger library scan
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh library")
            }
        }
    }

    private func iconName(for category: String) -> String {
        switch category {
        case "People": return "person.2"
        case "Pets": return "pawprint"
        case "Animals": return "hare"
        case "Nature": return "leaf"
        case "Food": return "fork.knife"
        case "Travel": return "airplane"
        case "Activities": return "figure.run"
        case "Events": return "party.popper"
        case "Home": return "house"
        case "Documents": return "doc.text"
        case "Screenshots": return "rectangle.on.rectangle"
        case "Art": return "paintpalette"
        case "Vehicles": return "car"
        default: return "photo"
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.allPhotos))
        .modelContainer(for: [Photo.self, Category.self, DuplicateGroup.self, Memory.self], inMemory: true)
}
