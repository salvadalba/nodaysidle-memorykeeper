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
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
        }

        MenuBarExtra("MemoryKeeper", systemImage: "photo.on.rectangle") {
            MenuBarView()
        }
    }
}
