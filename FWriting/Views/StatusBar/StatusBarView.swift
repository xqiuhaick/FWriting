//
//  StatusBarView.swift
//  FWriting
//

import SwiftUI

struct StatusBarView: View {
    let sheet: Sheet
    let saveStatus: SaveStatus

    var body: some View {
        HStack(spacing: 8) {
            Label(sheet.kind.title, systemImage: sheet.kind.icon)
            dot
            Text(WritingStatsService.formattedWordCount(sheet.wordCount) + " 字")
            dot
            Text(WritingStatsService.formattedWordCount(sheet.characterCount) + " 字符")
            dot
            Text("\(sheet.readingMinutes) 分钟阅读")

            if let goal = sheet.wordGoal, goal > 0 {
                dot
                let progress = min(Double(sheet.wordCount) / Double(goal), 1.0)
                Text("\(Int(progress * 100))% 目标")
                    .help("\(WritingStatsService.formattedWordCount(sheet.wordCount)) / \(WritingStatsService.formattedWordCount(goal))")
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: saveStatus == .saved ? "checkmark.circle" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                Text(saveStatus.label)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(height: 24)
        .padding(.horizontal, 16)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var dot: some View {
        Text("·")
            .foregroundStyle(.tertiary)
    }
}
