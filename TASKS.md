# Tasks Plan — MemoryKeeper

## 📌 Global Assumptions
- macOS 15 Sequoia is the minimum deployment target
- User has Apple Silicon Mac for Neural Engine optimization
- Photo library accessed is local (no iCloud Photos streaming)
- No network connectivity required for core features
- Swift 6 strict concurrency mode enabled
- SwiftUI 6 and SwiftData are stable for production use
- Vision framework's VNFeaturePrintObservation is sufficient for duplicate detection
- No server backend - all processing is on-device

## ⚠️ Risks
- Large photo libraries (100k+) may cause memory pressure during initial scan
- Vision feature print accuracy may vary for certain photo types (screenshots, documents)
- SwiftData performance with complex queries on large datasets unvalidated
- PhotoKit limited selection mode may frustrate users wanting full library access
- No Apple Intelligence API access means caption generation is template-based only

## 🧩 Epics
## Project Foundation
**Goal:** Establish the core project structure, SwiftData models, and app scaffolding for macOS 15+

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create Xcode project with SwiftUI App lifecycle (XS)

Initialize macOS 15+ project with SwiftUI 6, Swift 6 strict concurrency, and proper bundle identifiers. Configure for Apple Silicon optimization.

**Acceptance Criteria**
- Project compiles with Swift 6 language mode
- Strict concurrency checking enabled
- macOS 15 deployment target set
- App runs and displays empty window

**Dependencies**
_None_

### ✅ Design and implement SwiftData schema (S)

Create @Model classes for Photo, DuplicateGroup, Category, Memory, and Caption entities with relationships. Include migration plan.

**Acceptance Criteria**
- Photo model with asset identifier, feature print hash, timestamps, and category relationships
- DuplicateGroup model linking similar photos with similarity scores
- Category model with name, auto-generated flag, and photo relationships
- Memory model with date range, photos, and generated caption
- Schema versioning configured for future migrations
- In-memory container works for testing

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

### ✅ Implement os.Logger infrastructure (XS)

Set up logging subsystem 'com.memorykeeper.app' with categories: PhotoLibrary, DuplicateDetection, Categorization, MemorySurfacing, DataStore, UI. Include signpost intervals.

**Acceptance Criteria**
- Logger extension provides typed category loggers
- Log levels correctly differentiate debug/info/error
- Signposts defined for PhotoAnalysis, DuplicateDetection, MemoryGeneration, ThumbnailLoad
- Logs visible in Console.app with subsystem filter

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

### ✅ Create domain-specific error types (XS)

Define typed error enums for each module: PhotoLibraryError, VisionAnalysisError, CategorizationError, DataStoreError. Include localized descriptions.

**Acceptance Criteria**
- Each error enum covers expected failure cases
- Errors conform to LocalizedError with user-facing messages
- Errors are Sendable for structured concurrency
- Unit tests verify error descriptions

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

## Photo Library Integration
**Goal:** Integrate with PhotoKit to access and monitor the user's photo library with proper permissions

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement PhotoKit permission flow (S)

Create PhotoLibraryService actor that requests and monitors PHAuthorizationStatus. Handle all authorization states gracefully.

**Acceptance Criteria**
- Service correctly requests read-only photo library access
- All authorization states handled (authorized, limited, denied, restricted)
- Permission changes observed and propagated via AsyncStream
- UI displays appropriate guidance for denied state

**Dependencies**
- Design and implement SwiftData schema

### ✅ Build PHAsset fetch and enumeration (M)

Implement async photo enumeration using PHFetchResult with support for incremental loading. Include change observation.

**Acceptance Criteria**
- Fetches all PHAssets sorted by creation date
- Supports limited selection mode asset enumeration
- PHPhotoLibraryChangeObserver updates propagated
- Memory-efficient enumeration for large libraries (50k+ photos)
- Cancellation support via Task cancellation

**Dependencies**
- Implement PhotoKit permission flow

### ✅ Create thumbnail request pipeline (S)

Implement thumbnail loading with PHImageManager using requestImage. Support multiple target sizes and caching.

