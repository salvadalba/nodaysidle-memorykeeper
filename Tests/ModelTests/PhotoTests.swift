import Testing
import SwiftData
@testable import MemoryKeeper

@Suite("Photo Model Tests")
struct PhotoTests {

    @Test("Photo can be created with asset identifier")
    func createPhoto() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
        let context = ModelContext(container)

        let photo = Photo(assetIdentifier: "test-asset-123")
        context.insert(photo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Photo>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.assetIdentifier == "test-asset-123")
    }

    @Test("Photo stores location coordinates")
    func photoLocation() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
        let context = ModelContext(container)

        let photo = Photo(assetIdentifier: "location-test")
        photo.latitude = 37.7749
        photo.longitude = -122.4194
        context.insert(photo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Photo>()).first!
        #expect(fetched.latitude == 37.7749)
        #expect(fetched.longitude == -122.4194)
    }
}
