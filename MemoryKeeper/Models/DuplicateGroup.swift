import Foundation
import SwiftData

@Model
final class DuplicateGroup {
    var createdDate: Date = Date()
    var isResolved: Bool = false
    var resolvedDate: Date?

    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []

    var similarityScores: [String: Double] = [:]

    init() {}

    var representativePhoto: Photo? {
        photos.first
    }

    var averageSimilarity: Double {
        guard !similarityScores.isEmpty else { return 0 }
        return similarityScores.values.reduce(0, +) / Double(similarityScores.count)
    }
}
