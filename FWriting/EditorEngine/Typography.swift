//
//  Typography.swift
//  FWriting
//

import AppKit
import SwiftUI

enum EditorPreferences {
    static let editorWidthKey = "editorMaxWidth"
    static let markdownHighlightKey = "markdownHighlight"
    static let typewriterModeKey = "typewriterMode"
    static let currentLineHighlightKey = "currentLineHighlight"
    static let paragraphFocusKey = "paragraphFocus"
    static let autoSaveKey = "autoSaveEnabled"
    static let defaultExportFormatKey = "defaultExportFormat"
    static let exportStyleKey = "exportStyle"
    static let exportAuthorKey = "exportAuthor"
    static let exportIncludeTOCKey = "exportIncludeTOC"
    static let exportTitlePageKey = "exportTitlePage"
    static let exportIncludeCommentsKey = "exportIncludeComments"
    static let openLastProjectKey = "openLastProject"
    static let wordCountModeKey = "wordCountMode"
    static let showInsertBarKey = "showInsertBar"

    static var editorMaxWidth: Double {
        get { UserDefaults.standard.object(forKey: editorWidthKey) as? Double ?? 720 }
        set { UserDefaults.standard.set(newValue, forKey: editorWidthKey) }
    }

    static var markdownHighlight: Bool {
        get { UserDefaults.standard.object(forKey: markdownHighlightKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: markdownHighlightKey) }
    }

    static var typewriterMode: Bool {
        get { UserDefaults.standard.object(forKey: typewriterModeKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: typewriterModeKey) }
    }

    static var currentLineHighlight: Bool {
        get { UserDefaults.standard.object(forKey: currentLineHighlightKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: currentLineHighlightKey) }
    }

    static var paragraphFocus: Bool {
        get { UserDefaults.standard.object(forKey: paragraphFocusKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: paragraphFocusKey) }
    }

    static var autoSaveEnabled: Bool {
        get { UserDefaults.standard.object(forKey: autoSaveKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoSaveKey) }
    }

    static var defaultExportFormat: String {
        get { UserDefaults.standard.string(forKey: defaultExportFormatKey) ?? ExportFormat.markdown.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: defaultExportFormatKey) }
    }

    static var openLastProject: Bool {
        get { UserDefaults.standard.object(forKey: openLastProjectKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: openLastProjectKey) }
    }

    static var showInsertBar: Bool {
        get { UserDefaults.standard.object(forKey: showInsertBarKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showInsertBarKey) }
    }
}

enum EditorTypographySpec {
    static let bodyFontSize: CGFloat = 15
    static let lineHeightMultiple: CGFloat = 1.6
    static let paragraphSpacing: CGFloat = 9

    static let h1Size: CGFloat = 32
    static let h2Size: CGFloat = 26
    static let h3Size: CGFloat = 22

    static let h1Weight: NSFont.Weight = .bold
    static let h2Weight: NSFont.Weight = .semibold
    static let h3Weight: NSFont.Weight = .medium
    static let codeFontSize: CGFloat = 14
}

struct EditorTypography {
    let maxWidth: Double

    init(maxWidth: Double = EditorPreferences.editorMaxWidth) {
        self.maxWidth = maxWidth
    }

    var titleFont: Font {
        .system(size: EditorTypographySpec.h1Size, weight: .bold)
    }

    var bodyFont: Font {
        .system(size: EditorTypographySpec.bodyFontSize)
    }

    static func bodyParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = EditorTypographySpec.lineHeightMultiple
        style.paragraphSpacing = EditorTypographySpec.paragraphSpacing
        return style
    }

    static func bodyFont() -> NSFont {
        NSFont.systemFont(ofSize: EditorTypographySpec.bodyFontSize, weight: .regular)
    }

    /// Markdown 语法标记（#、>、- 等）使用正文小号，与标题正文区分。
    static func markerFont() -> NSFont {
        bodyFont()
    }

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1:
            NSFont.systemFont(ofSize: EditorTypographySpec.h1Size, weight: EditorTypographySpec.h1Weight)
        case 2:
            NSFont.systemFont(ofSize: EditorTypographySpec.h2Size, weight: EditorTypographySpec.h2Weight)
        default:
            NSFont.systemFont(ofSize: EditorTypographySpec.h3Size, weight: EditorTypographySpec.h3Weight)
        }
    }
}
