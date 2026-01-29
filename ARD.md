# Architecture Requirements Document

## 🧱 System Overview
MemoryKeeper is a local-first macOS photo librarian that uses on-device AI (Vision, CoreML, NaturalLanguage) to detect duplicates, auto-categorize content, and surface forgotten memories from the user's photo library without cloud dependencies. Built with SwiftUI 6 and SwiftData, it provides a warm, nostalgic editorial interface while maintaining complete privacy through local-only processing.

## 🏗 Architecture Style
Local-first monolithic macOS application with layered architecture separating UI, business logic, ML processing, and data persistence. Event-driven updates via Observation framework with background processing through Swift Structured Concurrency.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI 6 with NavigationSplitView, .ultraThinMaterial/.regularMaterial backgrounds, matchedGeometryEffect for seamless transitions, PhaseAnimator for load animations, TimelineView for dynamic memory displays
- **State Management:** Observation framework (@Observable classes) for view models, SwiftData @Query for reactive data binding, environment-based dependency injection for services
- **Routing:** NavigationSplitView with sidebar/content/detail pattern, NavigationStack for drill-down flows, WindowGroup for main window, MenuBarExtra for companion widget, Settings scene for preferences
- **Build Tooling:** Xcode 16+, Swift Package Manager for dependencies, Metal shader compilation for visual effects, CoreML model bundling, asset catalogs with SF Symbols

## 🧠 Backend Architecture
- **Approach:** In-process service layer with Swift Structured Concurrency (async/await, TaskGroups, Actors) for background ML processing and photo analysis without blocking UI
- **API Style:** Internal Swift protocols with async/await, Actor isolation for thread-safe ML processing, Sendable types for cross-actor data transfer
- **Services:**
- PhotoLibraryService: PhotoKit integration for library access, change observation, and asset fetching
- DuplicateDetectionService: Vision-based perceptual hashing with VNGenerateImageFeaturePrintRequest for similarity scoring
- CategorizationService: CoreML image classification using VNClassifyImageRequest for scene/object/activity detection
- MemorySurfacingService: Algorithm combining date analysis, location clustering, and content relevance for forgotten photo discovery
- CaptionGenerationService: NaturalLanguage framework for auto-generating editorial story captions from photo metadata
- MetadataGraphService: SwiftData relationship management connecting photos by people, places, events, and themes

## 🗄 Data Layer
- **Primary Store:** SwiftData with SQLite backing for metadata graph, photo analysis results, user preferences, and organizational state. PhotoKit remains source of truth for actual photo assets.
- **Relationships:** SwiftData @Model classes with @Relationship attributes: Photo (1:many) Tags, Photo (many:many) Categories, Photo (many:1) Event, Photo (many:many) People, Category (1:many) Subcategories. Lightweight references via PHAsset localIdentifier rather than duplicating photo data.
- **Migrations:** SwiftData automatic lightweight migrations with VersionedSchema for breaking changes, manual migration plans for complex schema evolution

## ☁️ Infrastructure
- **Hosting:** Standalone macOS application distributed via Mac App Store or direct notarized download. No server infrastructure required. Optional CloudKit sync disabled by default for privacy-first positioning.
- **Scaling Strategy:** Efficient memory management via lazy loading and thumbnail caching. Background processing with TaskGroup concurrency limits (4-8 parallel analysis tasks). Incremental library scanning with progress persistence. Metal-accelerated image processing for large libraries.
- **CI/CD:** Xcode Cloud or GitHub Actions with xcodebuild, automated testing via XCTest, notarization workflow for direct distribution, TestFlight for beta releases

## ⚖️ Key Trade-offs
- Local-only ML processing limits model sophistication compared to cloud services but ensures complete privacy and offline functionality
- PhotoKit integration provides seamless library access but restricts organization to non-destructive metadata without modifying original photos
- SwiftData chosen over Core Data for modern SwiftUI integration at cost of less mature migration tooling
- Monolithic architecture simplifies development and deployment but requires careful actor isolation to prevent ML processing from blocking UI
- macOS 15+ requirement enables latest SwiftUI/SwiftData features but limits addressable market to users on recent OS versions
- Menu bar companion adds discoverability for memory surfacing but increases complexity of window management

## 📐 Non-Functional Requirements
- Process 10,000+ photo library within 5 minutes using parallel TaskGroup analysis with progress reporting
- Zero network requests for photo analysis; all CoreML models bundled and run on-device
- UI maintains 60fps during photo browsing via lazy loading, thumbnail caching, and background processing
- Metadata database under 100MB for libraries up to 100,000 photos through efficient SwiftData schema
- macOS 15+ (Sequoia) with Apple Silicon Neural Engine optimization for CoreML inference
- Full VoiceOver accessibility with meaningful image descriptions from ML analysis
- Peak RAM usage under 2GB during intensive analysis via streaming processing and memory pooling
- App launch to interactive state under 1.5 seconds with deferred background analysis startup