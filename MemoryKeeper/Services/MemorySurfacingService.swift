import SwiftData
import Foundation
import OSLog

@MainActor
final class MemorySurfacingService {
    private let logger = Logger.memorySurfacing
    private let modelContainer: ModelContainer

    private(set) var memoriesSurfacedTotal: Int = 0

    var forgottenMonths: Int = 12
    var excludeFavorites: Bool = false

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - On This Day

    func getOnThisDayPhotos(limit: Int = 10) throws -> [Photo] {
        let context = modelContainer.mainContext
        let calendar = Calendar.current
        let today = Date()

        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)

        // Fetch all photos and filter by month/day
        let descriptor = FetchDescriptor<Photo>(
            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
        )

        let allPhotos = try context.fetch(descriptor)

        let matchingPhotos = allPhotos.filter { photo in
            guard let creationDate = photo.creationDate else { return false }

            let photoMonth = calendar.component(.month, from: creationDate)
            let photoDay = calendar.component(.day, from: creationDate)
            let currentYear = calendar.component(.year, from: today)

            // Same month and day, but different year
            return photoMonth == currentMonth &&
                   photoDay == currentDay &&
                   calendar.component(.year, from: creationDate) != currentYear
        }

        // Weight older photos higher (more nostalgic)
        let weighted = matchingPhotos.sorted { photo1, photo2 in
            guard let date1 = photo1.creationDate,
                  let date2 = photo2.creationDate else { return false }
            return date1 < date2 // Older first
        }

        // Exclude recently viewed
        let filtered = weighted.filter { photo in
            guard let lastViewed = photo.lastViewedDate else { return true }
            let daysSinceViewed = calendar.dateComponents([.day], from: lastViewed, to: today).day ?? 0
            return daysSinceViewed > 7
        }

        logger.info("Found \(filtered.count) 'On This Day' photos")
        return Array(filtered.prefix(limit))
    }

    // MARK: - Forgotten Photos

    func getForgottenPhotos(limit: Int = 10) throws -> [Photo] {
        let context = modelContainer.mainContext
        let calendar = Calendar.current
        let today = Date()

        guard let cutoffDate = calendar.date(byAdding: .month, value: -forgottenMonths, to: today) else {
            return []
        }

        let descriptor = FetchDescriptor<Photo>()
        let allPhotos = try context.fetch(descriptor)

        let forgottenPhotos = allPhotos.filter { photo in
            // Must have a creation date
            guard photo.creationDate != nil else { return false }

            // Must not have been viewed recently
            if let lastViewed = photo.lastViewedDate, lastViewed > cutoffDate {
                return false
            }

            // Optionally exclude favorites
            if excludeFavorites && photo.isFavorite {
                return false
            }

            return true
        }

        // Weighted random selection for variety
        let shuffled = forgottenPhotos.shuffled()

        logger.info("Found \(shuffled.count) forgotten photos")
        return Array(shuffled.prefix(limit))
    }

    // MARK: - Memory Creation

    func createOnThisDayMemory() throws -> Memory? {
        let photos = try getOnThisDayPhotos()
        guard !photos.isEmpty else {
            logger.info("No photos for On This Day memory")
            return nil
        }

        let context = modelContainer.mainContext

        let memory = Memory(type: .onThisDay)
        memory.photos = photos
        memory.startDate = photos.compactMap(\.creationDate).min()
        memory.endDate = photos.compactMap(\.creationDate).max()

        context.insert(memory)
        try context.save()

        memoriesSurfacedTotal += 1
        logger.info("Created On This Day memory with \(photos.count) photos")

        return memory
    }

    func createForgottenMemory() throws -> Memory? {
        let photos = try getForgottenPhotos()
        guard !photos.isEmpty else {
            logger.info("No photos for Forgotten memory")
            return nil
        }

        let context = modelContainer.mainContext

        let memory = Memory(type: .forgotten)
        memory.photos = photos
        memory.startDate = photos.compactMap(\.creationDate).min()
        memory.endDate = photos.compactMap(\.creationDate).max()

        context.insert(memory)
        try context.save()

        memoriesSurfacedTotal += 1
        logger.info("Created Forgotten memory with \(photos.count) photos")

        return memory
    }

    // MARK: - Daily Memory Generation

    func generateDailyMemory() throws -> Memory? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if we already generated a memory today
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Memory>(
            predicate: #Predicate { memory in
                memory.createdDate >= today
            }
        )

        let todaysMemories = try context.fetch(descriptor)
        if !todaysMemories.isEmpty {
            logger.info("Already generated memory today")
            return todaysMemories.first
        }

        // Alternate between On This Day and Forgotten
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        if dayOfYear % 2 == 0 {
            return try createOnThisDayMemory() ?? createForgottenMemory()
        } else {
            return try createForgottenMemory() ?? createOnThisDayMemory()
        }
    }

    // MARK: - Memory Retrieval

    func getTodaysMemory() throws -> Memory? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Memory>(
            predicate: #Predicate { memory in
                memory.createdDate >= today
            },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    func getAllMemories(limit: Int = 50) throws -> [Memory] {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<Memory>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func markMemoryAsPresented(_ memory: Memory) throws {
        let context = modelContainer.mainContext
        memory.wasPresented = true
        memory.presentedDate = Date()
        try context.save()
    }

    func markPhotoAsViewed(_ photo: Photo) throws {
        let context = modelContainer.mainContext
        photo.lastViewedDate = Date()
        try context.save()
    }
}
