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
