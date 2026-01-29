import SwiftData
import Photos
import OSLog

@MainActor
final class PhotoSyncService {
    private let logger = Logger.dataStore
    private let modelContainer: ModelContainer

    private(set) var photosAnalyzedTotal: Int = 0

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func createOrUpdatePhoto(
        assetIdentifier: String,
        creationDate: Date?,
        latitude: Double?,
        longitude: Double?,
        isFavorite: Bool
    ) -> Photo {
        let context = modelContainer.mainContext

        // Check if photo already exists
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetIdentifier == assetIdentifier }
        )

        if let existing = try? context.fetch(descriptor).first {
            // Update existing
            existing.creationDate = creationDate
            existing.latitude = latitude
            existing.longitude = longitude
            existing.isFavorite = isFavorite
            existing.modificationDate = Date()
            return existing
        }

        // Create new
        let photo = Photo(assetIdentifier: assetIdentifier)
        photo.creationDate = creationDate
        photo.latitude = latitude
        photo.longitude = longitude
        photo.isFavorite = isFavorite

        context.insert(photo)

        return photo
    }

    func syncAsset(_ asset: PHAsset) -> Photo {
        let location = asset.location?.coordinate
        photosAnalyzedTotal += 1
        return createOrUpdatePhoto(
            assetIdentifier: asset.localIdentifier,
            creationDate: asset.creationDate,
            latitude: location?.latitude,
            longitude: location?.longitude,
            isFavorite: asset.isFavorite
        )
    }

    func syncAssets(_ assets: [PHAsset], progress: ((Int, Int) -> Void)? = nil) throws {
        logger.info("Starting sync of \(assets.count) assets")

        let context = modelContainer.mainContext
        let batchSize = 100

        for (index, asset) in assets.enumerated() {
            _ = syncAsset(asset)

            if index % batchSize == 0 {
                try context.save()
                progress?(index, assets.count)
                logger.debug("Synced \(index)/\(assets.count) photos")
            }
        }

        try context.save()
        logger.info("Sync complete. Total photos: \(self.photosAnalyzedTotal)")
    }

    func markPhotosDeleted(identifiers: Set<String>) throws {
        let context = modelContainer.mainContext

        for identifier in identifiers {
            let descriptor = FetchDescriptor<Photo>(
                predicate: #Predicate { $0.assetIdentifier == identifier }
            )

            if let photo = try context.fetch(descriptor).first {
                context.delete(photo)
            }
        }

        try context.save()
        logger.info("Marked \(identifiers.count) photos as deleted")
    }

    func getPhoto(byIdentifier identifier: String) -> Photo? {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetIdentifier == identifier }
        )
        return try? context.fetch(descriptor).first
    }

    func getAllPhotos() throws -> [Photo] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Photo>(
            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func getPhotosNeedingAnalysis() throws -> [Photo] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.featurePrintHash == nil }
        )
        return try context.fetch(descriptor)
    }

    func updateFeaturePrint(for photoId: String, hash: Data) throws {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetIdentifier == photoId }
        )

        if let photo = try context.fetch(descriptor).first {
            photo.featurePrintHash = hash
            try context.save()
        }
    }
}
