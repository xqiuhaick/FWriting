//
//  Tag.swift
//  FWriting
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var sortOrder: Int

    @Relationship(inverse: \Sheet.tags)
    var sheets: [Sheet]

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.sheets = []
    }

    var displayName: String {
        name.hasPrefix("#") ? name : "#\(name)"
    }
}
