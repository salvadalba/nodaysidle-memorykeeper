import NaturalLanguage
import SwiftData
import Foundation
import OSLog
import CoreLocation

actor CaptionGenerationService {
    private let logger = Logger.memorySurfacing
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Keyword Extraction

    struct PhotoKeywords: Sendable {
        var location: String?
        var season: String?
        var year: String?
        var dayOfWeek: String?
        var timeOfDay: String?
        var categories: [String] = []
    }

    nonisolated func extractKeywords(from photos: [Photo]) -> PhotoKeywords {
        var keywords = PhotoKeywords(categories: [])

        // Extract date-based keywords from first photo with a date
        if let firstDate = photos.compactMap(\.creationDate).first {
            let calendar = Calendar.current

            // Year
            keywords.year = String(calendar.component(.year, from: firstDate))

            // Season
            let month = calendar.component(.month, from: firstDate)
            keywords.season = seasonName(for: month)

            // Day of week
            let weekday = calendar.component(.weekday, from: firstDate)
            keywords.dayOfWeek = calendar.weekdaySymbols[weekday - 1]

            // Time of day
            let hour = calendar.component(.hour, from: firstDate)
            keywords.timeOfDay = timeOfDayName(for: hour)
        }

        // Extract categories
        let allCategories = photos.flatMap { $0.categories.map(\.name) }
        let uniqueCategories = Array(Set(allCategories))
        keywords.categories = uniqueCategories

        // Extract location (simplified - would need reverse geocoding for full implementation)
        if let lat = photos.compactMap(\.latitude).first,
           let lon = photos.compactMap(\.longitude).first {
            keywords.location = formatLocation(latitude: lat, longitude: lon)
        }

        return keywords
    }

    nonisolated private func seasonName(for month: Int) -> String {
        switch month {
        case 3...5: return "spring"
        case 6...8: return "summer"
        case 9...11: return "autumn"
        default: return "winter"
        }
    }

    nonisolated private func timeOfDayName(for hour: Int) -> String {
        switch hour {
        case 5...11: return "morning"
        case 12...16: return "afternoon"
        case 17...20: return "evening"
        default: return "night"
        }
    }

    nonisolated private func formatLocation(latitude: Double, longitude: Double) -> String {
        // Simplified location formatting
        // In a full implementation, you'd use CLGeocoder for reverse geocoding
        return "a memorable place"
    }

    // MARK: - Caption Templates

    private let onThisDayTemplates = [
        "Remember this {season} day from {year}?",
        "A {timeOfDay} to remember, {year}.",
        "{year} called—it misses you too.",
        "This {dayOfWeek} in {year} was special.",
        "A glimpse back to {season} {year}.",
        "Some moments from {year} worth revisiting.",
        "Look what you were up to in {year}.",
    ]

    private let forgottenTemplates = [
        "These moments have been waiting for you.",
        "Remember when?",
        "Some treasures from your library.",
        "Rediscover these forgotten moments.",
        "Time to revisit these memories.",
        "These photos miss you.",
        "A trip down memory lane awaits.",
    ]

    private let categoryTemplates: [String: [String]] = [
        "People": [
            "Faces that make life brighter.",
            "The people who matter most.",
            "Cherished moments with loved ones.",
        ],
        "Nature": [
            "Nature's beauty, captured by you.",
            "The great outdoors awaits.",
            "Scenes from the natural world.",
        ],
        "Travel": [
            "Adventures from your travels.",
            "Places you've explored.",
            "The world through your lens.",
        ],
        "Food": [
            "Culinary moments to savor.",
            "Delicious memories.",
            "A feast for the eyes.",
        ],
        "Pets": [
            "Furry friends and happy moments.",
            "Your beloved companions.",
            "Pawsitively adorable memories.",
        ]
    ]

    // MARK: - Caption Generation

    nonisolated func generateCaption(for memory: Memory) -> String {
        let keywords = extractKeywords(from: memory.photos)

        let template: String
        switch memory.type {
        case .onThisDay:
            template = onThisDayTemplates.randomElement() ?? onThisDayTemplates[0]
        case .forgotten:
            template = forgottenTemplates.randomElement() ?? forgottenTemplates[0]
        case .collection:
            // Use category-specific template if available
            if let mainCategory = keywords.categories.first,
               let templates = categoryTemplates[mainCategory] {
                template = templates.randomElement() ?? templates[0]
            } else {
                template = forgottenTemplates.randomElement() ?? forgottenTemplates[0]
            }
        }

        // Replace placeholders
        var caption = template
        caption = caption.replacingOccurrences(of: "{year}", with: keywords.year ?? "the past")
        caption = caption.replacingOccurrences(of: "{season}", with: keywords.season ?? "beautiful")
        caption = caption.replacingOccurrences(of: "{dayOfWeek}", with: keywords.dayOfWeek ?? "day")
        caption = caption.replacingOccurrences(of: "{timeOfDay}", with: keywords.timeOfDay ?? "moment")
        caption = caption.replacingOccurrences(of: "{location}", with: keywords.location ?? "a special place")

        return caption
    }

    nonisolated func generateCaptionForPhotos(_ photos: [Photo], type: MemoryType) -> String {
        let memory = Memory(type: type)
        memory.photos = photos
        return generateCaption(for: memory)
    }

    // MARK: - Persistence

    @MainActor
    func createCaption(for memory: Memory) throws -> Caption {
        let context = modelContainer.mainContext

        let text = generateCaption(for: memory)
        let caption = Caption(text: text, isAutoGenerated: true)
        caption.memory = memory
        memory.caption = caption

        context.insert(caption)
        try context.save()

        logger.info("Created caption for memory: \(text)")
        return caption
    }

    @MainActor
    func updateCaption(_ caption: Caption, newText: String) throws {
        let context = modelContainer.mainContext

        caption.text = newText
        caption.isAutoGenerated = false
        caption.editedDate = Date()

        try context.save()
        logger.info("Updated caption to: \(newText)")
    }

    @MainActor
    func regenerateCaption(for memory: Memory) throws -> Caption {
        let context = modelContainer.mainContext

        // Delete existing caption
        if let existingCaption = memory.caption {
            context.delete(existingCaption)
        }

        // Generate new one
        return try createCaption(for: memory)
    }
}
