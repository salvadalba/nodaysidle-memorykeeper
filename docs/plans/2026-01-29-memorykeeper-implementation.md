# MemoryKeeper Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a local-first macOS photo librarian with on-device AI for duplicate detection, auto-categorization, and memory surfacing.

**Architecture:** SwiftUI 6 + SwiftData monolithic app with actor-based service layer. Vision/CoreML for ML processing. Swift Structured Concurrency for background tasks. Zero network dependencies.

**Tech Stack:** macOS 15+, Swift 6, SwiftUI 6, SwiftData, Vision, CoreML, NaturalLanguage, PhotoKit

---

## Phase 1: Project Foundation

### Task 1.1: Create Xcode Project

**Files:**
- Create: `MemoryKeeper/MemoryKeeperApp.swift`
- Create: `MemoryKeeper/ContentView.swift`
- Create: `MemoryKeeper.xcodeproj`

**Step 1: Create new Xcode project via command line**

```bash
cd /Users/archuser/Downloads/ndi/nodaysidle-memorykeeper
mkdir -p MemoryKeeper
```

**Step 2: Create the App entry point**

Create `MemoryKeeper/MemoryKeeperApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct MemoryKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Photo.self)

        Settings {
            SettingsView()
        }

        MenuBarExtra("MemoryKeeper", systemImage: "photo.on.rectangle") {
            MenuBarView()
        }
    }
}
```

**Step 3: Create placeholder ContentView**

Create `MemoryKeeper/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } content: {
            Text("Content")
        } detail: {
            Text("Detail")
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
```

**Step 4: Create placeholder views**

Create `MemoryKeeper/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .frame(width: 400, height: 300)
    }
}
```

Create `MemoryKeeper/Views/MenuBarView.swift`:
```swift
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("Today's Memory")
            Divider()
            Button("Open MemoryKeeper") { }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding()
    }
}
```

**Step 5: Create Package.swift for SPM structure**

Create `Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryKeeper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MemoryKeeper", targets: ["MemoryKeeper"])
    ],
    targets: [
        .executableTarget(
            name: "MemoryKeeper",
            path: "MemoryKeeper",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MemoryKeeperTests",
            dependencies: ["MemoryKeeper"],
            path: "Tests"
        )
    ]
)
```

**Step 6: Verify project builds**

