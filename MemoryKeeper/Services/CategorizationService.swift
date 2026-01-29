import Vision
import SwiftData
import Photos
import OSLog

@MainActor
final class CategorizationService {
    private let logger = Logger.categorization
    private let visionService: VisionAnalysisService
    private let modelContainer: ModelContainer

    private(set) var photosAnalyzedTotal: Int = 0

    var minimumConfidence: Float = 0.7
    var maxCategoriesPerPhoto: Int = 5

    init(visionService: VisionAnalysisService, modelContainer: ModelContainer) {
        self.visionService = visionService
        self.modelContainer = modelContainer
    }

    // MARK: - Category Mapping

    /// Maps Vision's detailed labels to user-friendly categories
    nonisolated static let categoryMapping: [String: String] = [
        // People
        "person": "People",
        "face": "People",
        "crowd": "People",
        "portrait": "People",
        "selfie": "People",
        "baby": "People",
        "child": "People",

        // Pets & Animals
        "dog": "Pets",
        "cat": "Pets",
        "pet": "Pets",
        "animal": "Animals",
        "bird": "Animals",
        "fish": "Animals",
        "wildlife": "Animals",

        // Nature & Outdoors
        "landscape": "Nature",
        "mountain": "Nature",
        "beach": "Nature",
        "ocean": "Nature",
        "forest": "Nature",
        "tree": "Nature",
        "flower": "Nature",
        "garden": "Nature",
        "sunset": "Nature",
        "sunrise": "Nature",
        "sky": "Nature",
        "cloud": "Nature",
        "snow": "Nature",
        "rain": "Nature",

        // Food & Drink
        "food": "Food",
        "meal": "Food",
        "restaurant": "Food",
        "coffee": "Food",
        "drink": "Food",
        "fruit": "Food",
        "vegetable": "Food",
        "dessert": "Food",
        "cake": "Food",

        // Travel & Places
        "travel": "Travel",
        "landmark": "Travel",
        "architecture": "Travel",
        "building": "Travel",
        "city": "Travel",
        "street": "Travel",
        "bridge": "Travel",
        "monument": "Travel",
        "museum": "Travel",
        "hotel": "Travel",
        "airport": "Travel",

        // Activities & Events
        "sport": "Activities",
        "exercise": "Activities",
        "party": "Events",
        "celebration": "Events",
        "wedding": "Events",
        "birthday": "Events",
        "concert": "Events",
        "festival": "Events",
        "holiday": "Events",

        // Home & Indoor
        "interior": "Home",
        "room": "Home",
        "furniture": "Home",
        "kitchen": "Home",
        "bedroom": "Home",
        "living room": "Home",

        // Documents & Screenshots
        "document": "Documents",
        "text": "Documents",
        "screenshot": "Screenshots",
        "screen": "Screenshots",
        "receipt": "Documents",

        // Art & Creative
        "art": "Art",
        "painting": "Art",
        "drawing": "Art",
        "illustration": "Art",
        "design": "Art",

        // Vehicles
        "car": "Vehicles",
        "vehicle": "Vehicles",
        "airplane": "Vehicles",
        "boat": "Vehicles",
        "motorcycle": "Vehicles",
        "bicycle": "Vehicles"
    ]

    nonisolated func mapToCategory(_ visionLabel: String) -> String {
        let lowercased = visionLabel.lowercased()

        // Direct match
        if let category = Self.categoryMapping[lowercased] {
            return category
        }

        // Partial match
        for (key, category) in Self.categoryMapping {
            if lowercased.contains(key) {
                return category
            }
        }

        return "Other"
    }

    // MARK: - Categorization

    func categorizeAsset(_ asset: PHAsset) async throws -> [(String, Float)] {
        let classifications = try await visionService.classifyAsset(asset, minimumConfidence: minimumConfidence)

        var categoryScores: [String: Float] = [:]

        for classification in classifications {
            let category = mapToCategory(classification.identifier)
            let existingScore = categoryScores[category] ?? 0
            categoryScores[category] = max(existingScore, classification.confidence)
        }

        // Sort by confidence and limit
        let sorted = categoryScores.sorted { $0.value > $1.value }
        return Array(sorted.prefix(maxCategoriesPerPhoto))
    }

    // MARK: - Batch Processing

    func categorizeAssets(
        _ assets: [PHAsset],
        progress: ((Int, Int) -> Void)? = nil
    ) async throws -> [String: [(String, Float)]] {
        logger.info("Categorizing \(assets.count) assets")

        var results: [String: [(String, Float)]] = [:]

        for (index, asset) in assets.enumerated() {
            do {
                let categories = try await categorizeAsset(asset)
                results[asset.localIdentifier] = categories
                photosAnalyzedTotal += 1
            } catch {
                logger.warning("Failed to categorize \(asset.localIdentifier): \(error.localizedDescription)")
            }

            if index % 10 == 0 {
                progress?(index, assets.count)
            }
        }

        logger.info("Categorized \(results.count) assets")
        return results
    }

    // MARK: - Persistence

    func persistCategories(for photoId: String, categories: [(String, Float)]) throws {
        let context = modelContainer.mainContext

        let photoDescriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetIdentifier == photoId }
        )

        guard let photo = try context.fetch(photoDescriptor).first else {
            logger.warning("Photo not found for categorization: \(photoId)")
            return
        }

        // Store confidence scores
        var confidences: [String: Double] = [:]
        for (categoryName, confidence) in categories {
            confidences[categoryName] = Double(confidence)
        }
        photo.categoryConfidences = confidences

        // Link to Category entities
        for (categoryName, _) in categories {
            let categoryDescriptor = FetchDescriptor<Category>(
                predicate: #Predicate { $0.name == categoryName }
            )

            let category: Category
            if let existing = try context.fetch(categoryDescriptor).first {
                category = existing
            } else {
                category = Category(name: categoryName, isAutoGenerated: true)
                context.insert(category)
            }

            if !photo.categories.contains(where: { $0.name == categoryName }) {
                photo.categories.append(category)
            }
        }

        try context.save()
    }

    func persistAllCategories(_ results: [String: [(String, Float)]]) throws {
        for (photoId, categories) in results {
            try persistCategories(for: photoId, categories: categories)
        }
        logger.info("Persisted categories for \(results.count) photos")
    }

    func getAllCategories() throws -> [Category] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func getPhotos(inCategory categoryName: String) throws -> [Photo] {
        let context = modelContainer.mainContext

        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == categoryName }
        )

        guard let category = try context.fetch(categoryDescriptor).first else {
            return []
        }

        return category.photos
    }
}
