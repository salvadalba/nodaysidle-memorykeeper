import Photos
import AppKit
import OSLog

actor ThumbnailService {
    private let logger = Logger.photoLibrary
    private let imageManager = PHCachingImageManager()
    private var cache: [String: NSImage] = [:]
    private let maxCacheSize = 500

    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0

    enum DeliveryMode: Sendable {
        case fast
        case highQuality
    }

    enum ThumbnailSize: Sendable {
        case small      // 100x100
        case medium     // 200x200
        case large      // 400x400

        var cgSize: CGSize {
            switch self {
            case .small: return CGSize(width: 100, height: 100)
            case .medium: return CGSize(width: 200, height: 200)
            case .large: return CGSize(width: 400, height: 400)
            }
        }
    }

    nonisolated func cacheKey(for assetId: String, size: CGSize) -> String {
        "\(assetId)-\(Int(size.width))x\(Int(size.height))"
    }

    func thumbnail(
        for asset: PHAsset,
        targetSize: CGSize,
        mode: DeliveryMode = .fast
    ) async throws -> NSImage {
        let key = cacheKey(for: asset.localIdentifier, size: targetSize)

        if let cached = cache[key] {
            cacheHits += 1
            return cached
        }

        cacheMisses += 1

        let options = PHImageRequestOptions()
        options.deliveryMode = mode == .fast ? .fastFormat : .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        options.resizeMode = .fast

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: PhotoLibraryError.thumbnailLoadFailed(error.localizedDescription))
                    return
                }

                // Check if this is a degraded image (low quality placeholder)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    // Wait for high quality version
                    return
                }

                guard let nsImage = image else {
                    continuation.resume(throwing: PhotoLibraryError.thumbnailLoadFailed(asset.localIdentifier))
                    return
                }

                if let self {
                    Task {
                        await self.cacheImage(nsImage, forKey: key)
                    }
                }

                continuation.resume(returning: nsImage)
            }
        }
    }

    func thumbnail(
        for asset: PHAsset,
        size: ThumbnailSize,
        mode: DeliveryMode = .fast
    ) async throws -> NSImage {
        try await thumbnail(for: asset, targetSize: size.cgSize, mode: mode)
    }

    private func cacheImage(_ image: NSImage, forKey key: String) {
        if cache.count >= maxCacheSize {
            // Simple eviction: remove first half
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 2))
            for k in keysToRemove {
                cache.removeValue(forKey: k)
            }
            logger.debug("Cache eviction: removed \(keysToRemove.count) items")
        }
        cache[key] = image
    }

    func clearCache() {
        cache.removeAll()
        cacheHits = 0
        cacheMisses = 0
        logger.info("Thumbnail cache cleared")
    }

    nonisolated func prefetch(assets: [PHAsset], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    nonisolated func stopPrefetch(assets: [PHAsset], targetSize: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    nonisolated func stopAllPrefetching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    var cacheStats: (hits: Int, misses: Int, size: Int) {
        (cacheHits, cacheMisses, cache.count)
    }
}