**Acceptance Criteria**
- Async thumbnail requests with configurable target size
- Fast vs high-quality delivery modes supported
- Request cancellation on view disappearance
- Thumbnail cache with memory budget
- ui_photo_load_latency_ms metrics emitted

**Dependencies**
- Build PHAsset fetch and enumeration

### ✅ Sync PHAssets to SwiftData Photo entities (M)

Create import pipeline that syncs PHAsset metadata to Photo @Model instances. Handle additions, modifications, and deletions.

**Acceptance Criteria**
- New PHAssets create Photo entities with local identifier
- Modified assets update Photo metadata
- Deleted assets mark Photo entities for cleanup
- Batch inserts for initial library scan performance
- photos_analyzed_total metric incremented

**Dependencies**
- Build PHAsset fetch and enumeration
- Design and implement SwiftData schema

## Duplicate Detection
**Goal:** Detect visually similar photos using Vision framework feature prints

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement Vision feature print extraction (M)

Create VisionAnalysisService actor that generates VNFeaturePrintObservation for photos. Optimize for Neural Engine.

**Acceptance Criteria**
- Generates feature print from CGImage or PHAsset
- Handles HEIC, JPEG, and RAW formats
- analysis_duration_seconds histogram updated
- Errors surfaced as VisionAnalysisError
- Feature print hash stored on Photo entity

**Dependencies**
- Sync PHAssets to SwiftData Photo entities

### ✅ Build feature print comparison engine (S)

Implement similarity calculation using VNFeaturePrintObservation.computeDistance. Define configurable similarity threshold.

**Acceptance Criteria**
- Computes distance between two feature prints
- Threshold-based duplicate determination (default 0.5)
- Handles comparison of photo against collection efficiently
- DuplicateDetectionTests validate accuracy with test pairs

**Dependencies**
- Implement Vision feature print extraction

### ✅ Create background duplicate scanning pipeline (M)

Implement DuplicateDetectionService that scans library for duplicates using TaskGroup. Support incremental and full scans.

**Acceptance Criteria**
- Full scan processes entire library with progress reporting
- Incremental scan checks only new/modified photos
- TaskGroup parallelism bounded to avoid memory pressure
- Cancellation stops scan gracefully
- duplicates_detected_total counter updated

**Dependencies**
- Build feature print comparison engine

### ✅ Feature print caching system (S)

Persist extracted feature prints to avoid re-computation. Track cache hits for efficiency metrics.

**Acceptance Criteria**
- Feature prints serialized and stored with Photo entity
- Cache lookup before extraction attempt
- feature_print_cache_hits counter incremented on hit
- Cache invalidation on photo modification

**Dependencies**
- Build feature print comparison engine

### ✅ Persist duplicate groups to SwiftData (S)

Store detected duplicate groups with similarity scores. Support merging overlapping groups.

**Acceptance Criteria**
- DuplicateGroup entities created with member photos
- Similarity scores stored per relationship
- Overlapping groups merged correctly
- Groups updated on incremental scan
- Deletion of resolved groups supported

**Dependencies**
- Create background duplicate scanning pipeline

## Auto-Categorization
**Goal:** Automatically categorize photos by content using Vision image classification

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement Vision classification request (S)

Create CategorizationService actor that performs VNClassifyImageRequest to get content labels with confidence scores.

**Acceptance Criteria**
- Generates classification observations from image
- Filters by minimum confidence threshold (0.7)
- Returns top N classifications (default 5)
- Handles VNClassifyImageRequest errors gracefully

**Dependencies**
- Sync PHAssets to SwiftData Photo entities

### ✅ Map Vision labels to user-friendly categories (S)

Create mapping from Vision's 1000+ labels to curated category set (People, Pets, Nature, Food, Travel, etc).

**Acceptance Criteria**
- Mapping dictionary covers common Vision labels
- Unmapped labels fall back to 'Other' category
- CategorizationTests verify mapping accuracy
- Categories localized for display

**Dependencies**
- Implement Vision classification request

### ✅ Build background categorization pipeline (M)

Process photos through categorization on background TaskGroup. Support batch processing for initial scan.

