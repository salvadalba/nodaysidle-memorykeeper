# MemoryKeeper

**A nostalgic photo library companion for macOS**

MemoryKeeper helps you rediscover and organize your photo memories with a warm, vintage-inspired interface. It surfaces forgotten photos, detects duplicates, and intelligently categorizes your library — all while keeping your data private with on-device processing.

---

## Features

### Rediscover Your Memories
MemoryKeeper surfaces photos you haven't viewed in years, presenting them as curated "memories" with beautiful Ken Burns transitions and cinematic vignettes. Like finding a box of old polaroids in the attic.

### Smart Duplicate Detection
Uses perceptual hashing through Apple's Vision framework to find visually similar photos — not just exact matches. Review duplicates side-by-side and keep only your favorites.

### Intelligent Categorization
On-device ML automatically organizes photos into meaningful categories: People, Pets, Nature, Travel, Food, and more. No cloud processing, no privacy concerns.

### AI-Powered Captions
Generate descriptive captions for your photos using on-device machine learning. Perfect for accessibility and search.

---

## Design Philosophy

MemoryKeeper embraces a **warm, nostalgic aesthetic** inspired by physical photo albums and polaroid cameras:

- **Typography**: SF Pro Rounded for friendly UI, New York serif for elegant titles
- **Colors**: Cream backgrounds, amber accents, sepia tones, and warm gold highlights
- **Animations**: Gentle fades, Ken Burns pan-and-zoom, floating sparkle particles
- **Empty States**: Hand-crafted vintage illustrations instead of generic icons

The interface feels like handling cherished photographs, not managing digital files.

---

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon or Intel Mac
- Photos library access

---

## Building

### Using Xcode

1. Open `MemoryKeeper.xcodeproj`
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

### Using Swift Package Manager

```bash
swift build --configuration release
swift test  # Run the test suite
```

---

## Architecture

```
MemoryKeeper/
├── Models/           # SwiftData models (Photo, Memory, Category, DuplicateGroup)
├── Services/         # Business logic (Vision analysis, duplicate detection, sync)
├── Views/            # SwiftUI views with warm nostalgic styling
└── Infrastructure/   # Error handling and logging
```

**Key Technologies:**
- Swift 6 with strict concurrency
- SwiftUI 6 + SwiftData
- PhotoKit for library access
- Vision framework (VNFeaturePrintObservation, VNClassifyImageRequest)
- On-device ML for categorization and captions

---

## User Guide

### First Launch

1. **Grant Photo Access**: When you first open MemoryKeeper, you'll be asked to grant access to your Photos library. Click "Grant Photo Access" and approve in the system dialog.

2. **Wait for Import**: MemoryKeeper will scan your photo library in the background. You'll see a loading indicator with progress. This only happens once.

3. **Explore Your Library**: Use the sidebar to navigate:
   - **All Photos**: Browse your complete photo library in a grid
   - **Memories**: View curated memory slideshows with Ken Burns transitions
   - **Duplicates**: Review and clean up similar photos
   - **Categories**: Photos organized by AI (People, Pets, Nature, etc.)

### Using the App

- **Photo Grid**: Click any photo to see it in the detail view. Use arrow keys for navigation.
- **Memories**: Click a memory card to start a cinematic slideshow. Press Space to pause, Escape to exit.
- **Duplicate Review**: Compare similar photos side-by-side. Choose which to keep.
- **Refresh**: Click the refresh button in the toolbar to scan for new photos.

### Troubleshooting

**"Photo library access not granted"**
- Open System Settings > Privacy & Security > Photos
- Find MemoryKeeper and enable access

**No photos appear after granting access**
- Click the refresh button in the toolbar
- Make sure you have photos in your Photos library

---

## Privacy

MemoryKeeper processes everything on-device:

- No cloud uploads
- No analytics or tracking
- Photos never leave your Mac
- Sandboxed with minimal permissions

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <em>Built with care for your memories</em>
</p>
