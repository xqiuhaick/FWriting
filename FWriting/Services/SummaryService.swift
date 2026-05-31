//
//  SummaryService.swift
//  FWriting
//
//  自动章节摘要管线：写完一章后自动生成结构化摘要，供后续续写时用。
//

import Foundation
import SwiftData

enum SummaryService {
    /// 低于此字数不生成摘要。
    static let minWordCountForSummary = 300
    /// 字数变化低于此比例不重新生成。
    static let reSummarizeWordRatioThreshold = 0.3

    /// 判断是否需要为 sheet 生成或更新摘要。
    static func needsSummary(_ sheet: Sheet) -> Bool {
        let wordCount = sheet.wordCount
        guard wordCount >= minWordCountForSummary else { return false }

        // 从未生成过
        guard let lastSummary = sheet.summary, !lastSummary.isEmpty,
              let lastUpdated = sheet.summaryUpdatedAt else {
            return true
        }

        // body 修改过但摘要没更新
        guard lastUpdated >= sheet.modifiedAt else {
            // 字数变化超过阈值才重新生成
            let lastSummaryWordCount = WritingStatsService.wordCount(for: lastSummary)
            guard lastSummaryWordCount > 0 else { return true }
            let ratio = abs(Double(wordCount - lastSummaryWordCount)) / Double(max(lastSummaryWordCount, 1))
            return ratio > reSummarizeWordRatioThreshold
        }

        return false
    }

    /// 为 Sheet 生成章节上下文信息（前后章节标题），用于摘要提示词。
    static func buildChapterContext(for sheet: Sheet, in allSheets: [Sheet]) -> String {
        var lines: [String] = []

        if let project = sheet.project {
            let siblings = allSheets
                .filter { $0.project?.id == project.id && $0.kind == .text }
                .sorted { $0.sortOrder < $1.sortOrder }

            if let index = siblings.firstIndex(where: { $0.id == sheet.id }) {
                if index > 0 {
                    lines.append("上一章：\(siblings[index - 1].displayTitle)")
                }
                if index < siblings.count - 1 {
                    lines.append("下一章：\(siblings[index + 1].displayTitle)")
                }
            }
        }

        return lines.isEmpty ? "未提供" : lines.joined(separator: "\n")
    }

    /// 异步生成摘要并保存到 Sheet。
    static func generateSummary(for sheet: Sheet, in allSheets: [Sheet]) async {
        guard needsSummary(sheet) else { return }
        let body = sheet.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let chapterContext = buildChapterContext(for: sheet, in: allSheets)

        do {
            let summary = try await AIService.summarize(
                text: body,
                title: sheet.displayTitle,
                chapterContext: chapterContext
            )
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            await MainActor.run {
                sheet.summary = trimmed
                sheet.summaryChapterContext = chapterContext
                sheet.summaryUpdatedAt = .now
            }
        } catch {
            // 悄无声息地失败——不打断用户写作流程。
            print("[SummaryService] 摘要生成失败: \(error.localizedDescription)")
        }
    }

    /// 收集当前 Sheet 在项目中的前面章节摘要，拼接后喂给续写。
    static func previousSummaries(for sheet: Sheet, in allSheets: [Sheet]) -> String {
        guard let project = sheet.project else { return "" }

        let siblings = allSheets
            .filter { $0.project?.id == project.id && $0.kind == .text }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let index = siblings.firstIndex(where: { $0.id == sheet.id }),
              index > 0 else { return "" }

        let previousChapters = siblings[0..<index]
        let summaries = previousChapters.compactMap { chapter -> String? in
            guard let summary = chapter.summary,
                  !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let header = "第 \(chapter.sortOrder + 1) 章 · \(chapter.displayTitle)"
            return "\(header)\n\(summary.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        return summaries.isEmpty ? "" : summaries.joined(separator: "\n\n---\n\n")
    }
}