**Acceptance Criteria**
- Categorizes uncategorized photos in background
- Progress reporting via AsyncStream
- Bounded parallelism for memory efficiency
- Cancellation supported
- photos_analyzed_total metric updated

**Dependencies**
- Map Vision labels to user-friendly categories

### ✅ Store category assignments in SwiftData (S)

Persist photo-to-category relationships with confidence scores. Support multiple categories per photo.

**Acceptance Criteria**
- Photo entity links to multiple Category entities
- Confidence score stored per relationship
- Category entities created on-demand
- Query by category returns sorted photo list

**Dependencies**
- Build background categorization pipeline

## Memory Surfacing
**Goal:** Surface forgotten photos as memories using time-based and content-based algorithms

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Implement 'On This Day' algorithm (S)

Create MemorySurfacingService that finds photos from previous years on current date. Weight by age and uniqueness.

**Acceptance Criteria**
- Fetches photos from same month/day in previous years
- Weights older photos higher for nostalgia
- Excludes recently viewed photos
- Returns configurable limit (default 10)
- MemorySurfacingTests validate relevance scoring

**Dependencies**
- Store category assignments in SwiftData

### ✅ Implement forgotten photos discovery (S)

Find photos that haven't been viewed in configurable period and have good quality scores.

**Acceptance Criteria**
- Identifies photos not viewed in N months (default 12)
- Filters by minimum quality heuristics
- Optionally excludes favorites
- Weighted random selection for variety

**Dependencies**
- Store category assignments in SwiftData

### ✅ Create Memory entity persistence (S)

Store generated memories with associated photos, date range, and metadata for rediscovery prevention.

**Acceptance Criteria**
- Memory entity stores photos, creation date, type
- Presented memories tracked to avoid repeats
- Memories queryable by date and type
- memory_surfaced_total counter updated

**Dependencies**
- Implement 'On This Day' algorithm
- Implement forgotten photos discovery

### ✅ Implement memory scheduling (S)

Schedule memory generation to run daily at configurable time. Use UserDefaults for next generation timestamp.

**Acceptance Criteria**
- Generates new memory once per day
- Generation time configurable in settings
- Skips generation if no eligible photos
- Gracefully handles app not running at scheduled time

**Dependencies**
- Create Memory entity persistence

## Caption Generation
**Goal:** Generate editorial captions for memories using on-device NaturalLanguage processing

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Extract keywords from photo metadata (S)

Use NLTagger and Vision labels to extract key terms for caption generation. Include location, date, and content terms.

**Acceptance Criteria**
- Extracts location names from photo metadata
- Includes date-based terms (season, year, day of week)
- Incorporates Vision classification labels
- CaptionGenerationTests verify keyword extraction

**Dependencies**
- Create Memory entity persistence

### ✅ Build template-based caption generator (S)

Create CaptionGenerationService that combines keywords with editorial templates for warm, nostalgic captions.

**Acceptance Criteria**
- Multiple template variations for variety
- Templates include placeholders for location, time, content
- Generated captions feel editorial, not robotic
- Supports singular and plural photo contexts

**Dependencies**
- Extract keywords from photo metadata

### ✅ Store captions with Memory entities (XS)

Persist generated captions and allow user editing. Track auto vs user-edited state.

**Acceptance Criteria**
- Caption stored on Memory entity
- Auto-generated flag distinguishes from user edits
- User can edit and save custom caption
- Regeneration possible for auto captions

**Dependencies**
- Build template-based caption generator

## Main Window UI
**Goal:** Build the primary photo browsing interface with warm, editorial aesthetic

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create app-wide typography system (S)

Implement Typography enum/extension providing SF Pro Rounded, Display, Text, and New York fonts as specified in design spec.

**Acceptance Criteria**
- Hero titles use SF Pro Rounded Semibold 34-40pt
- Section headers use SF Pro Display Medium 20-28pt
- Body uses SF Pro Text Regular 13-15pt
- Captions use New York Regular/Italic 14-16pt
- Tags use SF Pro Rounded Medium 11-12pt
- +2% tracking applied to captions

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

### ✅ Implement photo grid view with LazyVGrid (M)

