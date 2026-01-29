import Testing
@testable import MemoryKeeper

@Suite("Error Types Tests")
struct ErrorTests {

    @Test("PhotoLibraryError provides localized description")
    func photoLibraryErrorDescription() {
        let errors: [PhotoLibraryError] = [
            .accessDenied,
            .accessRestricted,
            .assetNotFound("test-id"),
            .fetchFailed("test reason"),
            .thumbnailLoadFailed("test-id")
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("VisionAnalysisError provides localized description")
    func visionErrorDescription() {
        let errors: [VisionAnalysisError] = [
            .featurePrintFailed,
            .classificationFailed,
            .imageLoadFailed("test reason"),
            .modelNotAvailable
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("CategorizationError provides localized description")
    func categorizationErrorDescription() {
        let errors: [CategorizationError] = [
            .noClassificationsFound,
            .confidenceTooLow,
            .mappingFailed("test label")
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("DataStoreError provides localized description")
    func dataStoreErrorDescription() {
        let errors: [DataStoreError] = [
            .saveFailed("test reason"),
            .fetchFailed("test reason"),
            .migrationFailed("test reason"),
            .containerInitFailed("test reason")
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("Errors are Sendable")
    func errorsSendable() async {
        let photoError: any Error & Sendable = PhotoLibraryError.accessDenied
        let visionError: any Error & Sendable = VisionAnalysisError.featurePrintFailed
        let categorizationError: any Error & Sendable = CategorizationError.noClassificationsFound
        let dataStoreError: any Error & Sendable = DataStoreError.saveFailed("test")

        #expect(photoError is PhotoLibraryError)
        #expect(visionError is VisionAnalysisError)
        #expect(categorizationError is CategorizationError)
        #expect(dataStoreError is DataStoreError)
    }
}
