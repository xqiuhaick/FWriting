//
//  SampleDataCleanup.swift
//  FWriting
//

import Foundation
import SwiftData

enum SampleDataCleanup {
    private static let cleanupKey = "hasRemovedSampleData"

    private static let sampleSheetTitles = [
        "欢迎使用文栈",
        "中亚新闻翻译示例",
        "论文第一章 绪论"
    ]

    private static let sampleProjectNames = [
        "论文写作",
        "翻译项目",
        "日记",
        "资料整理"
    ]

    private static let sampleTagNames = [
        "论文",
        "哈萨克语",
        "翻译",
        "新闻稿"
    ]

    @MainActor
    static func removeSamplesIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else { return }

        if let sheets = try? modelContext.fetch(FetchDescriptor<Sheet>()) {
            for sheet in sheets where sampleSheetTitles.contains(sheet.title) {
                modelContext.delete(sheet)
            }
        }

        if let projects = try? modelContext.fetch(FetchDescriptor<Project>()) {
            for project in projects where sampleProjectNames.contains(project.name) {
                modelContext.delete(project)
            }
        }

        if let tags = try? modelContext.fetch(FetchDescriptor<Tag>()) {
            for tag in tags where sampleTagNames.contains(tag.name) {
                modelContext.delete(tag)
            }
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: cleanupKey)
        UserDefaults.standard.removeObject(forKey: "hasSeededSampleData")
    }
}
