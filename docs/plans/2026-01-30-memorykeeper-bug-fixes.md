# MemoryKeeper Bug Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all identified bugs causing crashes and non-functional features in MemoryKeeper

**Architecture:** The bugs fall into three categories:
1. **Race conditions** between PHPhotoLibrary.changes and SwiftUI view updates causing crashes
2. **Continuation misuse** in PHImageManager callbacks (can call completion multiple times, but `withCheckedContinuation` only allows one resume)
3. **Button/UI bugs** where the "Grant Photo Access" button doesn't work and shows empty state despite photos being available

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PhotoKit, Vision framework

---

## Bug Analysis Summary

### Bug 1: PHPhotoLibrary.changes Crash (CRITICAL)
**Symptom:** App crashes on `com.apple.PHPhotoLibrary.changes` thread with EXC_BREAKPOINT
**Root Cause:** SwiftUI AttributeGraph is trying to update views while data is being modified by background photo library changes. The crash occurs because:
- PHPhotoLibrary change observers fire on background threads
- These trigger SwiftData updates which invalidate SwiftUI @Query results
- SwiftUI tries to re-render but data is in inconsistent state

### Bug 2: "Grant Photo Access" Button Doesn't Work
**Symptom:** User sees "Your Photo Library Awaits" screen with "Grant Photo Access" button even when photos are already granted and visible in sidebar
**Root Cause:**
- PhotoGridView shows `emptyState` when `photos.isEmpty`
- But `photos` array can be empty temporarily while loading
- The `openPhotoPrivacySettings()` opens system settings, but doesn't trigger a refresh

### Bug 3: Continuation Called Multiple Times (Potential Crash)
**Symptom:** Potential hangs or crashes in thumbnail loading
**Root Cause:** `withCheckedContinuation` in MemoryCard and MemorySlideshowView can only be resumed ONCE, but PHImageManager may call its completion handler multiple times (degraded first, then high quality)

---

## Task 1: Fix PHImageManager Continuation Bugs in MemoryViews.swift

**Files:**
- Modify: `MemoryKeeper/Views/MemoryViews.swift:184-206` (MemoryCard.loadThumbnail)
- Modify: `MemoryKeeper/Views/MemoryViews.swift:806-836` (MemorySlideshowView.loadCurrentImage)

**Step 1: Identify the problematic code in MemoryCard**

The current code at lines 193-206:
```swift
return await withCheckedContinuation { continuation in
    PHImageManager.default().requestImage(
        for: asset,
        targetSize: CGSize(width: size.width * 2, height: size.height * 2),
        contentMode: .aspectFill,
        options: options
    ) { image, info in
        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
        if !isDegraded {
            continuation.resume(returning: image)  // BUG: May never be called if only degraded images come
        }
    }
}
```

This has TWO bugs:
1. If only degraded images come, continuation is never resumed (hang)
2. If called multiple times with non-degraded, crashes

**Step 2: Replace MemoryCard.loadThumbnail with AsyncStream pattern**

Replace lines 184-206 with:
```swift
private func loadThumbnail(for identifier: String, size: CGSize) async -> NSImage? {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
    guard let asset = fetchResult.firstObject else { return nil }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    var resultImage: NSImage?
    for await image in loadImageStream(asset: asset, targetSize: CGSize(width: size.width * 2, height: size.height * 2), options: options) {
        resultImage = image
    }
    return resultImage
}

private func loadImageStream(asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
    AsyncStream { continuation in
        var hasFinished = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let hasError = info?[PHImageErrorKey] != nil

            if let image = image {
                continuation.yield(image)
            }

            if !isDegraded || isCancelled || hasError {
                if !hasFinished {
                    hasFinished = true
                    continuation.finish()
                }
            }
        }
    }
}
```

**Step 3: Replace MemorySlideshowView.loadCurrentImage with AsyncStream pattern**

Replace lines 806-836 with:
```swift
private func loadCurrentImage() async {
    guard let photo = memory.photos[safe: currentIndex] else { return }
    isLoadingImage = true

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
    guard let asset = fetchResult.firstObject else {
        isLoadingImage = false
        return
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    for await image in loadSlideshowImageStream(asset: asset, options: options) {
        currentThumbnail = image
    }

    isLoadingImage = false
}

private func loadSlideshowImageStream(asset: PHAsset, options: PHImageRequestOptions) -> AsyncStream<NSImage> {
    AsyncStream { continuation in
        var hasFinished = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1920, height: 1080),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let hasError = info?[PHImageErrorKey] != nil

            if let image = image {
                continuation.yield(image)
            }

            if !isDegraded || isCancelled || hasError {
                if !hasFinished {
                    hasFinished = true
                    continuation.finish()
                }
            }
        }
    }
}
```

