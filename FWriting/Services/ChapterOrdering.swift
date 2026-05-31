//
//  ChapterOrdering.swift
//  FWriting
//

import Foundation

struct ChapterPosition {
    let index: Int
    let total: Int
    let previousTitle: String?
    let nextTitle: String?

    var compactLabel: String {
        "第 \(index) 章 / 共 \(total) 章"
    }

    var detailText: String {
        let previous = previousTitle ?? "无"
        let next = nextTitle ?? "无"
        return """
        当前章节：第 \(index) 章 / 共 \(total) 章
        当前标题：\(currentTitle)
        上一章：\(previous)
        下一章：\(next)
        """
    }

    let currentTitle: String

    init?(sheet: Sheet, ordered: [Sheet]) {
        guard sheet.kind == .text,
              sheet.project != nil,
              let index = ordered.firstIndex(where: { $0.id == sheet.id }) else {
            return nil
        }
        self.index = index + 1
        self.total = ordered.count
        self.currentTitle = sheet.displayTitle
        self.previousTitle = index > 0 ? ordered[index - 1].displayTitle : nil
        self.nextTitle = index + 1 < ordered.count ? ordered[index + 1].displayTitle : nil
    }
}

enum ChapterOrdering {
    static func orderedTextSheets(for sheet: Sheet, in allSheets: [Sheet]) -> [Sheet] {
        guard let project = sheet.project else { return [] }
        return allSheets
            .filter { candidate in
                candidate.kind == .text &&
                !candidate.isTrashed &&
                candidate.project?.id == project.id
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    static func position(for sheet: Sheet, in allSheets: [Sheet]) -> ChapterPosition? {
        let ordered = orderedTextSheets(for: sheet, in: allSheets)
        return ChapterPosition(sheet: sheet, ordered: ordered)
    }
}
