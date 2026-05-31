//
//  SettingsView.swift
//  FWriting
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(EditorPreferences.openLastProjectKey) private var openLastProject = EditorPreferences.openLastProject
    @AppStorage(EditorPreferences.autoSaveKey) private var autoSaveEnabled = EditorPreferences.autoSaveEnabled
    @AppStorage(EditorPreferences.markdownHighlightKey) private var markdownHighlight = EditorPreferences.markdownHighlight
    @AppStorage(EditorPreferences.typewriterModeKey) private var typewriterMode = EditorPreferences.typewriterMode
    @AppStorage(EditorPreferences.currentLineHighlightKey) private var currentLineHighlight = EditorPreferences.currentLineHighlight
    @AppStorage(EditorPreferences.paragraphFocusKey) private var paragraphFocus = EditorPreferences.paragraphFocus
    @AppStorage(EditorPreferences.showInsertBarKey) private var showInsertBar = EditorPreferences.showInsertBar
    @AppStorage(EditorPreferences.defaultExportFormatKey) private var defaultExportFormat = EditorPreferences.defaultExportFormat
    @AppStorage(EditorPreferences.exportStyleKey) private var exportStyleRaw = ExportStyle.modern.rawValue
    @AppStorage(EditorPreferences.exportAuthorKey) private var exportAuthor = ""
    @AppStorage(AIService.apiKeyKey) private var aiAPIKey = ""
    @AppStorage(AIService.modelKey) private var aiDefaultModel = AIService.defaultModel
    @AppStorage(AIService.baseURLKey) private var aiBaseURL = AIService.defaultBaseURL
    @AppStorage(AIService.disableThinkingKey) private var aiDisableThinking = true

    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var modelsError: String?
    @State private var modelsFetchTask: Task<Void, Never>?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            editorTab
                .tabItem { Label("编辑器", systemImage: "textformat") }
            exportTab
                .tabItem { Label("导出", systemImage: "square.and.arrow.up") }
            aiTab
                .tabItem { Label("DeepSeek", systemImage: "sparkles") }
        }
        .frame(width: 480, height: 320)
        .onAppear {
            migrateLegacyAISettings()
            AIService.normalizeLegacyPrompts()
            Task { await loadModels() }
        }
    }

    private var generalTab: some View {
        Form {
            Toggle("默认打开上次项目", isOn: $openLastProject)
            Toggle("自动保存", isOn: $autoSaveEnabled)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var editorTab: some View {
        Form {
            Toggle("结构渲染（轻 Markdown）", isOn: $markdownHighlight)
            Toggle("当前行高亮", isOn: $currentLineHighlight)
            Toggle("段落聚焦", isOn: $paragraphFocus)
            Toggle("打字机模式", isOn: $typewriterMode)
            Toggle("底部 Markdown 插入栏", isOn: $showInsertBar)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var exportTab: some View {
        Form {
            Picker("默认导出格式", selection: $defaultExportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.displayName).tag(format.rawValue)
                }
            }
            Picker("默认导出样式", selection: $exportStyleRaw) {
                ForEach(ExportStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            TextField("默认作者名", text: $exportAuthor)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aiTab: some View {
        Form {
            SecureField("DeepSeek API Key", text: $aiAPIKey)
                .onChange(of: aiAPIKey) { _, _ in
                    scheduleModelFetch()
                }

            TextField("DeepSeek API 地址", text: $aiBaseURL)
                .onChange(of: aiBaseURL) { _, _ in
                    scheduleModelFetch()
                }

            HStack {
                if availableModels.isEmpty {
                    TextField("DeepSeek 模型", text: $aiDefaultModel)
                } else {
                    Picker("DeepSeek 模型", selection: $aiDefaultModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                Button {
                    Task { await loadModels() }
                } label: {
                    if isLoadingModels {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingModels)
                .help("根据 API Key 获取可用模型")
            }

            if let modelsError {
                Text(modelsError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("快速模式（跳过推理，直接输出）", isOn: $aiDisableThinking)
                .help("开启后跳过 AI 推理步骤，直接生成结果。润色/翻译/续写更快。写作场景建议开启。")
        }
        .formStyle(.grouped)
        .padding()
    }

    @MainActor
    private func scheduleModelFetch() {
        modelsFetchTask?.cancel()
        modelsFetchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await loadModels()
        }
    }

    @MainActor
    private func loadModels() async {
        let key = aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            availableModels = []
            modelsError = nil
            return
        }

        isLoadingModels = true
        modelsError = nil
        defer { isLoadingModels = false }

        do {
            let models = try await AIService.fetchModels()
            availableModels = models
            if !models.contains(aiDefaultModel) {
                aiDefaultModel = models.first(where: { $0 == AIService.defaultModel }) ?? models[0]
            }
        } catch {
            availableModels = []
            modelsError = error.localizedDescription
        }
    }

    private func migrateLegacyAISettings() {
        aiDefaultModel = AIService.normalizeLegacyModel(aiDefaultModel)

        let baseURL = aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.isEmpty || baseURL == "https://api.openai.com/v1/chat/completions" {
            aiBaseURL = AIService.defaultBaseURL
        }
    }
}
