# Technical Requirements Document

## 🧭 System Context
MemoryKeeper is a local-first macOS 15+ photo librarian using on-device Vision/CoreML for duplicate detection, auto-categorization, and memory surfacing. Built with SwiftUI 6, SwiftData, and Swift Structured Concurrency. No server infrastructure - all processing runs locally via Apple Silicon Neural Engine optimization.

## 🔌 API Contracts
### PhotoLibraryService
- **Method:** async
- **Description:** _Not specified_

### PhotoLibraryService
- **Method:** async
- **Description:** _Not specified_

### DuplicateDetectionService
- **Method:** async
- **Description:** _Not specified_

### DuplicateDetectionService
- **Method:** async
- **Description:** _Not specified_

### CategorizationService
- **Method:** async
- **Description:** _Not specified_

### CategorizationService
- **Method:** async
- **Description:** _Not specified_

### MemorySurfacingService
- **Method:** async
- **Description:** _Not specified_

### MemorySurfacingService
- **Method:** async
- **Description:** _Not specified_

### CaptionGenerationService
- **Method:** async
- **Description:** _Not specified_

### CaptionGenerationService
- **Method:** async
- **Description:** _Not specified_

### MetadataGraphService
- **Method:** async
- **Description:** _Not specified_

### MetadataGraphService
- **Method:** async
- **Description:** _Not specified_

## 🧱 Modules
### PhotoLibraryModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### DuplicateDetectionModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### CategorizationModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### MemorySurfacingModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### CaptionGenerationModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### DataPersistenceModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### UIModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### MenuBarModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

### SettingsModule
- **Responsibility:** _Not specified_
- **Dependencies:**
_None_

## 🗃 Data Model Notes
### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

### Unknown Entity
_None_

## 🔐 Validation & Security
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_
- **Rule:** _Not specified_

## 🧯 Error Handling Strategy
Swift typed throws with domain-specific error enums per module: PhotoLibraryError, VisionAnalysisError, CategorizationError, DataStoreError. All async functions propagate errors to callers. UI layer catches errors and presents localized alerts via SwiftUI .alert modifier. Background tasks log errors via os.Logger and continue processing remaining items. Critical errors (model load failure, database corruption) trigger user notification and graceful degradation to read-only mode.

## 🔭 Observability
- **Logging:** os.Logger with subsystem 'com.memorykeeper.app' and categories per module: PhotoLibrary, DuplicateDetection, Categorization, MemorySurfacing, DataStore, UI. Log levels: .debug for verbose ML metrics, .info for user actions, .error for failures. Unified Logging visible in Console.app.
- **Tracing:** Signpost intervals via os.signpost for performance analysis in Instruments: PhotoAnalysis, DuplicateDetection, MemoryGeneration, ThumbnailLoad. Enables Time Profiler correlation with code paths.
- **Metrics:**
- photos_analyzed_total: Counter of photos processed by categorization
- duplicates_detected_total: Counter of duplicate groups identified
- analysis_duration_seconds: Histogram of per-photo analysis time
- memory_surfaced_total: Counter of memories presented to user
- feature_print_cache_hits: Counter for cache efficiency tracking
- ui_photo_load_latency_ms: Histogram of thumbnail load times

## ⚡ Performance Notes
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_
- **Metric:** _Not specified_

## 🧪 Testing Strategy
### Unit
- DuplicateDetectionTests: similarity calculation accuracy with known image pairs
- CategorizationTests: category mapping from Vision classifications
- MemorySurfacingTests: relevance scoring algorithm with mock photo data
- CaptionGenerationTests: caption format and keyword extraction
- DataStoreTests: CRUD operations and relationship integrity with in-memory container
- PreferencesTests: validation rules for settings ranges
### Integration
- PhotoLibraryIntegrationTests: PHAsset fetching with test photo library
- VisionPipelineTests: end-to-end feature print generation and classification
- SwiftDataMigrationTests: schema evolution with versioned test databases
- BackgroundProcessingTests: TaskGroup cancellation and progress reporting
### E2E
- LibraryImportFlow: grant permissions → scan library → view categorized grid
- DuplicateReviewFlow: detect duplicates → review groups → resolve selections
- MemoryDiscoveryFlow: open app → view surfaced memory → navigate to full photo
- SettingsFlow: adjust threshold → re-analyze → verify changed results
- MenuBarFlow: click widget → view daily memory → open in main app

## 🚀 Rollout Plan
### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

### Phase
_Not specified_

## ❓ Open Questions
- Should duplicate resolution allow user to select preferred photo or auto-select by quality score?
- What is the minimum photo library size before analysis features become valuable (50? 100? 500 photos)?
- Should forgotten photos exclude favorites and recently edited items?
- How to handle HEIC/RAW vs JPEG when computing feature prints - convert first or process native?
- Should caption generation use Apple Intelligence APIs when available on macOS 15.1+?
- What CloudKit schema design if optional sync is enabled in future versions?
- Should MenuBarExtra show notification badge for new memories or remain passive?