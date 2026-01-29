import Foundation
import SwiftData

@Model
final class Photo {
    @Attribute(.unique) var assetIdentifier: String
    var creationDate: Date?
    var modificationDate: Date?
    var latitude: Double?
    var longitude: Double?
    var featurePrintHash: Data?
    var lastViewedDate: Date?
    var isFavorite: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Category.photos)
    var categories: [Category] = []

    @Relationship(deleteRule: .nullify, inverse: \DuplicateGroup.photos)
    var duplicateGroup: DuplicateGroup?

    @Relationship(deleteRule: .nullify, inverse: \Memory.photos)
    var memories: [Memory] = []

    var categoryConfidences: [String: Double] = [:]

    init(assetIdentifier: String) {
        self.assetIdentifier = assetIdentifier
    }
}
