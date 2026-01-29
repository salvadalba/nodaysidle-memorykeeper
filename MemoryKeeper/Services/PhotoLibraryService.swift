import Photos
import OSLog

actor PhotoLibraryService {
    private let logger = Logger.photoLibrary

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        logger.info("Requesting photo library authorization")
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        logger.info("Authorization status: \(String(describing: status.rawValue))")
        return status
    }

    func authorizationStatusStream() -> AsyncStream<PHAuthorizationStatus> {
        AsyncStream { continuation in
            let initialStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            continuation.yield(initialStatus)

            let observer = PhotoLibraryObserver { status in
                continuation.yield(status)
            }

            continuation.onTermination = { _ in
                observer.stopObserving()
            }
        }
    }

    // MARK: - Asset Fetching

    func fetchAllAssets() async throws -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        logger.info("Fetching all photo assets")

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        logger.info("Fetched \(assets.count) assets")
        return assets
    }

    func fetchAssets(limit: Int) async throws -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    func fetchAsset(withIdentifier identifier: String) async throws -> PHAsset {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

        guard let asset = result.firstObject else {
            throw PhotoLibraryError.assetNotFound(identifier)
        }

        return asset
    }

    func assetStream() -> AsyncStream<PHAsset> {
        AsyncStream { continuation in
            Task {
                do {
                    let assets = try await fetchAllAssets()
                    for asset in assets {
                        continuation.yield(asset)
                    }
                    continuation.finish()
                } catch {
                    logger.error("Asset stream failed: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Change Observation

    func observeChanges() -> AsyncStream<PHChange> {
        AsyncStream { continuation in
            let observer = PhotoLibraryChangeObserver { change in
                continuation.yield(change)
            }

            continuation.onTermination = { _ in
                observer.stopObserving()
            }
        }
    }
}

// MARK: - Photo Library Observers

private final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private var onChange: ((PHAuthorizationStatus) -> Void)?

    init(onChange: @escaping (PHAuthorizationStatus) -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    func stopObserving() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        onChange = nil
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        onChange?(status)
    }
}

private final class PhotoLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private var onChange: ((PHChange) -> Void)?

    init(onChange: @escaping (PHChange) -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    func stopObserving() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        onChange = nil
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange?(changeInstance)
    }
}
