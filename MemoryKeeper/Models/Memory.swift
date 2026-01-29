import Foundation
import SwiftData

enum MemoryType: String, Codable, Sendable {
    case onThisDay
    case forgotten
    case collection
}

@Model
final class Memory {
    var createdDate: Date = Date()
    var startDate: Date?
    var endDate: Date?
    var type: MemoryType = MemoryType.onThisDay
    var wasPresented: Bool = false
    var presentedDate: Date?

    @Relationship(deleteRule: .nullify)
    var photos: [Photo] = []

    @Relationship(deleteRule: .cascade, inverse: \Caption.memory)
    var caption: Caption?

    init(type: MemoryType = .onThisDay) {
        self.type = type
    }
}
