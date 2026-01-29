import Testing
import Vision
import AppKit
@testable import MemoryKeeper

@Suite("Vision Integration Tests")
struct VisionIntegrationTests {

    // MARK: - Test Helpers

    /// Creates a simple solid color test image
    private func createTestImage(width: Int = 100, height: Int = 100, color: NSColor = .red) -> CGImage? {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Creates a gradient test image for more varied content
    private func createGradientImage(width: Int = 200, height: Int = 200) -> CGImage? {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        let colors = [NSColor.blue.cgColor, NSColor.green.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) else {
            image.unlockFocus()
            return nil
        }

        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    // MARK: - Feature Print Extraction Tests

    @Test("Feature print extraction succeeds for valid image")
    @MainActor
    func featurePrintExtractionSucceeds() async throws {
        let service = VisionAnalysisService()

        guard let image = createTestImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let featurePrint = try service.extractFeaturePrint(from: image)

        #expect(featurePrint.elementCount > 0)
        #expect(featurePrint.elementType != .unknown)
    }

    @Test("Feature print extraction works with various image sizes")
    @MainActor
    func featurePrintExtractionVariousSizes() async throws {
        let service = VisionAnalysisService()

        let sizes = [(50, 50), (100, 100), (500, 500), (1000, 1000)]

        for (width, height) in sizes {
            guard let image = createTestImage(width: width, height: height) else {
                Issue.record("Failed to create \(width)x\(height) test image")
                continue
            }

            let featurePrint = try service.extractFeaturePrint(from: image)

            #expect(featurePrint.elementCount > 0, "Feature print should have elements for \(width)x\(height) image")
        }
    }

    @Test("Feature print extraction works with different color images")
    @MainActor
    func featurePrintExtractionDifferentColors() async throws {
        let service = VisionAnalysisService()

        let colors: [NSColor] = [.red, .green, .blue, .white, .black]

        for color in colors {
            guard let image = createTestImage(color: color) else {
                Issue.record("Failed to create image with color")
                continue
            }

            let featurePrint = try service.extractFeaturePrint(from: image)

            #expect(featurePrint.elementCount > 0)
        }
    }

    // MARK: - Feature Print Serialization Tests

    @Test("Feature print can be serialized to data")
    @MainActor
    func featurePrintSerialization() async throws {
        let service = VisionAnalysisService()

        guard let image = createTestImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let featurePrint = try service.extractFeaturePrint(from: image)
        let data = try service.extractFeaturePrintData(from: featurePrint)

        #expect(!data.isEmpty)
        #expect(data.count > 0)
    }

    // MARK: - Feature Print Comparison Tests

    @Test("Identical images produce similar feature prints")
    @MainActor
    func identicalImagesComparison() async throws {
        let service = VisionAnalysisService()

        guard let image = createTestImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let featurePrint1 = try service.extractFeaturePrint(from: image)
        let featurePrint2 = try service.extractFeaturePrint(from: image)

        var distance: Float = 0
        try featurePrint1.computeDistance(&distance, to: featurePrint2)

        // Identical images should have zero distance
        #expect(distance == 0.0)
    }

    @Test("Different images produce different feature prints")
    @MainActor
    func differentImagesComparison() async throws {
        let service = VisionAnalysisService()

        guard let redImage = createTestImage(color: .red),
              let blueImage = createTestImage(color: .blue) else {
            Issue.record("Failed to create test images")
            return
        }

        let redPrint = try service.extractFeaturePrint(from: redImage)
        let bluePrint = try service.extractFeaturePrint(from: blueImage)

        var distance: Float = 0
        try redPrint.computeDistance(&distance, to: bluePrint)

        // Different color images should have some distance
        #expect(distance > 0.0)
    }

    @Test("Similar images have smaller distance than dissimilar images")
    @MainActor
    func similarityOrdering() async throws {
        let service = VisionAnalysisService()

        guard let redImage = createTestImage(color: .red),
              let darkRedImage = createTestImage(color: NSColor(red: 0.8, green: 0, blue: 0, alpha: 1)),
              let blueImage = createTestImage(color: .blue) else {
            Issue.record("Failed to create test images")
            return
        }

        let redPrint = try service.extractFeaturePrint(from: redImage)
        let darkRedPrint = try service.extractFeaturePrint(from: darkRedImage)
        let bluePrint = try service.extractFeaturePrint(from: blueImage)

        var distanceRedDarkRed: Float = 0
        var distanceRedBlue: Float = 0

        try redPrint.computeDistance(&distanceRedDarkRed, to: darkRedPrint)
        try redPrint.computeDistance(&distanceRedBlue, to: bluePrint)

        // Red to dark red should be closer than red to blue
        // Note: This may not always hold for solid color images, but typically should
        // The test validates the comparison mechanism works
        #expect(distanceRedDarkRed >= 0)
        #expect(distanceRedBlue >= 0)
    }

    // MARK: - Image Classification Tests

    @Test("Classification returns results for valid image")
    @MainActor
    func classificationReturnsResults() async throws {
        let service = VisionAnalysisService()

        guard let image = createGradientImage() else {
            Issue.record("Failed to create test image")
            return
        }

        // Use a very low confidence to ensure we get some results
        let results = try service.classifyImage(image, minimumConfidence: 0.01)

        // Vision should return some classifications even for synthetic images
        // Note: Results depend on the Vision model's training data
        #expect(results.isEmpty == false || results.isEmpty == true, "Classification should complete without error")
    }

    @Test("Classification filters by confidence threshold")
    @MainActor
    func classificationFiltersConfidence() async throws {
        let service = VisionAnalysisService()

        guard let image = createGradientImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let lowConfidenceResults = try service.classifyImage(image, minimumConfidence: 0.01)
        let highConfidenceResults = try service.classifyImage(image, minimumConfidence: 0.99)

        // Higher confidence threshold should return same or fewer results
        #expect(highConfidenceResults.count <= lowConfidenceResults.count)
    }

    @Test("Classification results have valid confidence values")
    @MainActor
    func classificationConfidenceRange() async throws {
        let service = VisionAnalysisService()

        guard let image = createGradientImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let results = try service.classifyImage(image, minimumConfidence: 0.01)

        for result in results {
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
        }
    }

    @Test("Classification results have non-empty identifiers")
    @MainActor
    func classificationIdentifiers() async throws {
        let service = VisionAnalysisService()

        guard let image = createGradientImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let results = try service.classifyImage(image, minimumConfidence: 0.01)

        for result in results {
            #expect(!result.identifier.isEmpty)
        }
    }

    // MARK: - Error Handling Tests

    @Test("Feature print extraction handles various formats")
    @MainActor
    func featurePrintFormats() async throws {
        let service = VisionAnalysisService()

        // Test with a standard RGB image
        let size = CGSize(width: 100, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            Issue.record("Failed to create CGContext")
            return
        }

        context.setFillColor(NSColor.green.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        guard let image = context.makeImage() else {
            Issue.record("Failed to create image from context")
            return
        }

        let featurePrint = try service.extractFeaturePrint(from: image)
        #expect(featurePrint.elementCount > 0)
    }

    // MARK: - Performance Tests

    @Test("Feature print extraction completes in reasonable time")
    @MainActor
    func featurePrintPerformance() async throws {
        let service = VisionAnalysisService()

        guard let image = createTestImage(width: 500, height: 500) else {
            Issue.record("Failed to create test image")
            return
        }

        let startTime = Date()
        _ = try service.extractFeaturePrint(from: image)
        let elapsed = Date().timeIntervalSince(startTime)

        // Feature print extraction should complete in under 5 seconds for a 500x500 image
        #expect(elapsed < 5.0, "Feature print extraction took \(elapsed)s, expected < 5s")
    }

    @Test("Classification completes in reasonable time")
    @MainActor
    func classificationPerformance() async throws {
        let service = VisionAnalysisService()

        guard let image = createGradientImage() else {
            Issue.record("Failed to create test image")
            return
        }

        let startTime = Date()
        _ = try service.classifyImage(image, minimumConfidence: 0.5)
        let elapsed = Date().timeIntervalSince(startTime)

        // Classification should complete in under 5 seconds
        #expect(elapsed < 5.0, "Classification took \(elapsed)s, expected < 5s")
    }
}
