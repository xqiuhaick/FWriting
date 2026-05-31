//
//  ExportStyle.swift
//  FWriting
//

import AppKit
import Foundation

enum ExportStyle: String, CaseIterable, Identifiable, Codable {
    case modern
    case serif
    case manuscript
    case minimal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modern: "现代"
        case .serif: "衬线"
        case .manuscript: "手稿"
        case .minimal: "极简"
        }
    }

    var summary: String {
        switch self {
        case .modern: "系统无衬线，舒适行距，适合屏幕阅读"
        case .serif: "宋体/衬线正文，经典书籍版式"
        case .manuscript: "Courier 等宽，双倍行距，投稿风格"
        case .minimal: "黑白、窄边距、无装饰"
        }
    }

    func bodyFont(size: CGFloat) -> NSFont {
        switch self {
        case .modern:
            NSFont.systemFont(ofSize: size, weight: .regular)
        case .serif:
            NSFont(name: "Songti SC", size: size)
                ?? NSFont(name: "STSong", size: size)
                ?? NSFont.systemFont(ofSize: size)
        case .manuscript:
            NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .minimal:
            NSFont.systemFont(ofSize: size, weight: .light)
        }
    }

    func headingFont(level: Int, bodySize: CGFloat) -> NSFont {
        let scale: CGFloat = switch level {
        case 1: 1.85
        case 2: 1.45
        default: 1.2
        }
        let size = bodySize * scale
        let weight: NSFont.Weight = switch (self, level) {
        case (.minimal, _): .regular
        case (_, 1): .bold
        case (_, 2): .semibold
        default: .medium
        }
        switch self {
        case .manuscript:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            return NSFont(name: "Songti SC Bold", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        default:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    func css(bodySize: CGFloat, maxWidth: CGFloat) -> String {
        let fontFamily: String = switch self {
        case .modern: "-apple-system, \"PingFang SC\", \"Helvetica Neue\", sans-serif"
        case .serif: "\"Songti SC\", \"STSong\", \"Noto Serif SC\", Georgia, serif"
        case .manuscript: "\"Courier New\", \"Menlo\", monospace"
        case .minimal: "-apple-system, BlinkMacSystemFont, sans-serif"
        }
        let lineHeight: CGFloat = self == .manuscript ? 2.0 : (self == .minimal ? 1.55 : 1.7)
        let textColor = self == .minimal ? "#111" : "#1a1a1a"
        let muted = self == .minimal ? "#666" : "#555"
        let maxW = Int(maxWidth)
        let bodyPx = Int(bodySize)
        let h1 = Int(bodySize * 1.85)
        let h2 = Int(bodySize * 1.45)
        let h3 = Int(bodySize * 1.2)

        return """
        :root {
          --text: \(textColor);
          --muted: \(muted);
          --accent: \(self == .minimal ? "#111" : "#2563eb");
          --border: \(self == .minimal ? "#ddd" : "#e5e7eb");
        }
        * { box-sizing: border-box; }
        body {
          font-family: \(fontFamily);
          font-size: \(bodyPx)px;
          line-height: \(lineHeight);
          color: var(--text);
          max-width: \(maxW)px;
          margin: 0 auto;
          padding: 48px 32px 80px;
          background: #fff;
        }
        .title-page { text-align: center; margin-bottom: 3em; padding-bottom: 2em; border-bottom: 1px solid var(--border); }
        .title-page h1 { font-size: \(h1 + 8)px; margin: 0 0 0.35em; font-weight: 700; }
        .title-page .meta { color: var(--muted); font-size: 0.9em; }
        .toc { margin: 2em 0 3em; padding: 1.25em 1.5em; background: \(self == .minimal ? "transparent" : "#f8fafc"); border: 1px solid var(--border); border-radius: 8px; }
        .toc h2 { font-size: 1.1em; margin: 0 0 0.75em; }
        .toc ol { margin: 0; padding-left: 1.4em; }
        .toc li { margin: 0.35em 0; }
        .toc a { color: var(--accent); text-decoration: none; }
        .toc a:hover { text-decoration: underline; }
        .chapter { margin-top: 3em; padding-top: 2em; border-top: 1px solid var(--border); }
        .chapter:first-of-type { margin-top: 0; padding-top: 0; border-top: none; }
        .chapter-title { font-size: \(h1)px; margin: 0 0 1em; }
        h1 { font-size: \(h1)px; margin: 1.6em 0 0.5em; font-weight: 700; }
        h2 { font-size: \(h2)px; margin: 1.4em 0 0.45em; font-weight: 600; }
        h3 { font-size: \(h3)px; margin: 1.2em 0 0.4em; font-weight: 600; }
        p { margin: 0 0 0.85em; }
        blockquote {
          margin: 1em 0;
          padding: 0.25em 0 0.25em 1em;
          border-left: 3px solid var(--accent);
          color: var(--muted);
        }
        ul, ol { margin: 0.5em 0 1em; padding-left: 1.5em; }
        li { margin: 0.25em 0; }
        pre, code {
          font-family: \"Menlo\", \"SF Mono\", monospace;
          font-size: 0.92em;
        }
        pre {
          background: #f4f4f5;
          padding: 1em 1.1em;
          border-radius: 6px;
          overflow-x: auto;
          margin: 1em 0;
        }
        code { background: #f4f4f5; padding: 0.12em 0.35em; border-radius: 4px; }
        pre code { background: none; padding: 0; }
        strong { font-weight: 600; }
        del { opacity: 0.65; }
        hr { border: none; border-top: 1px solid var(--border); margin: 2.5em 0; }
        @media print {
          body { padding: 0; max-width: none; }
          .toc { break-after: page; }
          .chapter { break-before: page; }
          .chapter:first-of-type { break-before: auto; }
        }
        """
    }

    var pdfPaperSize: NSSize {
        switch self {
        case .manuscript: NSSize(width: 612, height: 792) // US Letter
        default: NSSize(width: 595, height: 842) // A4
        }
    }

    var pdfMargins: NSEdgeInsets {
        switch self {
        case .minimal: NSEdgeInsets(top: 54, left: 54, bottom: 54, right: 54)
        case .manuscript: NSEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        default: NSEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        }
    }
}