**Step 4: Build and verify no compiler errors**

Run: `swift build 2>&1 | head -50`
Expected: Build succeeds or only warnings

**Step 5: Commit**

```bash
git add MemoryKeeper/Views/MemoryViews.swift
git commit -m "$(cat <<'EOF'
fix: Replace withCheckedContinuation with AsyncStream in MemoryViews

PHImageManager.requestImage() can call its completion handler multiple
times (degraded thumbnail first, then full quality). Using
withCheckedContinuation is unsafe because it can only be resumed once.

Replaced with AsyncStream pattern that properly handles multiple callbacks
and finishes when the final (non-degraded) image arrives.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Fix Empty State Showing Despite Photos Granted

**Files:**
- Modify: `MemoryKeeper/Views/PhotoGridView.swift:33-41`
- Modify: `MemoryKeeper/Views/PhotoGridView.swift:95-140` (emptyState)

**Step 1: Understand the bug**

The current code shows empty state when `photos.isEmpty`:
```swift
var body: some View {
    Group {
        if photos.isEmpty {
            emptyState  // Shows "Your Photo Library Awaits" with Grant Access button
        } else {
            photoGrid
        }
    }
}
```

But `photos` can be empty during initial load even if permission is granted. The empty state incorrectly assumes no permission.

**Step 2: Add authorization check to PhotoGridView**

Add state for authorization at line 15:
```swift
@State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
```

**Step 3: Update body to check both photos AND authorization**

Replace lines 33-41:
```swift
var body: some View {
    Group {
        if photos.isEmpty {
            // Only show permission-related empty state if actually not authorized
            if authorizationStatus == .denied || authorizationStatus == .restricted {
                permissionDeniedState
            } else if authorizationStatus == .notDetermined {
                requestPermissionState
            } else {
                // Authorized but no photos yet - show loading or truly empty library state
                emptyLibraryState
            }
        } else {
            photoGrid
        }
    }
    .onAppear {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
}
```

**Step 4: Split emptyState into three distinct views**

Replace lines 95-140 with three separate views:
```swift
private var permissionDeniedState: some View {
    VStack(spacing: 40) {
        VintageCameraIllustration()
            .frame(width: 240, height: 200)

        VStack(spacing: 16) {
            Text("Photo Access Required")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            Text("MemoryKeeper needs access to your photos. Please grant access in System Settings.")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }

        Button {
            openPhotoPrivacySettings()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gear")
                Text("Open System Settings")
            }
            .font(Typography.bodyMedium)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.memoryAccent)

        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.caption)
            Text("Your photos stay on your device. Always.")
                .font(Typography.metadataSmall)
        }
        .foregroundStyle(Color.memoryFaded)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.memoryWarmLight)
}

private var requestPermissionState: some View {
    VStack(spacing: 40) {
        VintageCameraIllustration()
            .frame(width: 240, height: 200)

        VStack(spacing: 16) {
            Text("Your Photo Library Awaits")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            Text("Grant access to your photos and let us help you rediscover your cherished memories")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }

        Button {
            requestPhotoAccess()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                Text("Grant Photo Access")
            }
            .font(Typography.bodyMedium)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.memoryAccent)

        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.caption)
            Text("Your photos stay on your device. Always.")
                .font(Typography.metadataSmall)
        }
        .foregroundStyle(Color.memoryFaded)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.memoryWarmLight)
}

private var emptyLibraryState: some View {
    VStack(spacing: 40) {
        VintageCameraIllustration()
            .frame(width: 240, height: 200)

        VStack(spacing: 16) {
            Text("No Photos Yet")
                .font(Typography.heroSmall)
                .foregroundStyle(Color.memoryTextPrimary)

            Text("Your photo library appears to be empty. Add some photos to get started!")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.memoryTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.memoryWarmLight)
}
```

**Step 5: Add requestPhotoAccess function**

Add after `openPhotoPrivacySettings()`:
```swift
private func requestPhotoAccess() {
    Task {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
        }
    }
}
```

**Step 6: Build and verify**

Run: `swift build 2>&1 | head -50`
Expected: Build succeeds

**Step 7: Commit**

```bash
git add MemoryKeeper/Views/PhotoGridView.swift
git commit -m "$(cat <<'EOF'
fix: Properly handle authorization states in PhotoGridView empty state

