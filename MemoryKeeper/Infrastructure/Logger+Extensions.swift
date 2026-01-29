import OSLog

extension Logger {
    private static let subsystem = "com.memorykeeper.app"

    static let photoLibrary = Logger(subsystem: subsystem, category: "PhotoLibrary")
    static let duplicateDetection = Logger(subsystem: subsystem, category: "DuplicateDetection")
    static let categorization = Logger(subsystem: subsystem, category: "Categorization")
    static let memorySurfacing = Logger(subsystem: subsystem, category: "MemorySurfacing")
    static let dataStore = Logger(subsystem: subsystem, category: "DataStore")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}

enum SignpostName {
    static let photoAnalysis = "PhotoAnalysis"
    static let duplicateDetection = "DuplicateDetection"
    static let memoryGeneration = "MemoryGeneration"
    static let thumbnailLoad = "ThumbnailLoad"
}
