//
//  EditorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var appState: AppState

    let allSheets: [Sheet]
    let sheet: Sheet?

    @State private var autoSave = AutoSaveService()
    @AppStorage(EditorPreferences.markdownHighlightKey) private var markdownHighlight = EditorPreferences.markdownHighlight
    @AppStorage(EditorPreferences.typewriterModeKey) private var typewriterMode = EditorPreferences.typewriterMode
    @AppStorage(EditorPreferences.currentLineHighlightKey) private var currentLineHighlight = EditorPreferences.currentLineHighlight
    @AppStorage(EditorPreferences.paragraphFocusKey) private var paragraphFocus = EditorPreferences.paragraphFocus
    @AppStorage(EditorPreferences.showInsertBarKey) private var showInsertBar = EditorPreferences.showInsertBar

    private let typography = EditorTypography()
    @State private var horizontalPadding: CGFloat = 32
    private let topTextPadding: CGFloat = 60

    private var textMaxWidth: CGFloat {
        max(CGFloat(typography.maxWidth), 1040)
    }

    var body: some View {
        Group {
            if let sheet {
                editorContent(for: sheet)
            } else {
                ContentUnavailableView {
                    Label("选择或新建文稿", systemImage: "square.and.pencil")
                } description: {
                    Text("从左侧列表选择一篇文稿，或创建新文稿开始写作")
                } actions: {
                    Button("新建文稿") {
                        SheetCreation.create(in: modelContext, appState: appState)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .topTrailing) {
            if let sheet, !appState.isFocusMode {
                Text(WritingStatsService.formattedWordCount(sheet.wordCount) + " 字")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { horizontalPadding = adaptivePadding(for: geometry.size.width) }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        horizontalPadding = adaptivePadding(for: newWidth)
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiPolishRequested)) { _ in
            EditorFocusState.shared.beginInlineAI?(.polish)
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiTranslateRequested)) { _ in
            EditorFocusState.shared.beginInlineAI?(.translate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiContinueRequested)) { _ in
            EditorFocusState.shared.beginInlineAI?(.continueWriting)
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiBrainstormRequested)) { _ in
            EditorFocusState.shared.beginInlineAI?(.brainstorm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiQuickCreateRequested)) { _ in
            EditorFocusState.shared.beginInlineAI?(.quickCreate)
        }
    }

    @ViewBuilder
    private func editorContent(for sheet: Sheet) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                MarkdownTextView(
                    text: Binding(
                        get: { sheet.body },
                        set: {
                            sheet.body = $0
                            SheetTitleSync.applyFirstHeading(to: sheet)
                            scheduleSave(sheet)
                        }
                    ),
                    typography: typography,
                    markdownHighlight: markdownHighlight,
                    typewriterMode: typewriterMode,
                    currentLineHighlight: currentLineHighlight,
                    paragraphFocus: paragraphFocus,
                    previousSummaries: previousSummaries(for: sheet),
                    horizontalTextInset: horizontalPadding,
                    topTextInset: topTextPadding,
                    onTextChange: {
                        SheetTitleSync.applyFirstHeading(to: sheet)
                        scheduleSave(sheet)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showInsertBar && !appState.isFocusMode {
                MarkdownInsertBar()
            }

            StatusBarView(sheet: sheet, saveStatus: appState.saveStatus)
        }
        .onAppear {
            SheetTitleSync.applyFirstHeading(to: sheet)
        }
    }

    private func adaptivePadding(for width: CGFloat) -> CGFloat {
        /// 窄窗口用较少 padding，宽窗口保持接近参考图的左右留白。
        let targetTextWidth = textMaxWidth
        let available = max(width, 200)
        let padding = max(96, (available - targetTextWidth) / 2)
        return min(padding, 320)
    }

    private func scheduleSave(_ sheet: Sheet) {
        guard EditorPreferences.autoSaveEnabled else { return }
        autoSave.scheduleSave(sheet: sheet, modelContext: modelContext, appState: appState)
    }

    private func previousSummaries(for sheet: Sheet) -> String {
        previousSummarySheets(for: sheet).enumerated()
            .compactMap { index, previous -> String? in
                let summary = previous.summary?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !summary.isEmpty else { return nil }
                return "第 \(index + 1) 章：\(previous.displayTitle)\n\(summary)"
            }
            .joined(separator: "\n\n")
    }

    private func previousSummarySheets(for sheet: Sheet) -> [Sheet] {
        let ordered = orderedSummaryScope(for: sheet)
        guard let index = ordered.firstIndex(where: { $0.id == sheet.id }) else { return [] }
        return Array(ordered.prefix(index))
    }

    private func orderedSummaryScope(for sheet: Sheet) -> [Sheet] {
        allSheets
            .filter { candidate in
                candidate.kind == .text &&
                !candidate.isTrashed &&
                isInSameSummaryScope(candidate, sheet)
            }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private func isInSameSummaryScope(_ lhs: Sheet, _ rhs: Sheet) -> Bool {
        switch (lhs.project?.id, rhs.project?.id) {
        case let (left?, right?):
            return left == right
        case (nil, nil):
            return true
        default:
            return false
        }
    }

}
