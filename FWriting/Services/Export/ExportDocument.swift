//
//  ExportDocument.swift
//  FWriting
//

import Foundation

enum ExportScope: String, CaseIterable, Identifiable {
    case currentSheet
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .currentSheet: "当前文稿"
        case .project: "整个项目"
        }
    }
}

struct ExportOptions: Equatable {
    var scope: ExportScope = .currentSheet
    var style: ExportStyle = .modern
    var includeTableOfContents: Bool = true
    var includeComments: Bool = false
    var includeTitlePage: Bool = true
    var chapterPerSheet: Bool = true
    var author: String = ""
    var bodyFontSize: CGFloat = 17
    var maxWidth: CGFloat = 720

    static let `default` = ExportOptions()
}

struct ExportTOCEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int
    let anchor: String
}

struct ExportChapter: Identifiable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let sortOrder: Int
    let isGluedToPrevious: Bool
}

struct ExportDocument: Equatable {
    let title: String
    let subtitle: String?
    let chapters: [ExportChapter]
    let options: ExportOptions

    init(
        title: String,
        subtitle: String? = nil,
        chapters: [ExportChapter],
        options: ExportOptions = .default
    ) {
        self.title = title
        self.subtitle = subtitle
        self.chapters = chapters
        self.options = options
    }

    static func from(sheets: [Sheet], options: ExportOptions, bundleTitle: String? = nil) -> ExportDocument {
        let sorted = sheets.sorted { $0.sortOrder < $1.sortOrder }
        let chapters = sorted.map { sheet in
            ExportChapter(
                id: sheet.id,
                title: sheet.title.isEmpty ? "无标题" : sheet.title,
                body: sheet.body,
                sortOrder: sheet.sortOrder,
                isGluedToPrevious: sheet.isGluedToPrevious
            )
        }
        let title: String
        if let bundleTitle, !bundleTitle.isEmpty {
            title = bundleTitle
        } else if chapters.count == 1 {
            title = chapters[0].title
        } else {
            title = "导出合集"
        }
        return ExportDocument(title: title, subtitle: nil, chapters: chapters, options: options)
    }

    static func single(_ sheet: Sheet, options: ExportOptions = .default) -> ExportDocument {
        from(sheets: [sheet], options: options)
    }

    var combinedMarkdown: String {
        chapters.map { chapter in
            var parts: [String] = []
            if chapters.count > 1, options.chapterPerSheet, !chapter.isGluedToPrevious {
                parts.append("# \(chapter.title)")
                parts.append("")
            }
            parts.append(chapter.body)
            return parts.joined(separator: "\n")
        }.enumerated().reduce(into: "") { result, item in
            let index = item.offset
            let content = item.element
            guard !result.isEmpty else {
                result = content
                return
            }
            result += chapters[index].isGluedToPrevious ? "\n" : "\n\n"
            result += content
        }
    }

    var allBlocks: [(chapterID: UUID, chapterTitle: String, block: Block)] {
        var result: [(UUID, String, Block)] = []
        for chapter in chapters {
            let blocks = BlockParser.parse(chapter.body)
            for block in blocks {
                result.append((chapter.id, chapter.title, block))
            }
        }
        return result
    }
}
