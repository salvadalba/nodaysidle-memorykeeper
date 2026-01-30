import SwiftUI
import SwiftData

@main
struct MemoryKeeperApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Photo.self,
            Category.self,
            DuplicateGroup.self,
            Memory.self,
            Caption.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            OnboardingContainerView()
                .preferredColorScheme(.light) // Force light mode for warm nostalgic theme
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra("MemoryKeeper", systemImage: "photo.on.rectangle") {
            MenuBarView()
                .modelContainer(sharedModelContainer)
        }
    }
}
