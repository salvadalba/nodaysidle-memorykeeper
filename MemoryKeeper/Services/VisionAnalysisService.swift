import Vision
import Photos
import AppKit
import OSLog

@MainActor
final class VisionAnalysisService {
    private let logger = Logger.duplicateDetection

    // MARK: - Feature Print Extraction

    nonisolated func extractFeaturePrint(from image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw VisionAnalysisError.featurePrintFailed
        }

        return result
    }

    func extractFeaturePrint(from asset: PHAsset) async throws -> VNFeaturePrintObservation {
        logger.debug("Extracting feature print from PHAsset: \(asset.localIdentifier)")

        let image = try await loadImage(from: asset)
        return try extractFeaturePrint(from: image)
    }

    nonisolated func extractFeaturePrintData(from featurePrint: VNFeaturePrintObservation) throws -> Data {
        return try NSKeyedArchiver.archivedData(withRootObject: featurePrint, requiringSecureCoding: true)
    }

    // MARK: - Image Loading

    private func loadImage(from asset: PHAsset) async throws -> CGImage {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        // Request a reasonable size for feature print (doesn't need full resolution)
        let targetSize = CGSize(width: 1024, height: 1024)

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: VisionAnalysisError.imageLoadFailed(error.localizedDescription))
                    return
                }

                // Skip degraded images
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    return
                }

                guard let nsImage = image,
                      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(throwing: VisionAnalysisError.imageLoadFailed("No image returned"))
                    return
                }

                continuation.resume(returning: cgImage)
            }
        }
    }

    // MARK: - Classification

    nonisolated func classifyImage(_ image: CGImage, minimumConfidence: Float = 0.7) throws -> [VNClassificationObservation] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        try handler.perform([request])

        guard let results = request.results else {
            throw VisionAnalysisError.classificationFailed
        }

        return results.filter { $0.confidence >= minimumConfidence }
    }

    func classifyAsset(_ asset: PHAsset, minimumConfidence: Float = 0.7) async throws -> [VNClassificationObservation] {
        let image = try await loadImage(from: asset)
        return try classifyImage(image, minimumConfidence: minimumConfidence)
    }
}
