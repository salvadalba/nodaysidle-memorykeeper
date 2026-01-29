import Foundation

enum PhotoLibraryError: LocalizedError, Sendable {
    case accessDenied
    case accessRestricted
    case assetNotFound(String)
    case fetchFailed(String)
    case thumbnailLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access was denied. Please grant access in System Settings."
        case .accessRestricted:
            return "Photo library access is restricted on this device."
        case .assetNotFound(let id):
            return "Photo with identifier \(id) was not found."
        case .fetchFailed(let reason):
            return "Failed to fetch photos: \(reason)"
        case .thumbnailLoadFailed(let id):
            return "Failed to load thumbnail for photo \(id)."
        }
    }
}

enum VisionAnalysisError: LocalizedError, Sendable {
    case featurePrintFailed
    case classificationFailed
    case imageLoadFailed(String)
    case modelNotAvailable

    var errorDescription: String? {
        switch self {
        case .featurePrintFailed:
            return "Failed to generate image feature print."
        case .classificationFailed:
            return "Failed to classify image content."
        case .imageLoadFailed(let reason):
            return "Failed to load image for analysis: \(reason)"
        case .modelNotAvailable:
            return "Vision model is not available on this device."
        }
    }
}

enum CategorizationError: LocalizedError, Sendable {
    case noClassificationsFound
    case confidenceTooLow
    case mappingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noClassificationsFound:
            return "No content classifications were found for this image."
        case .confidenceTooLow:
            return "Classification confidence was below threshold."
        case .mappingFailed(let label):
            return "Failed to map classification label: \(label)"
        }
    }
}

enum DataStoreError: LocalizedError, Sendable {
    case saveFailed(String)
    case fetchFailed(String)
    case migrationFailed(String)
    case containerInitFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save data: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch data: \(reason)"
        case .migrationFailed(let reason):
            return "Database migration failed: \(reason)"
        case .containerInitFailed(let reason):
            return "Failed to initialize data store: \(reason)"
        }
    }
}
