# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build with Xcode (preferred - creates .app bundle)
xcodebuild -project MemoryKeeper.xcodeproj -scheme MemoryKeeper -configuration Release

# Build with SPM
swift build --configuration release

# Run tests
swift test

# Install to Applications (after Release build)
cp -r build/Build/Products/Release/MemoryKeeper.app /Applications/
```

## Architecture

### Data Flow
```
PHPhotoLibrary (source of truth for photos)
       ↓
PhotoLibraryService (actor, fetches PHAssets)
       ↓
PhotoSyncService (syncs to SwiftData)
       ↓
SwiftData Models (Photo, Category, DuplicateGroup, Memory)
       ↓
SwiftUI Views (@Query for reactive updates)
```

### Key Services
- **PhotoLibraryService** (`actor`): PhotoKit integration, authorization, change observation
- **VisionAnalysisService**: Feature print extraction and image classification via Vision framework
- **DuplicateDetectionService**: Compares VNFeaturePrintObservation pairs, groups similar photos
- **CategorizationService**: Assigns categories based on VNClassifyImageRequest results
- **MemorySurfacingService**: Surfaces forgotten photos based on date and viewing history

### SwiftData Models
All models use `PHAsset.localIdentifier` as the bridge to PhotoKit:
- **Photo**: Core model with `@Attribute(.unique) var assetIdentifier: String`
- **Category**: Many-to-many with Photo via `@Relationship`
- **DuplicateGroup**: Groups similar photos, `isResolved` tracks user decisions
- **Memory**: Curated photo collections for slideshow display

## Critical Patterns

### PHImageManager Callbacks
PHImageManager.requestImage() may call its completion handler multiple times (degraded thumbnail first, then full quality). Always use AsyncStream pattern:

```swift
private func loadImageStream(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
    AsyncStream { continuation in
        var hasFinished = false
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, ...) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image = image { continuation.yield(image) }
            if !isDegraded {
                if !hasFinished { hasFinished = true; continuation.finish() }
            }
        }
    }
}
```

### SwiftData Relationships
Must insert model into context BEFORE modifying relationships:
```swift
let group = DuplicateGroup()
context.insert(group)  // INSERT FIRST
group.photos.append(photo)  // THEN modify relationships
```

### SwiftUI + SwiftData Race Conditions
When deleting items that are being displayed via `@Query`, mark as resolved/remove from query results FIRST, then perform async deletion:
```swift
// Mark resolved so @Query stops showing this item immediately
group.isResolved = true
try? modelContext.save()

// Then delete in background
Task { await PHPhotoLibrary.shared().performChanges { ... } }
```

## Design System

Typography and colors are defined in `Views/Typography.swift`:
- Use `Typography.heroSmall`, `Typography.bodyMedium`, etc.
- Use `Color.memoryWarm`, `Color.memoryTextPrimary`, etc.
- Warm, nostalgic theme - forced light mode via `.preferredColorScheme(.light)`

## Concurrency

- Swift 6 strict concurrency enabled
- Services use `@MainActor` or `actor` isolation
- `@unchecked Sendable` used for PhotoKit observers with NSLock protection
- `nonisolated` for synchronous Vision operations that don't touch actor state

## Entitlements Required
- `com.apple.security.personal-information.photos-library` - Photo library access
- App is sandboxed; photos never leave the device
