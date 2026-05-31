//
//  ContentView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @State private var appState = AppState()
    @State private var isShowingVersionHistory = false
    @State private var previousSheetID: UUID?

    @Query(sort: \Sheet.modifiedAt, order: .reverse) private var allSheets: [Sheet]

    private var selectedSheet: Sheet? {
        guard let id = appState.selectedSheetID else { return nil }
        guard let sheet = allSheets.first(where: { $0.id == id }) else { return nil }
        guard ProjectSecurity.isAccessible(sheet, appState: appState) else { return nil }
        return sheet
    }

    var body: some View {
        splitView
            .modifier(FocusAwareSearchable(
                isFocusMode: appState.isFocusMode,
                text: $appState.searchText
            ))
            .toolbar(appState.isFocusMode ? .hidden : .visible, for: .windowToolbar)
            .toolbar { mainToolbar }
            .overlay(alignment: .topTrailing) {
                if appState.isFocusMode {
                    focusModeExitControl
                }
            }
            .background(FullscreenEscapeMonitor(appState: appState))
            .sheet(isPresented: $appState.isShowingExportPanel) {
                if let sheet = selectedSheet {
                    ExportPanelView(sheet: sheet)
                }
            }
            .onAppear {
                SampleDataCleanup.removeSamplesIfNeeded(modelContext: modelContext)
                AIService.normalizeLegacyPrompts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAppSettings)) { _ in
                openSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNewSheet)) { _ in
                SheetCreation.create(in: modelContext, appState: appState)
            }
            .onReceive(NotificationCenter.default.publisher(for: .createMaterialSheet)) { _ in
                SheetCreation.create(in: modelContext, appState: appState, kind: .material)
            }
            .onReceive(NotificationCenter.default.publisher(for: .splitSelectedSheet)) { _ in
                guard let sheet = selectedSheet else { return }
                triggerSummaryIfNeeded(for: sheet)
                if let newSheet = SheetLibraryOperations.splitAtSelection(
                    sheet: sheet,
                    selectedRange: EditorFocusState.shared.selectedRange,
                    modelContext: modelContext
                ) {
                    appState.selectedSheetID = newSheet.id
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showVersionHistory)) { _ in
                if selectedSheet != nil {
                    isShowingVersionHistory = true
                }
            }
            .sheet(isPresented: $isShowingVersionHistory) {
                if let sheet = selectedSheet {
                    VersionHistoryView(sheet: sheet)
                }
            }
            .focusedSceneValue(\.appState, appState)
            .focusedSceneValue(\.selectedSheet, selectedSheet)
            .onChange(of: appState.selectedSheetID) { oldID, newID in
                if let oldID, let previousSheet = allSheets.first(where: { $0.id == oldID }) {
                    triggerSummaryIfNeeded(for: previousSheet)
                }
            }
    }

    private var focusModeExitControl: some View {
        Button {
            appState.exitFocusMode()
        } label: {
            Label("退出专注", systemImage: "arrow.down.right.and.arrow.up.left")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(12)
        .help("退出专注模式 (Esc 或 ⌘⇧F)")
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(220)
        } content: {
            SheetListView(appState: appState)
                .navigationSplitViewColumnWidth(
                    min: 220,
                    ideal: appState.isShowingInspector && !appState.isFocusMode ? 260 : 280,
                    max: 320
                )
        } detail: {
            EditorView(appState: appState, allSheets: allSheets, sheet: selectedSheet)
        }
        .inspector(isPresented: inspectorBinding) {
            InspectorView(appState: appState, allSheets: allSheets, sheet: selectedSheet)
                .inspectorColumnWidth(min: 200, ideal: 240, max: 280)
        }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { appState.isShowingInspector && !appState.isFocusMode },
            set: { appState.isShowingInspector = $0 }
        )
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                SheetCreation.create(in: modelContext, appState: appState)
            } label: {
                Label(appState.librarySelection == .materials ? "新建资料" : "新建", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help(appState.librarySelection == .materials ? "新建资料" : "新建文稿")

            Button {
                appState.isShowingExportPanel = true
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedSheet == nil)
            .help("导出文稿")

            Button {
                toggleFocusMode()
            } label: {
                Label(
                    appState.isFocusMode ? "退出专注" : "专注模式",
                    systemImage: appState.isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
            }
            .help("专注模式 (⌘⇧F)")
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button {
                openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .help("设置 (⌘,)")

            Button {
                appState.isShowingInspector.toggle()
            } label: {
                Label("检查器", systemImage: "sidebar.trailing")
            }
            .disabled(selectedSheet == nil)
            .help("检查器：统计 / 摘要 / 目标 / 人物 / 标签 (⌥⌘I)")
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    private func toggleFocusMode() {
        if appState.isFocusMode {
            appState.exitFocusMode()
        } else {
            appState.enterFocusMode()
        }
    }

    private func triggerSummaryIfNeeded(for sheet: Sheet) {
        guard SummaryService.needsSummary(sheet) else { return }
        let sheets = allSheets
        Task {
            await SummaryService.generateSummary(for: sheet, in: sheets)
        }
    }
}

private struct FocusAwareSearchable: ViewModifier {
    let isFocusMode: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isFocusMode {
            content
        } else {
            content
                .searchable(text: $text, prompt: "搜索文稿…")
        }
    }
}

/// 捕获 Esc，退出系统全屏或专注模式。
private struct FullscreenEscapeMonitor: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> EscapeKeyView {
        let view = EscapeKeyView()
        view.appState = appState
        return view
    }

    func updateNSView(_ nsView: EscapeKeyView, context: Context) {
        nsView.appState = appState
    }

    final class EscapeKeyView: NSView {
        var appState: AppState?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installMonitorIfNeeded()
        }

        override func removeFromSuperview() {
            removeMonitor()
            super.removeFromSuperview()
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil, window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                guard let appState = self?.appState else { return event }
                let shouldHandle = FullscreenHelper.isFullScreen || appState.isFocusMode
                guard shouldHandle else { return event }
                FullscreenHelper.handleEscape(appState: appState)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Sheet.self, Tag.self, Character.self, SheetSnapshot.self], inMemory: true)
}
