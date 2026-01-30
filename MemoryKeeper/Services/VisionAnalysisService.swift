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
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        // Request a reasonable size for feature print (doesn't need full resolution)
        let targetSize = CGSize(width: 1024, height: 1024)

        // Use AsyncStream to handle multiple callbacks from PHImageManager
        var bestImage: CGImage?
        for await image in loadImageStream(asset: asset, targetSize: targetSize, options: options) {
            bestImage = image
        }

        guard let result = bestImage else {
            throw VisionAnalysisError.imageLoadFailed("No image returned")
        }
        return result
    }

    private func loadImageStream(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> AsyncStream<CGImage> {
        AsyncStream { continuation in
            var hasFinished = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil

                if let nsImage = image,
                   let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    continuation.yield(cgImage)
                }

                // Finish the stream when we get the final image or an error
                if !isDegraded || isCancelled || hasError {
                    if !hasFinished {
                        hasFinished = true
                        continuation.finish()
                    }
                }
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
