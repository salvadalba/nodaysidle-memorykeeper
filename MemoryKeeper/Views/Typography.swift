import SwiftUI

/// Typography system for MemoryKeeper following the design spec
/// Uses SF Pro family with specific weights and sizes for different contexts
enum Typography {

    // MARK: - Hero Titles (SF Pro Rounded Semibold 34-40pt)

    static var heroLarge: Font {
        .system(size: 40, weight: .semibold, design: .rounded)
    }

    static var heroMedium: Font {
        .system(size: 36, weight: .semibold, design: .rounded)
    }

    static var heroSmall: Font {
        .system(size: 34, weight: .semibold, design: .rounded)
    }

    // MARK: - Section Headers (SF Pro Display Medium 20-28pt)

    static var sectionLarge: Font {
        .system(size: 28, weight: .medium)
    }

    static var sectionMedium: Font {
        .system(size: 24, weight: .medium)
    }

    static var sectionSmall: Font {
        .system(size: 20, weight: .medium)
    }

    // MARK: - Body Text (SF Pro Text Regular 13-15pt)

    static var bodyLarge: Font {
        .system(size: 15, weight: .regular)
    }

    static var bodyMedium: Font {
        .system(size: 14, weight: .regular)
    }

    static var bodySmall: Font {
        .system(size: 13, weight: .regular)
    }

    // MARK: - Captions (New York Regular/Italic 14-16pt)
    // Using .serif design which maps to New York on Apple platforms

    static var captionLarge: Font {
        .system(size: 16, design: .serif)
    }

    static var captionMedium: Font {
        .system(size: 15, design: .serif)
    }

    static var captionSmall: Font {
        .system(size: 14, design: .serif)
    }

    static var captionItalic: Font {
        .system(size: 15, design: .serif).italic()
    }

    static var captionLargeItalic: Font {
        .system(size: 16, design: .serif).italic()
    }

    // MARK: - Tags (SF Pro Rounded Medium 11-12pt)

    static var tagLarge: Font {
        .system(size: 12, weight: .medium, design: .rounded)
    }

    static var tagSmall: Font {
        .system(size: 11, weight: .medium, design: .rounded)
    }

    // MARK: - Metadata (SF Pro Text 11-12pt)

    static var metadataLarge: Font {
        .system(size: 12, weight: .regular)
    }

    static var metadataSmall: Font {
        .system(size: 11, weight: .regular)
    }

    // MARK: - Caption Tracking
    // +2% tracking for captions = approximately 0.3pt at 15pt size

    static let captionTracking: CGFloat = 0.3
}

// MARK: - View Extensions for Typography

extension View {
    func heroTitle() -> some View {
        self.font(Typography.heroMedium)
    }

    func sectionHeader() -> some View {
        self.font(Typography.sectionMedium)
    }

    func bodyText() -> some View {
        self.font(Typography.bodyMedium)
    }

    func captionText() -> some View {
        self.font(Typography.captionMedium)
            .tracking(Typography.captionTracking)
    }

    func captionItalicText() -> some View {
        self.font(Typography.captionItalic)
            .tracking(Typography.captionTracking)
    }

    func tagStyle() -> some View {
        self.font(Typography.tagSmall)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }

