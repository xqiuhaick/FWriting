//
//  ExportPanelView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct ExportPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let sheet: Sheet

    @AppStorage(EditorPreferences.defaultExportFormatKey) private var defaultFormat = EditorPreferences.defaultExportFormat
    @AppStorage(EditorPreferences.exportStyleKey) private var exportStyleRaw = ExportStyle.modern.rawValue
    @AppStorage(EditorPreferences.exportAuthorKey) private var exportAuthor = ""
    @AppStorage(EditorPreferences.exportIncludeTOCKey) private var exportIncludeTOC = true
    @AppStorage(EditorPreferences.exportTitlePageKey) private var exportTitlePage = true
    @AppStorage(EditorPreferences.exportIncludeCommentsKey) private var exportIncludeComments = false

    @Query(sort: \Sheet.sortOrder) private var allSheets: [Sheet]

    @State private var selectedFormat: ExportFormat = .html
    @State private var scope: ExportScope = .currentSheet
    @State private var previewHTML = ""
    @State private var previewPDFData: Data?
    private var exportStyle: ExportStyle {
        ExportStyle(rawValue: exportStyleRaw) ?? .modern
    }

    private var projectSheets: [Sheet] {
        guard let project = sheet.project else { return [sheet] }
        return LibraryMetrics.sheets(for: project, projects: allProjects, sheets: allSheets)
            .filter { $0.kind == .text }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

    private var canExportProject: Bool {
        sheet.project != nil && projectSheets.count > 1
    }

    private var options: ExportOptions {
        ExportOptions(
            scope: scope,
            style: exportStyle,
            includeTableOfContents: exportIncludeTOC,
            includeComments: exportIncludeComments,
            includeTitlePage: exportTitlePage,
            chapterPerSheet: true,
            author: exportAuthor,
            bodyFontSize: EditorTypographySpec.bodyFontSize,
            maxWidth: EditorPreferences.editorMaxWidth
        )
    }

    private var document: ExportDocument {
        ExportManager.buildDocument(
            primarySheet: sheet,
            projectSheets: projectSheets,
            options: options
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            optionsColumn
                .frame(width: 340)
                .padding(24)

            Divider()

            previewColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1040, height: 640)
        .onAppear {
            selectedFormat = ExportFormat(rawValue: defaultFormat) ?? .html
            refreshPreview()
        }
        .onChange(of: selectedFormat) { refreshPreview() }
        .onChange(of: scope) { refreshPreview() }
        .onChange(of: exportStyleRaw) { refreshPreview() }
        .onChange(of: exportIncludeTOC) { refreshPreview() }
        .onChange(of: exportTitlePage) { refreshPreview() }
        .onChange(of: exportIncludeComments) { refreshPreview() }
        .onChange(of: exportAuthor) { refreshPreview() }
    }

    private var optionsColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("导出")
                            .font(.title2.bold())
                        Text(sheet.title.isEmpty ? "无标题" : sheet.title)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Group {
                        Text("范围")
                            .font(.headline)
                        Picker("范围", selection: $scope) {
                            Text(ExportScope.currentSheet.displayName).tag(ExportScope.currentSheet)
                            if canExportProject, let name = sheet.project?.name {
                                Text("项目「\(name)」（\(projectSheets.count) 篇）").tag(ExportScope.project)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    Group {
                        Text("格式")
                            .font(.headline)
                        Picker("格式", selection: $selectedFormat) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Group {
                        Text("样式")
                            .font(.headline)
                        Picker("样式", selection: $exportStyleRaw) {
                            ForEach(ExportStyle.allCases) { style in
                                Text(style.displayName).tag(style.rawValue)
                            }
                        }
                        Text(exportStyle.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Group {
                        Text("选项")
                            .font(.headline)
                        Toggle("扉页（标题与作者）", isOn: $exportTitlePage)
                        Toggle("目录", isOn: $exportIncludeTOC)
                        Toggle("包含注释 (%%)", isOn: $exportIncludeComments)
                        TextField("作者名（可选）", text: $exportAuthor)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Menu {
                    Button("复制富文本") {
                        ExportManager.copyAsRichText(document: document)
                    }
                    Button("复制 HTML（适合博客）") {
                        ExportManager.copyHTML(document: document)
                    }
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("导出…") { performExport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预览")
                    .font(.headline)
                Spacer()
                if scope == .project {
                    Text("\(document.chapters.count) 篇文稿")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ExportPreviewView(html: previewHTML, pdfData: previewPDFData, format: selectedFormat)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    private func refreshPreview() {
        previewHTML = ExportManager.previewHTML(document: document)
        previewPDFData = selectedFormat == .pdf ? ExportManager.previewPDFData(document: document) : nil
    }

    private func performExport() {
        EditorPreferences.defaultExportFormat = selectedFormat.rawValue
        ExportManager.export(document: document, format: selectedFormat)
        dismiss()
    }
}