Create responsive photo grid using LazyVGrid. Support dynamic column count based on window width.

**Acceptance Criteria**
- Grid displays thumbnails efficiently
- Column count adapts to window width
- Smooth scrolling with 50k+ photos
- Selection state highlighted visually
- matchedGeometryEffect prepared for detail transition

**Dependencies**
- Create thumbnail request pipeline
- Create app-wide typography system

### ✅ Build photo detail view with transitions (M)

Create full-size photo view with matchedGeometryEffect transition from grid. Show metadata and actions.

**Acceptance Criteria**
- Hero transition from grid thumbnail
- Full resolution image loading with progress
- Metadata display (date, location, camera)
- Navigation to next/previous photo
- .ultraThinMaterial overlay for controls

**Dependencies**
- Implement photo grid view with LazyVGrid

### ✅ Create category sidebar navigation (M)

Build sidebar with NavigationSplitView showing categories, smart albums, and search. Support collapsing.

**Acceptance Criteria**
- Categories listed with photo counts
- Selection filters main grid
- Smart albums (Duplicates, Memories) in sidebar
- Search field with instant filtering
- Sidebar collapses on narrow windows

**Dependencies**
- Implement photo grid view with LazyVGrid
- Store category assignments in SwiftData

### ✅ Implement font weight animation on load (S)

Use variable font weight axis to animate text from Light to Regular when photos appear.

**Acceptance Criteria**
- Text animates weight on photo thumbnail appearance
- Animation duration subtle (0.3s ease-out)
- Works with SF Pro variable font axis
- Disabled in reduced motion accessibility mode

**Dependencies**
- Implement photo grid view with LazyVGrid

## Duplicate Review UI
**Goal:** Provide interface for reviewing and resolving detected duplicates

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build duplicate groups list view (S)

Create view showing duplicate groups with representative thumbnails and similarity indicators.

**Acceptance Criteria**
- Groups listed with count badges
- Representative thumbnail for each group
- Similarity percentage displayed
- Sort by group size or similarity
- Empty state for no duplicates

**Dependencies**
- Persist duplicate groups to SwiftData
- Create category sidebar navigation

### ✅ Create duplicate comparison view (M)

Side-by-side comparison of duplicate photos with quality indicators and selection controls.

**Acceptance Criteria**
- Photos displayed side-by-side at equal scale
- Quality indicators (resolution, file size, date)
- Selection checkbox per photo
- Recommend best quality photo visually
- Gesture support for quick selection

**Dependencies**
- Build duplicate groups list view

### ✅ Implement duplicate resolution actions (S)

Allow user to keep selected, trash others, or merge metadata. Persist resolution state.

**Acceptance Criteria**
- Keep selected photos action
- Move duplicates to trash action
- Undo support for resolutions
- DuplicateGroup marked resolved after action
- Confirmation dialog for destructive actions

**Dependencies**
- Create duplicate comparison view

## Memory Presentation UI
**Goal:** Display surfaced memories with editorial presentation

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Build memory card component (S)

Create memory presentation card with hero photo, caption, and date range. Use New York font for editorial feel.

**Acceptance Criteria**
- Hero photo with rounded corners
- Caption in New York italic below photo
- Date range displayed elegantly
- Photo count indicator
- Card has warm shadow and material background

**Dependencies**
- Store captions with Memory entities
- Create app-wide typography system

### ✅ Create memories feed view (S)

Scrollable feed of memory cards using TimelineView for time-based updates.

**Acceptance Criteria**
- Vertical scroll of memory cards
- New memories appear with animation
- Empty state for no memories yet
- Pull to refresh generates new memory
- TimelineView updates at midnight for new day

**Dependencies**
- Build memory card component

### ✅ Build memory detail slideshow (M)

Full-screen memory presentation with photo slideshow and PhaseAnimator transitions.

**Acceptance Criteria**
- Full-screen photo slideshow
- PhaseAnimator handles photo transitions
- Caption overlay with .regularMaterial
- Play/pause controls
- Navigation to individual photos

**Dependencies**
- Create memories feed view

### ✅ Add memory caption editing (S)

Allow users to edit auto-generated captions inline with elegant text field styling.