    func metadataStyle() -> some View {
        self.font(Typography.metadataSmall)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Warm Nostalgic Color Palette

extension Color {
    // Primary warm background tones
    static let memoryWarm = Color(red: 0.98, green: 0.95, blue: 0.90)
    static let memoryWarmLight = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let memoryWarmDark = Color(red: 0.95, green: 0.90, blue: 0.82)

    // Accent colors with nostalgic feel
    static let memoryAccent = Color(red: 0.85, green: 0.65, blue: 0.45)
    static let memoryAccentLight = Color(red: 0.92, green: 0.78, blue: 0.62)
    static let memoryAccentDark = Color(red: 0.72, green: 0.52, blue: 0.35)

    // Semantic colors
    static let memoryGold = Color(red: 0.88, green: 0.75, blue: 0.45)
    static let memorySepia = Color(red: 0.45, green: 0.35, blue: 0.25)
    static let memoryFaded = Color(red: 0.55, green: 0.50, blue: 0.45) // Darker for better contrast

    // Shadow colors
    static let memoryShadow = Color.black.opacity(0.08)
    static let memoryShadowDeep = Color.black.opacity(0.15)

    // Card backgrounds
    static let memoryCardBackground = Color(red: 1.0, green: 0.98, blue: 0.95)

    // Text colors - READABLE on warm backgrounds
    static let memoryTextLight = Color.white.opacity(0.95)
    static let memoryTextDark = Color(red: 0.15, green: 0.12, blue: 0.10) // Very dark brown
    static let memoryTextPrimary = Color(red: 0.20, green: 0.18, blue: 0.15) // Primary text
    static let memoryTextSecondary = Color(red: 0.40, green: 0.35, blue: 0.30) // Secondary text
}

// MARK: - Animation Extensions

extension Animation {
    /// Spring animation for interactive elements
    static var memorySpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

    /// Quick spring for snappy feedback
    static var memorySpringQuick: Animation {
        .spring(response: 0.25, dampingFraction: 0.7)
    }

    /// Gentle spring for larger transitions
    static var memorySpringGentle: Animation {
        .spring(response: 0.6, dampingFraction: 0.85)
    }

    /// Ease out for fade/reveal animations
    static var memoryEaseOut: Animation {
        .easeOut(duration: 0.3)
    }

    /// Subtle ease for font weight changes
    static var fontWeight: Animation {
        .easeOut(duration: 0.25)
    }

    /// Slideshow transition
    static var slideshowTransition: Animation {
        .easeInOut(duration: 0.8)
    }

    /// Memory card hover animation
    static var cardHover: Animation {
        .spring(response: 0.35, dampingFraction: 0.75)
    }
}

// MARK: - Font Weight Animation Modifier

/// Animates font weight from light to regular when view appears
/// Per spec: "Use variable font weight axis to animate text from Light to Regular when photos appear"
struct FontWeightAnimationModifier: ViewModifier {
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .fontWeight(hasAppeared ? .regular : .light)
            .animation(reduceMotion ? nil : .fontWeight, value: hasAppeared)
            .onAppear {
                hasAppeared = true
            }
    }
}

extension View {
    /// Applies font weight animation from light to regular on appear
    func animateFontWeight() -> some View {
        modifier(FontWeightAnimationModifier())
    }
}

// MARK: - Phase Animator for Load Animations

/// Phases for photo thumbnail load animation
enum PhotoLoadPhase: CaseIterable {
    case initial
    case loading
    case loaded

    var opacity: Double {
        switch self {
        case .initial: return 0
        case .loading: return 0.5
        case .loaded: return 1
        }
    }

    var scale: Double {
        switch self {
        case .initial: return 0.95
        case .loading: return 0.98
        case .loaded: return 1
        }
    }
}

/// Phases for memory card entrance animation
enum MemoryCardPhase: CaseIterable {
    case hidden
    case appearing
    case visible

    var offset: CGFloat {
        switch self {
        case .hidden: return 20
        case .appearing: return 5
        case .visible: return 0
        }
    }

    var opacity: Double {
        switch self {
        case .hidden: return 0
        case .appearing: return 0.7
        case .visible: return 1
        }
    }

