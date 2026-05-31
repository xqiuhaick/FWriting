//
//  OutlineInspectorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct OutlineInspectorView: View {
    let sheet: Sheet
    let allSheets: [Sheet]

    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var summary: String {
        sheet.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// 仅归入项目的正文稿才参与章节顺序；「全部文稿」等未归项目稿不显示章节信息。
    private var showsChapterInfo: Bool {
        sheet.project != nil && sheet.kind == .text
    }

    private var chapterContext: String {
        guard showsChapterInfo else { return "未提供" }
        let custom = sheet.summaryChapterContext?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? defaultChapterContext : custom
    }

    private var defaultChapterContext: String {
        if let position = ChapterOrdering.position(for: sheet, in: allSheets) {
            return position.detailText
        }
        return "章节位置：未能确定。章节标题：\(sheet.displayTitle)。"
    }

    private var chapterContextBinding: Binding<String> {
        Binding(
            get: {
                guard showsChapterInfo else { return "" }
                if sheet.summaryChapterContext?.isEmpty == false {
                    return sheet.summaryChapterContext ?? ""
                }
                return defaultChapterContext
            },
            set: { value in
                guard showsChapterInfo else { return }
                sheet.summaryChapterContext = value
                try? sheet.modelContext?.save()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章节摘要")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await generateSummary() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(summary.isEmpty ? "生成" : "重新生成", systemImage: "sparkles")
                    }
                }
                .controlSize(.small)
                .disabled(isGenerating || sheet.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if showsChapterInfo {
                VStack(alignment: .leading, spacing: 5) {
                    Text("章节信息")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("章节信息", text: chapterContextBinding, axis: .vertical)
                        .font(.caption)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if summary.isEmpty {
                ContentUnavailableView {
                    Label("暂无摘要", systemImage: "text.alignleft")
                } description: {
                    Text(
                        showsChapterInfo
                        ? "生成后，完整续写会参考前面章节的摘要。"
                        : "生成后可用于 AI 续写。归入项目后可显示章节顺序。"
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let updatedAt = sheet.summaryUpdatedAt {
                    Text("更新于 \(updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func generateSummary() async {
        let text = sheet.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let result = try await AIService.summarize(
                text: text,
                title: sheet.displayTitle,
                chapterContext: chapterContext
            )
            sheet.summary = result
            sheet.summaryUpdatedAt = .now
            try? sheet.modelContext?.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
