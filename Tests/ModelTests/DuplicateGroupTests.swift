import Testing
import SwiftData
import Foundation
@testable import MemoryKeeper

@Suite("DuplicateGroup Model Tests")
struct DuplicateGroupTests {

    @Test("DuplicateGroup links multiple photos")
    func duplicateGroupPhotos() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
        let context = ModelContext(container)

        let group = DuplicateGroup()
        let photo1 = Photo(assetIdentifier: "dup-1")
        let photo2 = Photo(assetIdentifier: "dup-2")
        let photo3 = Photo(assetIdentifier: "dup-3")

        group.photos = [photo1, photo2, photo3]
        context.insert(group)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DuplicateGroup>())
        #expect(fetched.first?.photos.count == 3)
    }

    @Test("DuplicateGroup tracks resolution state")
    func duplicateGroupResolution() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
        let context = ModelContext(container)

        let group = DuplicateGroup()
        #expect(group.isResolved == false)
        #expect(group.resolvedDate == nil)

        group.isResolved = true
        group.resolvedDate = Date()

        context.insert(group)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DuplicateGroup>())
        #expect(fetched.first?.isResolved == true)
        #expect(fetched.first?.resolvedDate != nil)
    }

    @Test("DuplicateGroup calculates average similarity")
    func averageSimilarity() {
        let group = DuplicateGroup()
        group.similarityScores = [
            "pair-1-2": 0.8,
            "pair-1-3": 0.7,
            "pair-2-3": 0.9
        ]

        let expected = (0.8 + 0.7 + 0.9) / 3.0
        #expect(abs(group.averageSimilarity - expected) < 0.001)
    }

    @Test("DuplicateGroup returns representative photo")
    func representativePhoto() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
        let context = ModelContext(container)

        let group = DuplicateGroup()
        let photo1 = Photo(assetIdentifier: "first")
        let photo2 = Photo(assetIdentifier: "second")

        group.photos = [photo1, photo2]
        context.insert(group)

        #expect(group.representativePhoto?.assetIdentifier == "first")
    }
}
