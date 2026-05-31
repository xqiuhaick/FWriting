//
//  AppCommands.swift
//  FWriting
//

import AppKit
import SwiftData
import SwiftUI

private struct AppStateFocusedValueKey: FocusedValueKey {
    typealias Value = AppState
}

private struct SelectedSheetFocusedValueKey: FocusedValueKey {
    typealias Value = Sheet
}

extension FocusedValues {
    var appState: AppState? {
        get { self[AppStateFocusedValueKey.self] }
        set { self[AppStateFocusedValueKey.self] = newValue }
    }

    var selectedSheet: Sheet? {
        get { self[SelectedSheetFocusedValueKey.self] }
        set { self[SelectedSheetFocusedValueKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.appState) private var appState
    @FocusedValue(\.selectedSheet) private var selectedSheet

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文稿") {
                NotificationCenter.default.post(name: .createNewSheet, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("新建资料") {
                NotificationCenter.default.post(name: .createMaterialSheet, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        CommandMenu("文稿") {
            Button("导出…") {
                appState?.isShowingExportPanel = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Button("复制为富文本") {
                if let sheet = selectedSheet {
                    ExportManager.copyAsRichText(document: ExportDocument.single(sheet))
                }
            }
            .disabled(selectedSheet == nil)

            Divider()

            Button("专注模式") {
                if appState?.isFocusMode == true {
                    appState?.exitFocusMode()
                } else {
                    appState?.enterFocusMode()
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("AI 润色") {
                NotificationCenter.default.post(name: .aiPolishRequested, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Button("AI 翻译") {
                NotificationCenter.default.post(name: .aiTranslateRequested, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Button("AI 续写") {
                NotificationCenter.default.post(name: .aiContinueRequested, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Button("头脑风暴") {
                NotificationCenter.default.post(name: .aiBrainstormRequested, object: nil)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Button("快速创作") {
                NotificationCenter.default.post(name: .aiQuickCreateRequested, object: nil)
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])
            .disabled(selectedSheet == nil)

            Divider()

            Button(selectedSheet?.isFavorite == true ? "取消收藏" : "收藏") {
                guard let sheet = selectedSheet else { return }
                sheet.isFavorite.toggle()
                try? sheet.modelContext?.save()
            }
            .disabled(selectedSheet == nil)

            Button("设置目标字数…") {
                setWordGoal()
            }
            .disabled(selectedSheet == nil)

            Button("从光标处拆分") {
                NotificationCenter.default.post(name: .splitSelectedSheet, object: nil)
            }
            .disabled(selectedSheet == nil)

            Divider()

            Button("版本历史") {
                NotificationCenter.default.post(name: .showVersionHistory, object: nil)
            }
            .disabled(selectedSheet == nil)

            Button(appState?.isFocusMode == true ? "退出全屏写作" : "全屏写作") {
                if appState?.isFocusMode == true {
                    appState?.exitFocusMode()
                } else {
                    appState?.enterFocusMode()
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }

        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                NotificationCenter.default.post(name: .openAppSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    private func setWordGoal() {
        guard let sheet = selectedSheet else { return }
        let alert = NSAlert()
        alert.messageText = "目标字数"
        alert.informativeText = "为当前文稿设置写作目标"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        input.stringValue = sheet.wordGoal.map(String.init) ?? "3000"
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn, let value = Int(input.stringValue) {
            sheet.wordGoal = value
            try? sheet.modelContext?.save()
        }
    }
}

extension Notification.Name {
    static let showVersionHistory = Notification.Name("showVersionHistory")
    static let aiPolishRequested = Notification.Name("aiPolishRequested")
    static let aiTranslateRequested = Notification.Name("aiTranslateRequested")
    static let aiContinueRequested = Notification.Name("aiContinueRequested")
    static let aiBrainstormRequested = Notification.Name("aiBrainstormRequested")
    static let aiQuickCreateRequested = Notification.Name("aiQuickCreateRequested")
    static let openAppSettings = Notification.Name("FWriting.openAppSettings")
    static let createNewSheet = Notification.Name("FWriting.createNewSheet")
    static let createMaterialSheet = Notification.Name("FWriting.createMaterialSheet")
    static let splitSelectedSheet = Notification.Name("FWriting.splitSelectedSheet")
}
