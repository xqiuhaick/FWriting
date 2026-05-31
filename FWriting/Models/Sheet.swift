//
//  Sheet.swift
//  FWriting
//

import Foundation
import SwiftData

enum SheetKind: String, CaseIterable, Identifiable {
    case text
    case material

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "正文"
        case .material: "资料"
        }
    }

    var icon: String {
        switch self {
        case .text: "doc.text"
        case .material: "paperclip"
        }
    }
}

@Model
final class Sheet {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool
    var isTrashed: Bool
    var wordGoal: Int?
    var sortOrder: Int
    var kindRawValue: String = SheetKind.text.rawValue
    var isGluedToPrevious: Bool = false
    var summary: String?
    var summaryChapterContext: String?
    var summaryUpdatedAt: Date?

    var project: Project?

    @Relationship(deleteRule: .nullify)
    var tags: [Tag]

    @Relationship(deleteRule: .cascade, inverse: \SheetSnapshot.sheet)
    var snapshots: [SheetSnapshot]

    init(
        title: String = "无标题",
        body: String = "",
        project: Project? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = .now
        self.modifiedAt = .now
        self.isFavorite = false
        self.isTrashed = false
        self.wordGoal = nil
        self.sortOrder = sortOrder
        self.kindRawValue = SheetKind.text.rawValue
        self.isGluedToPrevious = false
        self.summary = nil
        self.summaryChapterContext = nil
        self.summaryUpdatedAt = nil
        self.project = project
        self.tags = []
        self.snapshots = []
    }

    var kind: SheetKind {
        get { SheetKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }

    var displayTitle: String {
        if let heading = BlockParser.firstHeadingTitle(in: body, level: 1), !heading.isEmpty {
            return heading
        }
        return title.isEmpty ? "无标题" : title
    }

    var preview: String {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "空白文稿" }
        var lines = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let first = lines.first, case .heading1 = BlockParser.blockType(forLine: first) {
            lines.removeFirst()
        }
        guard !lines.isEmpty else { return "空白文稿" }
        return lines.prefix(2).joined(separator: "\n")
    }

    var wordCount: Int {
        WritingStatsService.wordCount(for: body)
    }

    var characterCount: Int {
        WritingStatsService.characterCount(for: body)
    }

    var readingMinutes: Int {
        WritingStatsService.readingMinutes(for: body)
    }
}
