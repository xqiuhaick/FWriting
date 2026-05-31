//
//  FullscreenHelper.swift
//  FWriting
//

import AppKit

enum FullscreenHelper {
    static var mainWindow: NSWindow? {
        NSApp.mainWindow ?? NSApp.windows.first { $0.canBecomeMain }
    }

    static var isFullScreen: Bool {
        mainWindow?.styleMask.contains(.fullScreen) == true
    }

    static func toggleNativeFullScreen() {
        mainWindow?.toggleFullScreen(nil)
    }

    static func exitNativeFullScreen() {
        guard let window = mainWindow, window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }

    /// Esc：先退出系统全屏，再由调用方处理专注模式等。
    static func handleEscape(appState: AppState?) {
        if isFullScreen {
            exitNativeFullScreen()
            return
        }
        if appState?.isFocusMode == true {
            appState?.exitFocusMode()
        }
    }
}
