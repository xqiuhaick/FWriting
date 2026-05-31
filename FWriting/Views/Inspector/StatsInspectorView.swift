//
//  StatsInspectorView.swift
//  FWriting
//

import SwiftUI

struct StatsInspectorView: View {
    let sheet: Sheet

    private var stats: WritingStats {
        WritingStatsService.stats(for: sheet.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("计数器") {
                row("字符", "\(stats.characters)")
                row("不计空格", "\(stats.charactersNoSpaces)")
                row("字", "\(stats.words)")
                row("句", "\(stats.sentences)")
                row("段落", "\(stats.paragraphs)")
                row("行", "\(stats.lines)")
                row("页面", String(format: "%.1f", stats.pages))
            }

            section("阅读时间") {
                row("慢", WritingStatsService.formattedDuration(stats.slowSeconds))
                row("平均", WritingStatsService.formattedDuration(stats.averageSeconds))
                row("快", WritingStatsService.formattedDuration(stats.fastSeconds))
                row("朗读", WritingStatsService.formattedDuration(stats.readAloudSeconds))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}