Previously showed "Grant Photo Access" even when photos were authorized
but just loading. Now properly distinguishes between:
- Not determined: Show request permission button
- Denied/Restricted: Show open settings button
- Authorized but empty: Show "No Photos Yet" message

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Fix PHPhotoLibrary.changes Race Condition Crashes

**Files:**
- Modify: `MemoryKeeper/Services/PhotoLibraryService.swift:155-172` (PhotoLibraryChangeObserver)
- Modify: `MemoryKeeper/ContentView.swift` (add debouncing and safe data access)

**Step 1: Add thread safety to PhotoLibraryChangeObserver**

The PhotoLibraryChangeObserver at lines 155-172 is missing NSLock protection. Replace with:
```swift
private final class PhotoLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let lock = NSLock()
    private var _onChange: ((PHChange) -> Void)?

    init(onChange: @escaping (PHChange) -> Void) {
        self._onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        _onChange = nil
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        lock.lock()
        let callback = _onChange
        lock.unlock()

        // Dispatch to main thread to avoid race conditions with SwiftUI
        DispatchQueue.main.async {
            callback?(changeInstance)
        }
    }
}
```

**Step 2: Build and verify**

Run: `swift build 2>&1 | head -50`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add MemoryKeeper/Services/PhotoLibraryService.swift
git commit -m "$(cat <<'EOF'
fix: Add thread safety to PhotoLibraryChangeObserver

PHPhotoLibrary.photoLibraryDidChange() fires on background threads.
Added NSLock protection and dispatch to main thread to prevent race
conditions with SwiftUI view updates.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Prevent SwiftUI Updates During Data Mutations

**Files:**
- Modify: `MemoryKeeper/Views/DuplicateReviewView.swift:237-277` (already fixed, verify)

**Step 1: Verify DuplicateReviewView fix is still in place**

Read the current `deleteUnselectedPhotos()` function and verify it:
1. Marks group as resolved FIRST (removes from @Query)
2. Then deletes photos in background

The fix should already be:
```swift
private func deleteUnselectedPhotos() async {
    // Get asset identifiers to delete BEFORE modifying anything
    let toDelete = group.photos
        .filter { !selectedPhotos.contains($0.assetIdentifier) }
        .map { $0.assetIdentifier }

    // Mark group as resolved FIRST so it disappears from list immediately
    await MainActor.run {
        group.isResolved = true
        group.resolvedDate = Date()
        try? modelContext.save()
    }

    // ... delete in background
}
```

**Step 2: If not already fixed, apply the fix**

If the function doesn't follow this pattern, update it.

**Step 3: No commit needed if already fixed**

---

## Task 5: Build, Test, and Install

**Step 1: Clean build**

Run: `rm -rf build && xcodebuild -project MemoryKeeper.xcodeproj -scheme MemoryKeeper -configuration Release -derivedDataPath build`

Expected: BUILD SUCCEEDED

**Step 2: Install to Applications**

Run: `cp -r build/Build/Products/Release/MemoryKeeper.app /Applications/`

Expected: App copied successfully

**Step 3: Open and test**

Run: `open /Applications/MemoryKeeper.app`

Test scenarios:
1. Fresh launch - should not show "Grant Photo Access" if already authorized
2. Navigate to Duplicates - select photos and delete - should not crash
3. Navigate to Memories - view slideshow - should not crash
4. General usage - no crashes on PHPhotoLibrary.changes

**Step 4: Final commit with version bump (optional)**

---

## Summary of Fixes

| Bug | File | Fix |
|-----|------|-----|
| Continuation crash in MemoryCard | MemoryViews.swift | Replace `withCheckedContinuation` with `AsyncStream` |
| Continuation crash in Slideshow | MemoryViews.swift | Replace `withCheckedContinuation` with `AsyncStream` |
| Wrong empty state | PhotoGridView.swift | Check authorization status, show appropriate state |
| Grant Access button not working | PhotoGridView.swift | Add `requestPhotoAccess()` function |
| PHPhotoLibrary.changes crash | PhotoLibraryService.swift | Add NSLock + main thread dispatch |

Total: 5 bugs fixed across 3 files