**Acceptance Criteria**
- Tap caption to enter edit mode
- New York font maintained in edit mode
- Save on blur or Enter key
- Revert option for edited captions
- Character limit indicator

**Dependencies**
- Build memory card component

## Menu Bar Widget
**Goal:** Provide quick access to daily memories via MenuBarExtra

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create MenuBarExtra app scene (S)

Add MenuBarExtra scene to App struct with photo icon. Configure for click activation.

**Acceptance Criteria**
- Menu bar icon appears on app launch
- Icon uses SF Symbol photo.on.rectangle
- Click opens popover, not menu
- App runs in background when window closed

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

### ✅ Build daily memory popover view (S)

Create compact memory card view for menu bar popover. Show today's surfaced memory.

**Acceptance Criteria**
- Displays today's memory photo
- Caption visible in compact form
- Click opens main app to memory
- Graceful empty state if no memory
- Popover size appropriate (300x400)

**Dependencies**
- Create MenuBarExtra app scene
- Build memory card component

### ✅ Add quick actions to menu bar (XS)

Include actions for opening main app, generating new memory, and accessing settings.

**Acceptance Criteria**
- Open MemoryKeeper button
- Refresh memory action
- Settings shortcut
- Quit app option
- Keyboard shortcut hints displayed

**Dependencies**
- Build daily memory popover view

## Settings & Preferences
**Goal:** Provide user-configurable options via Settings scene

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create Settings scene with tabs (S)

Add Settings scene with General, Analysis, and Appearance tabs using native macOS settings style.

**Acceptance Criteria**
- Settings window opens via Cmd+,
- Tab bar with icons and labels
- Native macOS settings appearance
- Window remembers size and position

**Dependencies**
- Create Xcode project with SwiftUI App lifecycle

### ✅ Implement General preferences (S)

Add controls for launch at login, menu bar visibility, and notification preferences.

**Acceptance Criteria**
- Launch at login toggle (ServiceManagement)
- Show in menu bar toggle
- Memory notification toggle
- Daily memory time picker
- Preferences persisted to UserDefaults

**Dependencies**
- Create Settings scene with tabs

### ✅ Implement Analysis preferences (S)

Add controls for duplicate similarity threshold, categorization confidence, and forgotten photo timeframe.

**Acceptance Criteria**
- Similarity threshold slider (0.3-0.8)
- Categorization confidence slider (0.5-0.9)
- Forgotten months picker (6-24)
- Exclude favorites from forgotten toggle
- Reset to defaults button

**Dependencies**
- Create Settings scene with tabs

### ✅ Implement Appearance preferences (S)

Add controls for thumbnail size, grid spacing, and animation preferences.

**Acceptance Criteria**
- Thumbnail size picker (small/medium/large)
- Grid spacing slider
- Reduce animations toggle
- Font size adjustment
- Live preview of changes

**Dependencies**
- Create Settings scene with tabs

## Error Handling & Polish
**Goal:** Implement robust error handling, accessibility, and final polish

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Create error alert presentation system (S)

Build reusable error presentation using .alert modifier. Map domain errors to user-friendly messages.

**Acceptance Criteria**
- Errors presented via SwiftUI alerts
- Domain errors mapped to localized messages
- Retry action where applicable
- Error details available for support
- Non-blocking errors use toast instead

**Dependencies**
- Create domain-specific error types

### ✅ Implement graceful degradation (M)

Handle critical failures (model load, database corruption) by switching to read-only mode with clear messaging.

**Acceptance Criteria**
- Database corruption detected and messaged
- Vision model failure disables analysis features
- Read-only mode prevents data loss
- User guided to recovery steps
- Logging captures degradation events

**Dependencies**
- Create error alert presentation system

### ✅ Add VoiceOver accessibility labels (M)

Ensure all UI elements have appropriate accessibility labels and traits for VoiceOver users.

**Acceptance Criteria**
- Photos have descriptive labels (date, category)
- Buttons have clear action labels
- Custom controls expose traits
- Navigation structure logical for VoiceOver
- Tested with VoiceOver enabled

