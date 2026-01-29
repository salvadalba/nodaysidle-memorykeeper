import Testing
import SwiftData
@testable import MemoryKeeper

@Suite("Categorization Tests")
struct CategorizationTests {

    @Test("Vision labels map to user-friendly categories")
    func labelMapping() {
        // Test direct mappings
        #expect(CategorizationService.categoryMapping["dog"] == "Pets")
        #expect(CategorizationService.categoryMapping["cat"] == "Pets")
        #expect(CategorizationService.categoryMapping["mountain"] == "Nature")
        #expect(CategorizationService.categoryMapping["food"] == "Food")
        #expect(CategorizationService.categoryMapping["person"] == "People")
    }

    @Test("Category mapping covers common labels")
    func coverageTest() {
        let commonLabels = [
            "person", "dog", "cat", "car", "tree", "beach",
            "food", "building", "mountain", "flower"
        ]

        for label in commonLabels {
            let category = CategorizationService.categoryMapping[label]
            #expect(category != nil, "Missing mapping for: \(label)")
        }
    }

    @Test("Static category mapping has expected count")
    func mappingCount() {
        // Ensure we have a reasonable number of mappings
        #expect(CategorizationService.categoryMapping.count > 50)
    }

    @Test("All mappings have valid category values")
    func validCategories() {
        let validCategories = ["People", "Pets", "Animals", "Nature", "Food", "Travel",
                               "Activities", "Events", "Home", "Documents", "Screenshots",
                               "Art", "Vehicles"]

        for (_, category) in CategorizationService.categoryMapping {
            #expect(validCategories.contains(category), "Invalid category: \(category)")
        }
    }
}
