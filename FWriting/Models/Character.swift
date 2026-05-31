//
//  Character.swift
//  FWriting
//

import Foundation
import SwiftData

@Model
final class Character {
    var id: UUID
    var name: String
    var alias: String
    var gender: String
    var age: String
    var identity: String
    var personality: String
    var appearance: String
    var speakingStyle: String
    var relationships: String
    var constraints: String
    var notes: String
    var sortOrder: Int
    var createdAt: Date
    var modifiedAt: Date

    var project: Project?

    init(
        name: String = "",
        alias: String = "",
        gender: String = "",
        age: String = "",
        identity: String = "",
        personality: String = "",
        appearance: String = "",
        speakingStyle: String = "",
        relationships: String = "",
        constraints: String = "",
        notes: String = "",
        sortOrder: Int = 0,
        project: Project? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.alias = alias
        self.gender = gender
        self.age = age
        self.identity = identity
        self.personality = personality
        self.appearance = appearance
        self.speakingStyle = speakingStyle
        self.relationships = relationships
        self.constraints = constraints
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.modifiedAt = .now
        self.project = project
    }

    var displayName: String {
        let n = name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "未命名人物" : n
    }

    var searchableText: String {
        var parts: [String] = []
        for field in [name, alias, identity, personality, notes] {
            let t = field.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { parts.append(t) }
        }
        return parts.joined(separator: " ")
    }

    /// 用于 AI prompt 的紧凑描述
    func cardText(maxLength: Int = 600) -> String {
        var lines: [String] = []
        let nameText = name.trimmingCharacters(in: .whitespaces)
        guard !nameText.isEmpty else { return "" }

        lines.append("【\(nameText)】")
        if !alias.isEmpty { lines.append("别名：\(alias)") }
        if !gender.isEmpty { lines.append("性别：\(gender)") }
        if !age.isEmpty { lines.append("年龄：\(age)") }
        if !identity.isEmpty { lines.append("身份：\(identity)") }
        if !personality.isEmpty { lines.append("性格：\(personality)") }
        if !appearance.isEmpty { lines.append("外貌：\(appearance)") }
        if !speakingStyle.isEmpty { lines.append("说话风格：\(speakingStyle)") }
        if !relationships.isEmpty { lines.append("人物关系：\(relationships)") }
        if !constraints.isEmpty { lines.append("约束（不能写错）：\(constraints)") }
        if !notes.isEmpty { lines.append("备注：\(notes)") }

        return lines.joined(separator: "\n")
    }
}
