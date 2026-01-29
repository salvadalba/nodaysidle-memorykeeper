import Testing
import SwiftData
import Foundation
@testable import MemoryKeeper

@Suite("Memory Surfacing Tests")
struct MemorySurfacingTests {

    // MARK: - Test Helpers

    private func createContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )
    }

    private func createPhotoWithDate(
        _ assetId: String,
        year: Int,
        month: Int,
        day: Int,
        context: ModelContext
    ) -> Photo {
        let photo = Photo(assetIdentifier: assetId)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        photo.creationDate = Calendar.current.date(from: components)
        context.insert(photo)
        return photo
    }

    // MARK: - On This Day Tests

    @Test("On This Day finds photos from same month and day in previous years")
    @MainActor
    func onThisDayFindsCorrectDates() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // Create a photo from same month/day last year
        _ = createPhotoWithDate(
            "match-1",
            year: currentYear - 1,
            month: currentMonth,
            day: currentDay,
            context: context
        )

        // Create a photo from same month/day two years ago
        _ = createPhotoWithDate(
            "match-2",
            year: currentYear - 2,
            month: currentMonth,
            day: currentDay,
            context: context
        )

        // Create a photo from different day (should not match)
        let differentDay = (currentDay % 28) + 1
        _ = createPhotoWithDate(
            "no-match",
            year: currentYear - 1,
            month: currentMonth,
            day: differentDay,
            context: context
        )

        try context.save()

        let results = try service.getOnThisDayPhotos()

        #expect(results.count == 2)
        #expect(results.contains { $0.assetIdentifier == "match-1" })
        #expect(results.contains { $0.assetIdentifier == "match-2" })
        #expect(!results.contains { $0.assetIdentifier == "no-match" })
    }

    @Test("On This Day excludes photos from current year")
    @MainActor
    func onThisDayExcludesCurrentYear() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // Create a photo from today (should not match)
        _ = createPhotoWithDate(
            "current-year",
            year: currentYear,
            month: currentMonth,
            day: currentDay,
            context: context
        )

        // Create a photo from last year (should match)
        _ = createPhotoWithDate(
            "last-year",
            year: currentYear - 1,
            month: currentMonth,
            day: currentDay,
            context: context
        )

        try context.save()

        let results = try service.getOnThisDayPhotos()

        #expect(results.count == 1)
        #expect(results.first?.assetIdentifier == "last-year")
    }

    @Test("On This Day weights older photos higher")
    @MainActor
    func onThisDayWeightsOlderPhotos() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // Create photos from multiple years
        _ = createPhotoWithDate("year-1", year: currentYear - 1, month: currentMonth, day: currentDay, context: context)
        _ = createPhotoWithDate("year-3", year: currentYear - 3, month: currentMonth, day: currentDay, context: context)
        _ = createPhotoWithDate("year-5", year: currentYear - 5, month: currentMonth, day: currentDay, context: context)

        try context.save()

        let results = try service.getOnThisDayPhotos()

        #expect(results.count == 3)
        // Older photos should come first
        #expect(results.first?.assetIdentifier == "year-5")
    }

    @Test("On This Day excludes recently viewed photos")
    @MainActor
    func onThisDayExcludesRecentlyViewed() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // Create a photo viewed yesterday
        let recentlyViewed = createPhotoWithDate(
            "recently-viewed",
            year: currentYear - 1,
            month: currentMonth,
            day: currentDay,
            context: context
        )
        recentlyViewed.lastViewedDate = calendar.date(byAdding: .day, value: -1, to: today)

        // Create a photo not recently viewed
        let notRecentlyViewed = createPhotoWithDate(
            "not-recently-viewed",
            year: currentYear - 1,
            month: currentMonth,
            day: currentDay,
            context: context
        )
        notRecentlyViewed.lastViewedDate = calendar.date(byAdding: .day, value: -30, to: today)

        try context.save()

        let results = try service.getOnThisDayPhotos()

        #expect(results.count == 1)
        #expect(results.first?.assetIdentifier == "not-recently-viewed")
    }

    // MARK: - Forgotten Photos Tests

    @Test("Forgotten photos respects time threshold")
    @MainActor
    func forgottenPhotosRespectsThreshold() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)
        service.forgottenMonths = 12

        let calendar = Calendar.current
        let today = Date()

        // Create a photo not viewed for 18 months
        let forgotten = Photo(assetIdentifier: "forgotten")
        forgotten.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        forgotten.lastViewedDate = calendar.date(byAdding: .month, value: -18, to: today)
        context.insert(forgotten)

        // Create a photo viewed 6 months ago (should not be forgotten)
        let recent = Photo(assetIdentifier: "recent")
        recent.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        recent.lastViewedDate = calendar.date(byAdding: .month, value: -6, to: today)
        context.insert(recent)

        try context.save()

        let results = try service.getForgottenPhotos()

        #expect(results.contains { $0.assetIdentifier == "forgotten" })
        #expect(!results.contains { $0.assetIdentifier == "recent" })
    }

    @Test("Forgotten photos excludes favorites when configured")
    @MainActor
    func forgottenPhotosExcludesFavorites() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)
        service.forgottenMonths = 12
        service.excludeFavorites = true

        let calendar = Calendar.current
        let today = Date()

        // Create a forgotten favorite
        let favorite = Photo(assetIdentifier: "favorite")
        favorite.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        favorite.lastViewedDate = nil
        favorite.isFavorite = true
        context.insert(favorite)

        // Create a forgotten non-favorite
        let nonFavorite = Photo(assetIdentifier: "non-favorite")
        nonFavorite.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        nonFavorite.lastViewedDate = nil
        nonFavorite.isFavorite = false
        context.insert(nonFavorite)

        try context.save()

        let results = try service.getForgottenPhotos()

        #expect(!results.contains { $0.assetIdentifier == "favorite" })
        #expect(results.contains { $0.assetIdentifier == "non-favorite" })
    }

    @Test("Forgotten photos includes favorites when not configured to exclude")
    @MainActor
    func forgottenPhotosIncludesFavorites() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)
        service.forgottenMonths = 12
        service.excludeFavorites = false

        let calendar = Calendar.current
        let today = Date()

        // Create a forgotten favorite
        let favorite = Photo(assetIdentifier: "favorite")
        favorite.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        favorite.lastViewedDate = nil
        favorite.isFavorite = true
        context.insert(favorite)

        try context.save()

        let results = try service.getForgottenPhotos()

        #expect(results.contains { $0.assetIdentifier == "favorite" })
    }

    // MARK: - Memory Creation Tests

    @Test("Memory creation links photos correctly")
    @MainActor
    func memoryCreationLinksPhotos() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // Create photos that will match On This Day
        _ = createPhotoWithDate("photo-1", year: currentYear - 1, month: currentMonth, day: currentDay, context: context)
        _ = createPhotoWithDate("photo-2", year: currentYear - 2, month: currentMonth, day: currentDay, context: context)

        try context.save()

        let memory = try service.createOnThisDayMemory()

        #expect(memory != nil)
        #expect(memory?.type == .onThisDay)
        #expect(memory?.photos.count == 2)
        #expect(memory?.startDate != nil)
        #expect(memory?.endDate != nil)
    }

    @Test("Memory creation increments counter")
    @MainActor
    func memoryCreationIncrementsCounter() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        _ = createPhotoWithDate("photo-1", year: currentYear - 1, month: currentMonth, day: currentDay, context: context)

        try context.save()

        let initialCount = service.memoriesSurfacedTotal
        _ = try service.createOnThisDayMemory()
        let finalCount = service.memoriesSurfacedTotal

        #expect(finalCount == initialCount + 1)
    }

    @Test("Memory creation returns nil when no eligible photos")
    @MainActor
    func memoryCreationReturnsNilWhenEmpty() async throws {
        let container = try createContainer()
        let service = MemorySurfacingService(modelContainer: container)

        // Don't insert any photos

        let memory = try service.createOnThisDayMemory()

        #expect(memory == nil)
    }

    // MARK: - Daily Memory Tests

    @Test("Daily memory alternates between types")
    @MainActor
    func dailyMemoryAlternates() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        // Create enough photos for both memory types
        let calendar = Calendar.current
        let today = Date()
        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)
        let currentYear = calendar.component(.year, from: today)

        // On This Day photos
        _ = createPhotoWithDate("otd-1", year: currentYear - 1, month: currentMonth, day: currentDay, context: context)

        // Forgotten photos
        let forgotten = Photo(assetIdentifier: "forgotten-1")
        forgotten.creationDate = calendar.date(byAdding: .year, value: -2, to: today)
        forgotten.lastViewedDate = nil
        context.insert(forgotten)

        try context.save()

        let memory = try service.generateDailyMemory()

        #expect(memory != nil)
        #expect(memory?.type == .onThisDay || memory?.type == .forgotten)
    }

    // MARK: - Memory Retrieval Tests

    @Test("Mark memory as presented updates fields")
    @MainActor
    func markMemoryAsPresented() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let memory = Memory(type: .onThisDay)
        context.insert(memory)
        try context.save()

        #expect(memory.wasPresented == false)
        #expect(memory.presentedDate == nil)

        try service.markMemoryAsPresented(memory)

        #expect(memory.wasPresented == true)
        #expect(memory.presentedDate != nil)
    }

    @Test("Mark photo as viewed updates lastViewedDate")
    @MainActor
    func markPhotoAsViewed() async throws {
        let container = try createContainer()
        let context = container.mainContext
        let service = MemorySurfacingService(modelContainer: container)

        let photo = Photo(assetIdentifier: "test-photo")
        context.insert(photo)
        try context.save()

        #expect(photo.lastViewedDate == nil)

        try service.markPhotoAsViewed(photo)

        #expect(photo.lastViewedDate != nil)
    }
}