**Dependencies**
- Build photo detail view with transitions
- Create duplicate comparison view
- Build memory detail slideshow

### ✅ Implement keyboard navigation (S)

Add full keyboard support for grid navigation, actions, and dialogs.

**Acceptance Criteria**
- Arrow keys navigate grid
- Enter opens detail view
- Escape closes overlays
- Tab navigates focusable elements
- Shortcuts documented in menu

**Dependencies**
- Build photo detail view with transitions

### ✅ Add first-launch onboarding (M)

Create onboarding flow explaining features and requesting photo library permission.

**Acceptance Criteria**
- Welcome screen with app overview
- Permission request with clear explanation
- Brief feature tour (3-4 screens)
- Skip option for returning users
- Completes to main library view

**Dependencies**
- Implement PhotoKit permission flow
- Implement photo grid view with LazyVGrid

### ✅ Performance optimization pass (M)

Profile with Instruments and optimize thumbnail loading, grid scrolling, and memory analysis.

**Acceptance Criteria**
- Grid scrolls at 60fps with 50k photos
- Thumbnail load latency under 50ms
- Memory analysis under 200MB baseline
- No main thread blocking operations
- Signpost data validates improvements

**Dependencies**
- Implement photo grid view with LazyVGrid
- Create background duplicate scanning pipeline

## Testing
**Goal:** Implement comprehensive test suite covering unit, integration, and E2E scenarios

### User Stories
_None_

### Acceptance Criteria
_None_

### ✅ Write DuplicateDetection unit tests (S)

Test similarity calculation with known image pairs. Verify accuracy meets threshold.

**Acceptance Criteria**
- Tests cover identical image comparison
- Tests cover similar image pairs
- Tests cover dissimilar images
- Edge cases (corrupt images, zero-byte) handled
- 95%+ accuracy on test dataset

**Dependencies**
- Build feature print comparison engine

### ✅ Write Categorization unit tests (S)

Test Vision label to category mapping with mock classification data.

**Acceptance Criteria**
- All mapped labels resolve correctly
- Unmapped labels fall back to Other
- Confidence filtering works
- Multiple categories per photo handled

**Dependencies**
- Map Vision labels to user-friendly categories

### ✅ Write MemorySurfacing unit tests (S)

Test relevance scoring and date-based filtering with mock photo data.

**Acceptance Criteria**
- On This Day finds correct date matches
- Forgotten photos respects time threshold
- Exclusion filters work
- Weighting produces expected rankings

**Dependencies**
- Create Memory entity persistence

### ✅ Write SwiftData persistence tests (S)

Test CRUD operations and relationship integrity using in-memory ModelContainer.

**Acceptance Criteria**
- Create operations persist correctly
- Relationships maintained on fetch
- Updates propagate to related entities
- Deletes cascade appropriately
- Concurrent access handled safely

**Dependencies**
- Design and implement SwiftData schema

### ✅ Implement integration tests for Vision pipeline (M)

Test end-to-end feature print generation and classification with real images.

**Acceptance Criteria**
- Feature prints generated for test images
- Classifications returned with confidence
- Pipeline handles various image formats
- Error cases tested and handled

**Dependencies**
- Implement Vision classification request
- Implement Vision feature print extraction

### ✅ Create UI test suite for critical flows (L)

Implement XCUITest cases for library import, duplicate review, and memory discovery flows.

**Acceptance Criteria**
- LibraryImportFlow: permission → scan → grid
- DuplicateReviewFlow: list → compare → resolve
- MemoryDiscoveryFlow: open → view → navigate
- Tests run in CI without flakiness
- Accessibility identifiers in place

**Dependencies**
- Add first-launch onboarding
- Implement duplicate resolution actions
- Build memory detail slideshow

## ❓ Open Questions
- Should duplicate resolution allow user to select preferred photo or auto-select by quality score?
- What is the minimum photo library size before analysis features become valuable?
- Should forgotten photos exclude favorites and recently edited items?
- How to handle HEIC/RAW vs JPEG when computing feature prints?
- Should caption generation use Apple Intelligence APIs when available on macOS 15.1+?
- Should MenuBarExtra show notification badge for new memories or remain passive?