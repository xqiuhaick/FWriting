//
//  Project.swift
//  FWriting
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date
    var wordGoal: Int?
    var encryptionSalt: String?
    var encryptionPasswordHash: String?

    @Relationship(inverse: \Project.children)
    var parent: Project?

    @Relationship(deleteRule: .nullify)
    var children: [Project]

    @Relationship(deleteRule: .nullify, inverse: \Sheet.project)
    var sheets: [Sheet]

    init(name: String, sortOrder: Int = 0, parent: Project? = nil) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.wordGoal = nil
        self.encryptionSalt = nil
        self.encryptionPasswordHash = nil
        self.parent = parent
        self.children = []
        self.sheets = []
    }

    var isEncryptionEnabled: Bool {
        encryptionSalt != nil && encryptionPasswordHash != nil
    }

    var depth: Int {
        var level = 0
        var current = parent
        while current != nil {
            level += 1
            current = current?.parent
        }
        return level
    }
}