    var blur: CGFloat {
        switch self {
        case .hidden: return 4
        case .appearing: return 1
        case .visible: return 0
        }
    }
}

// MARK: - Matched Geometry Effect Namespaces

/// Namespace keys for matched geometry transitions
enum AnimationNamespace {
    static let photoGrid = "photoGrid"
    static let memoryCard = "memoryCard"
    static let duplicateComparison = "duplicateComparison"
}

// MARK: - Material Background Helpers

extension View {
    /// Applies ultra thin material background with rounded corners
    func ultraThinMaterialBackground(cornerRadius: CGFloat = 12) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Applies regular material background with rounded corners
    func regularMaterialBackground(cornerRadius: CGFloat = 12) -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Applies thick material background with rounded corners
    func thickMaterialBackground(cornerRadius: CGFloat = 12) -> some View {
        self.background(.thickMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Warm card background style
    func memoryCardStyle() -> some View {
        self
            .background(Color.memoryCardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .memoryShadow, radius: 8, y: 4)
    }
}

// MARK: - Accessibility Helpers

extension View {
    /// Adds comprehensive accessibility for photo elements
    func photoAccessibility(
        date: Date?,
        categories: [String],
        isFavorite: Bool,
        isDuplicate: Bool = false
    ) -> some View {
        let dateString: String
        if let date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            dateString = "taken on \(formatter.string(from: date))"
        } else {
            dateString = "date unknown"
        }

        let categoryString = categories.isEmpty
            ? ""
            : ", categorized as \(categories.joined(separator: ", "))"

        let favoriteString = isFavorite ? ", marked as favorite" : ""
        let duplicateString = isDuplicate ? ", has duplicates" : ""

        return self
            .accessibilityLabel("Photo \(dateString)\(categoryString)\(favoriteString)\(duplicateString)")
            .accessibilityHint("Double tap to view full size")
            .accessibilityAddTraits(.isImage)
    }

    /// Adds accessibility for memory cards
    func memoryAccessibility(
        type: String,
        photoCount: Int,
        dateRange: String?
    ) -> some View {
        let rangeString = dateRange.map { " from \($0)" } ?? ""
        return self
            .accessibilityLabel("\(type) memory with \(photoCount) photos\(rangeString)")
            .accessibilityHint("Double tap to view memory slideshow")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Keyboard Navigation Helpers

extension View {
    /// Adds standard keyboard navigation for grids
    func gridKeyboardNavigation(
        currentIndex: Binding<Int>,
        itemCount: Int,
        columnsPerRow: Int
    ) -> some View {
        self
            .onKeyPress(.leftArrow) {
                if currentIndex.wrappedValue > 0 {
                    currentIndex.wrappedValue -= 1
                }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                if currentIndex.wrappedValue < itemCount - 1 {
                    currentIndex.wrappedValue += 1
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                let newIndex = currentIndex.wrappedValue - columnsPerRow
                if newIndex >= 0 {
                    currentIndex.wrappedValue = newIndex
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                let newIndex = currentIndex.wrappedValue + columnsPerRow
                if newIndex < itemCount {
                    currentIndex.wrappedValue = newIndex
                }
                return .handled
            }
    }
}

#Preview("Typography Samples") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Hero Title Large")
            .font(Typography.heroLarge)

        Text("Section Header")
            .font(Typography.sectionMedium)

        Text("Body text for descriptions and content")
            .font(Typography.bodyMedium)

        Text("Caption with italic styling for memories")
            .font(Typography.captionItalic)
            .tracking(Typography.captionTracking)

        Text("Tag Label")
            .tagStyle()

        Text("Metadata: Jan 15, 2024")
            .metadataStyle()
    }
    .padding()
    .frame(width: 400)
}

#Preview("Color Palette") {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            colorSwatch(.memoryWarm, "Warm")
            colorSwatch(.memoryWarmLight, "Warm Light")
            colorSwatch(.memoryWarmDark, "Warm Dark")
        }
        HStack(spacing: 12) {
            colorSwatch(.memoryAccent, "Accent")
            colorSwatch(.memoryGold, "Gold")
            colorSwatch(.memorySepia, "Sepia")
        }
    }
    .padding()
}

@ViewBuilder
private func colorSwatch(_ color: Color, _ name: String) -> some View {
    VStack {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 60, height: 60)
        Text(name)
            .font(.caption)
    }
}
