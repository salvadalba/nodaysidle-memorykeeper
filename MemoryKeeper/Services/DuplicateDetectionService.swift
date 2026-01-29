import Vision
import SwiftData
import Photos
import OSLog

@MainActor
final class DuplicateDetectionService {
    private let logger = Logger.duplicateDetection
    private let visionService: VisionAnalysisService
    private let modelContainer: ModelContainer

    private(set) var duplicatesDetectedTotal: Int = 0

    // Default similarity threshold (0.0 = identical, higher = more different)
    // Photos with distance below this are considered duplicates
    var similarityThreshold: Float = 0.5

    init(visionService: VisionAnalysisService, modelContainer: ModelContainer) {
        self.visionService = visionService
        self.modelContainer = modelContainer
    }

    // MARK: - Feature Print Comparison

    nonisolated func computeDistance(
        _ featurePrint1: VNFeaturePrintObservation,
        _ featurePrint2: VNFeaturePrintObservation
    ) throws -> Float {
        var distance: Float = 0
        try featurePrint1.computeDistance(&distance, to: featurePrint2)
        return distance
    }

    nonisolated func areDuplicates(
        _ featurePrint1: VNFeaturePrintObservation,
        _ featurePrint2: VNFeaturePrintObservation,
        threshold: Float = 0.5
    ) throws -> Bool {
        let distance = try computeDistance(featurePrint1, featurePrint2)
        return distance < threshold
    }

    // MARK: - Scanning Pipeline

    func scanForDuplicates(
        assets: [PHAsset],
        progress: ((Int, Int, String) -> Void)? = nil
    ) async throws -> [[PHAsset]] {
        logger.info("Starting duplicate scan for \(assets.count) assets")

        var featurePrints: [(PHAsset, VNFeaturePrintObservation)] = []

        // Extract feature prints sequentially to avoid Sendable issues
        for (index, asset) in assets.enumerated() {
            do {
                let fp = try await visionService.extractFeaturePrint(from: asset)
                featurePrints.append((asset, fp))
            } catch {
                logger.warning("Failed to extract feature print for \(asset.localIdentifier): \(error.localizedDescription)")
            }

            if index % 10 == 0 {
                progress?(index, assets.count, "Extracting feature prints...")
            }
        }

        logger.info("Extracted \(featurePrints.count) feature prints, comparing...")

        // Compare all pairs
        var duplicateGroups: [[PHAsset]] = []
        var processedIndices: Set<Int> = []

        for i in 0..<featurePrints.count {
            if processedIndices.contains(i) { continue }

            var group: [PHAsset] = [featurePrints[i].0]

            for j in (i + 1)..<featurePrints.count {
                if processedIndices.contains(j) { continue }

                do {
                    let distance = try computeDistance(featurePrints[i].1, featurePrints[j].1)
                    if distance < similarityThreshold {
                        group.append(featurePrints[j].0)
                        processedIndices.insert(j)
                    }
                } catch {
                    logger.warning("Failed to compare feature prints: \(error.localizedDescription)")
                }
            }

            if group.count > 1 {
                duplicateGroups.append(group)
                processedIndices.insert(i)
            }

            progress?(i, featurePrints.count, "Comparing photos...")
        }

        duplicatesDetectedTotal += duplicateGroups.count
        logger.info("Found \(duplicateGroups.count) duplicate groups")

        return duplicateGroups
    }

    // MARK: - Persistence

    func persistDuplicateGroups(_ groups: [[PHAsset]]) throws {
        let context = modelContainer.mainContext

        for assets in groups {
            let group = DuplicateGroup()

            for asset in assets {
                let assetId = asset.localIdentifier
                let descriptor = FetchDescriptor<Photo>(
                    predicate: #Predicate { photo in
                        photo.assetIdentifier == assetId
                    }
                )

                if let photo = try? context.fetch(descriptor).first {
                    group.photos.append(photo)
                }
            }

            if group.photos.count > 1 {
                context.insert(group)
            }
        }

        try context.save()
        logger.info("Persisted \(groups.count) duplicate groups")
    }

    func getUnresolvedDuplicateGroups() throws -> [DuplicateGroup] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DuplicateGroup>(
            predicate: #Predicate { !$0.isResolved }
        )
        return try context.fetch(descriptor)
    }

    func resolveDuplicateGroup(_ group: DuplicateGroup, keepPhoto: Photo) throws {
        let context = modelContainer.mainContext

        group.isResolved = true
        group.resolvedDate = Date()

        // Remove other photos from the group (but don't delete them - user can do that)
        for photo in group.photos where photo.assetIdentifier != keepPhoto.assetIdentifier {
            photo.duplicateGroup = nil
        }

        try context.save()
        logger.info("Resolved duplicate group, kept photo: \(keepPhoto.assetIdentifier)")
    }
}