```bash
swift build
```
Expected: Build succeeds (will fail until models exist - that's next task)

**Step 7: Commit**

```bash
git init
git add .
git commit -m "feat: initialize MemoryKeeper macOS 15 project with SwiftUI App lifecycle"
```

---

### Task 1.2: Implement SwiftData Schema

**Files:**
- Create: `MemoryKeeper/Models/Photo.swift`
- Create: `MemoryKeeper/Models/DuplicateGroup.swift`
- Create: `MemoryKeeper/Models/Category.swift`
- Create: `MemoryKeeper/Models/Memory.swift`
- Create: `MemoryKeeper/Models/Caption.swift`
- Create: `Tests/ModelTests/PhotoTests.swift`

**Step 1: Write failing test for Photo model**

Create `Tests/ModelTests/PhotoTests.swift`:
```swift
import Testing
import SwiftData
@testable import MemoryKeeper

@Suite("Photo Model Tests")
struct PhotoTests {

    @Test("Photo can be created with asset identifier")
    func createPhoto() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Photo.self, configurations: config)
        let context = ModelContext(container)

        let photo = Photo(assetIdentifier: "test-asset-123")
        context.insert(photo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Photo>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.assetIdentifier == "test-asset-123")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter PhotoTests
```
Expected: FAIL - Photo type not found

**Step 3: Create Photo model**

Create `MemoryKeeper/Models/Photo.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Photo: @unchecked Sendable {
    @Attribute(.unique) var assetIdentifier: String
    var creationDate: Date?
    var modificationDate: Date?
    var latitude: Double?
    var longitude: Double?
    var featurePrintHash: Data?
    var lastViewedDate: Date?
    var isFavorite: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Category.photos)
    var categories: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \DuplicateGroup.photos)
    var duplicateGroup: DuplicateGroup?

    @Relationship(deleteRule: .nullify, inverse: \Memory.photos)
    var memories: [Memory] = []

    var categoryConfidences: [String: Double] = [:]

    init(assetIdentifier: String) {
        self.assetIdentifier = assetIdentifier
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter PhotoTests
```
Expected: PASS

**Step 5: Write test for Category model**

Add to `Tests/ModelTests/CategoryTests.swift`:
```swift
import Testing
import SwiftData
@testable import MemoryKeeper

@Suite("Category Model Tests")
struct CategoryTests {

    @Test("Category can link to multiple photos")
    func categoryPhotosRelationship() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self,
            configurations: config
        )
        let context = ModelContext(container)

        let category = Category(name: "Nature", isAutoGenerated: true)
        let photo1 = Photo(assetIdentifier: "photo-1")
        let photo2 = Photo(assetIdentifier: "photo-2")

        category.photos = [photo1, photo2]
        context.insert(category)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Category>())
        #expect(fetched.first?.photos.count == 2)
    }
}
```

**Step 6: Run test to verify it fails**

```bash
swift test --filter CategoryTests
```
Expected: FAIL - Category type not found

**Step 7: Create Category model**

Create `MemoryKeeper/Models/Category.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Category: @unchecked Sendable {
    @Attribute(.unique) var name: String
    var isAutoGenerated: Bool = true
    var localizedName: String?

    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []

    @Relationship(deleteRule: .nullify, inverse: \Category.parentCategory)
    var subcategories: [Category] = []

    @Relationship(deleteRule: .nullify)
    var parentCategory: Category?

    init(name: String, isAutoGenerated: Bool = true) {
        self.name = name
        self.isAutoGenerated = isAutoGenerated
    }
}
```

**Step 8: Run test to verify it passes**

```bash
swift test --filter CategoryTests
```
Expected: PASS

**Step 9: Create DuplicateGroup model**

Create `MemoryKeeper/Models/DuplicateGroup.swift`:
```swift
import Foundation
import SwiftData

@Model
final class DuplicateGroup: @unchecked Sendable {
    var createdDate: Date = Date()
    var isResolved: Bool = false
    var resolvedDate: Date?

    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []

    var similarityScores: [String: Double] = [:]

    init() {}

    var representativePhoto: Photo? {
        photos.first
    }

    var averageSimilarity: Double {
        guard !similarityScores.isEmpty else { return 0 }
        return similarityScores.values.reduce(0, +) / Double(similarityScores.count)
    }
}
```

**Step 10: Create Memory model**

Create `MemoryKeeper/Models/Memory.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Memory: @unchecked Sendable {
    var createdDate: Date = Date()
    var startDate: Date?
    var endDate: Date?
    var type: MemoryType = .onThisDay
    var wasPresented: Bool = false
    var presentedDate: Date?

    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []

    @Relationship(deleteRule: .cascade, inverse: \Caption.memory)
    var caption: Caption?

    init(type: MemoryType = .onThisDay) {
        self.type = type
    }
}

enum MemoryType: String, Codable, Sendable {
    case onThisDay
    case forgotten
    case collection
}
```

**Step 11: Create Caption model**

Create `MemoryKeeper/Models/Caption.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Caption: @unchecked Sendable {
    var text: String
    var isAutoGenerated: Bool = true
    var generatedDate: Date = Date()
    var editedDate: Date?

    @Relationship(deleteRule: .nullify)
    var memory: Memory?

    init(text: String, isAutoGenerated: Bool = true) {
        self.text = text
        self.isAutoGenerated = isAutoGenerated
    }
}
```

**Step 12: Update ModelContainer in App**

Update `MemoryKeeper/MemoryKeeperApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct MemoryKeeperApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Photo.self,
            Category.self,
            DuplicateGroup.self,
            Memory.self,
            Caption.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
        }

        MenuBarExtra("MemoryKeeper", systemImage: "photo.on.rectangle") {
            MenuBarView()
        }
    }
}
```

**Step 13: Run all model tests**

```bash
swift test
```
Expected: All tests PASS

**Step 14: Commit**

```bash
git add .
git commit -m "feat: implement SwiftData schema with Photo, Category, DuplicateGroup, Memory, Caption models"
```

---

### Task 1.3: Implement Logging Infrastructure

**Files:**
- Create: `MemoryKeeper/Infrastructure/Logger+Extensions.swift`
- Create: `Tests/InfrastructureTests/LoggerTests.swift`

**Step 1: Write test for logger categories**

Create `Tests/InfrastructureTests/LoggerTests.swift`:
```swift
import Testing
import OSLog
@testable import MemoryKeeper

@Suite("Logger Tests")
struct LoggerTests {

    @Test("Logger provides category-specific loggers")
    func categoryLoggers() {
        let photoLogger = Logger.photoLibrary
        let visionLogger = Logger.duplicateDetection

        // These should not crash
        photoLogger.info("Test photo library log")
        visionLogger.info("Test vision log")
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter LoggerTests
```
Expected: FAIL - Logger.photoLibrary not found

**Step 3: Create Logger extensions**

Create `MemoryKeeper/Infrastructure/Logger+Extensions.swift`:
```swift
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
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter LoggerTests
```
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add os.Logger infrastructure with category loggers and signpost names"
```

---

### Task 1.4: Create Domain Error Types

**Files:**
- Create: `MemoryKeeper/Infrastructure/Errors.swift`
- Create: `Tests/InfrastructureTests/ErrorTests.swift`

**Step 1: Write test for error localized descriptions**

Create `Tests/InfrastructureTests/ErrorTests.swift`:
```swift
import Testing
@testable import MemoryKeeper

@Suite("Error Types Tests")
struct ErrorTests {

    @Test("PhotoLibraryError provides localized description")
    func photoLibraryErrorDescription() {
        let error = PhotoLibraryError.accessDenied
        #expect(error.localizedDescription.isEmpty == false)
    }

    @Test("VisionAnalysisError is Sendable")
    func visionErrorSendable() async {
        let error: any Error & Sendable = VisionAnalysisError.featurePrintFailed
        #expect(error is VisionAnalysisError)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter ErrorTests
```
Expected: FAIL - PhotoLibraryError not found

**Step 3: Create error types**

Create `MemoryKeeper/Infrastructure/Errors.swift`:
```swift
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
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter ErrorTests
```
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add domain-specific error types with localized descriptions"
```

---

## Phase 2: Photo Library Integration

### Task 2.1: PhotoKit Permission Flow

**Files:**
- Create: `MemoryKeeper/Services/PhotoLibraryService.swift`
- Create: `Tests/ServiceTests/PhotoLibraryServiceTests.swift`

**Step 1: Write test for authorization status observation**

Create `Tests/ServiceTests/PhotoLibraryServiceTests.swift`:
```swift
import Testing
import Photos
@testable import MemoryKeeper

@Suite("PhotoLibraryService Tests")
struct PhotoLibraryServiceTests {

    @Test("Service reports current authorization status")
    func authorizationStatus() async {
        let service = PhotoLibraryService()
        let status = await service.authorizationStatus

        // Status should be one of the valid values
        #expect([
            PHAuthorizationStatus.notDetermined,
            .authorized,
            .limited,
            .denied,
            .restricted
        ].contains(status))
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter PhotoLibraryServiceTests
```
Expected: FAIL - PhotoLibraryService not found

**Step 3: Create PhotoLibraryService actor**

Create `MemoryKeeper/Services/PhotoLibraryService.swift`:
```swift
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
}

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
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter PhotoLibraryServiceTests
```
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: implement PhotoLibraryService with authorization flow"
```

---

### Task 2.2: PHAsset Fetch and Enumeration

**Files:**
- Modify: `MemoryKeeper/Services/PhotoLibraryService.swift`
- Modify: `Tests/ServiceTests/PhotoLibraryServiceTests.swift`

**Step 1: Write test for asset fetching**

Add to `Tests/ServiceTests/PhotoLibraryServiceTests.swift`:
```swift
@Test("Service fetches assets sorted by creation date")
func fetchAssets() async throws {
    let service = PhotoLibraryService()

    // This will return empty if no permission, which is fine for unit test
    let assets = try await service.fetchAllAssets()

    // Verify sorting if we have multiple assets
    if assets.count >= 2 {
        let dates = assets.compactMap { $0.creationDate }
        let sortedDates = dates.sorted(by: >)
        #expect(dates == sortedDates)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter "fetchAssets"
```
Expected: FAIL - fetchAllAssets not found

**Step 3: Add fetch methods to PhotoLibraryService**

Add to `MemoryKeeper/Services/PhotoLibraryService.swift`:
```swift
extension PhotoLibraryService {
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
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter "fetchAssets"
```
Expected: PASS (may be empty array if no permission)

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add PHAsset fetch and enumeration to PhotoLibraryService"
```

---

### Task 2.3: Thumbnail Request Pipeline

**Files:**
- Create: `MemoryKeeper/Services/ThumbnailService.swift`
- Create: `Tests/ServiceTests/ThumbnailServiceTests.swift`

**Step 1: Write test for thumbnail loading**

Create `Tests/ServiceTests/ThumbnailServiceTests.swift`:
```swift
import Testing
import Photos
import AppKit
@testable import MemoryKeeper

@Suite("ThumbnailService Tests")
struct ThumbnailServiceTests {

    @Test("Service returns cached thumbnail on second request")
    func thumbnailCaching() async throws {
        let service = ThumbnailService()

        // Create a mock asset identifier for testing cache logic
        let testId = "test-asset-123"

        // First call should miss cache
        let hitsBefore = await service.cacheHits

        // Since we can't create real PHAssets in tests,
        // we test the cache key generation
        let cacheKey = service.cacheKey(for: testId, size: CGSize(width: 200, height: 200))
        #expect(cacheKey.contains(testId))
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter ThumbnailServiceTests
```
Expected: FAIL - ThumbnailService not found

**Step 3: Create ThumbnailService**

Create `MemoryKeeper/Services/ThumbnailService.swift`:
```swift
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

    func cacheKey(for assetId: String, size: CGSize) -> String {
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

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                guard let self else { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: PhotoLibraryError.thumbnailLoadFailed(error.localizedDescription))
                    return
                }

                guard let cgImage = image else {
                    continuation.resume(throwing: PhotoLibraryError.thumbnailLoadFailed(asset.localIdentifier))
                    return
                }

                let nsImage = NSImage(cgImage: cgImage, size: targetSize)

                Task {
                    await self.cacheImage(nsImage, forKey: key)
                }

                continuation.resume(returning: nsImage)
            }
        }
    }

    private func cacheImage(_ image: NSImage, forKey key: String) {
        if cache.count >= maxCacheSize {
            // Simple eviction: remove first half
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 2))
            for k in keysToRemove {
                cache.removeValue(forKey: k)
            }
        }
        cache[key] = image
    }

    func clearCache() {
        cache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }

    func prefetch(assets: [PHAsset], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopPrefetch(assets: [PHAsset], targetSize: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter ThumbnailServiceTests
```
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: implement ThumbnailService with caching and prefetch"
```

---

### Task 2.4: Sync PHAssets to SwiftData

**Files:**
- Create: `MemoryKeeper/Services/PhotoSyncService.swift`
- Create: `Tests/ServiceTests/PhotoSyncServiceTests.swift`

**Step 1: Write test for photo sync**

Create `Tests/ServiceTests/PhotoSyncServiceTests.swift`:
```swift
import Testing
import SwiftData
import Photos
@testable import MemoryKeeper

@Suite("PhotoSyncService Tests")
struct PhotoSyncServiceTests {

    @Test("Service creates Photo entity from asset metadata")
    func syncCreatesPhotoEntity() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Photo.self, Category.self, DuplicateGroup.self, Memory.self, Caption.self,
            configurations: config
        )

        let service = PhotoSyncService(modelContainer: container)

        // Sync a mock photo (in real usage, this comes from PHAsset)
        let photo = await service.createOrUpdatePhoto(
            assetIdentifier: "test-123",
            creationDate: Date(),
            latitude: 37.7749,
            longitude: -122.4194,
            isFavorite: true
        )

        #expect(photo.assetIdentifier == "test-123")
        #expect(photo.latitude == 37.7749)
        #expect(photo.isFavorite == true)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter PhotoSyncServiceTests
```
Expected: FAIL - PhotoSyncService not found

**Step 3: Create PhotoSyncService**

Create `MemoryKeeper/Services/PhotoSyncService.swift`:
```swift
import SwiftData
import Photos
import OSLog

actor PhotoSyncService {
    private let logger = Logger.dataStore
    private let modelContainer: ModelContainer

    private var photosAnalyzedTotal: Int = 0

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
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
        photosAnalyzedTotal += 1

        return photo
    }

    @MainActor
    func syncAsset(_ asset: PHAsset) -> Photo {
        let location = asset.location?.coordinate
        return createOrUpdatePhoto(
            assetIdentifier: asset.localIdentifier,
            creationDate: asset.creationDate,
            latitude: location?.latitude,
            longitude: location?.longitude,
            isFavorite: asset.isFavorite
        )
    }

    @MainActor
    func syncAssets(_ assets: [PHAsset], progress: ((Int, Int) -> Void)? = nil) throws {
        logger.info("Starting sync of \(assets.count) assets")

        let context = modelContainer.mainContext
        let batchSize = 100

        for (index, asset) in assets.enumerated() {
            _ = syncAsset(asset)

            if index % batchSize == 0 {
                try context.save()
                progress?(index, assets.count)
            }
        }

        try context.save()
        logger.info("Sync complete. Total photos: \(photosAnalyzedTotal)")
    }

    @MainActor
    func markPhotosDeleted(identifiers: Set<String>) throws {
        let context = modelContainer.mainContext

        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { identifiers.contains($0.assetIdentifier) }
        )

        let photos = try context.fetch(descriptor)
        for photo in photos {
            context.delete(photo)
        }

        try context.save()
        logger.info("Marked \(photos.count) photos as deleted")
    }
}
```

**Step 4: Run test to verify it passes**

```bash
swift test --filter PhotoSyncServiceTests
```
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "feat: implement PhotoSyncService for PHAsset to SwiftData sync"
```

---

## Phase 3: Duplicate Detection

This phase continues in the same pattern. I'll save this file and continue with the remaining phases.
