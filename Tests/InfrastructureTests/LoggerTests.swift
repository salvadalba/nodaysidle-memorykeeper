import Testing
import OSLog
@testable import MemoryKeeper

@Suite("Logger Tests")
struct LoggerTests {

    @Test("Logger provides category-specific loggers")
    func categoryLoggers() {
        // These should not crash and should be accessible
        let photoLogger = Logger.photoLibrary
        let duplicateLogger = Logger.duplicateDetection
        let categorizationLogger = Logger.categorization
        let memoryLogger = Logger.memorySurfacing
        let dataStoreLogger = Logger.dataStore
        let uiLogger = Logger.ui

        // Log a test message to each
        photoLogger.info("Test photo library log")
        duplicateLogger.info("Test duplicate detection log")
        categorizationLogger.info("Test categorization log")
        memoryLogger.info("Test memory surfacing log")
        dataStoreLogger.info("Test data store log")
        uiLogger.info("Test UI log")

        // If we get here without crashing, the test passes
        #expect(true)
    }

    @Test("SignpostNames are defined")
    func signpostNames() {
        #expect(SignpostName.photoAnalysis == "PhotoAnalysis")
        #expect(SignpostName.duplicateDetection == "DuplicateDetection")
        #expect(SignpostName.memoryGeneration == "MemoryGeneration")
        #expect(SignpostName.thumbnailLoad == "ThumbnailLoad")
    }
}
