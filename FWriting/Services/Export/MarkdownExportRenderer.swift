//
//  MarkdownExportRenderer.swift
//  FWriting
//

import AppKit
import Foundation

enum MarkdownExportRenderer {
    // MARK: - Table of contents

    static func tableOfContents(for document: ExportDocument) -> [ExportTOCEntry] {
        var entries: [ExportTOCEntry] = []
        if document.chapters.count > 1, document.options.chapterPerSheet {
            for (index, chapter) in document.chapters.enumerated() {
                let anchor = "chapter-\(index)"
                entries.append(ExportTOCEntry(
                    id: anchor,
                    title: chapter.title,
                    level: 1,
                    anchor: anchor
                ))
            }
        }
        for (chapterIndex, chapter) in document.chapters.enumerated() {
            let blocks = BlockParser.parse(chapter.body)
            var headingIndex = 0
            for block in blocks {
                guard let level = BlockParser.headingLevel(for: block.type) else { continue }
                let text = block.text.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { continue }
                let anchor = "h-\(chapterIndex)-\(headingIndex)"
                headingIndex += 1
                entries.append(ExportTOCEntry(
                    id: anchor,
                    title: inlinePlainText(text),
                    level: document.chapters.count > 1 ? level + 1 : level,
                    anchor: anchor
                ))
            }
        }
        return entries
    }

    // MARK: - HTML

    static func renderHTML(document: ExportDocument) -> String {
        let options = document.options
        let css = options.style.css(bodySize: options.bodyFontSize, maxWidth: options.maxWidth)
        var bodyParts: [String] = []

        if options.includeTitlePage {
            bodyParts.append(titlePageHTML(document: document))
        }

        if options.includeTableOfContents {
            let toc = tableOfContents(for: document)
            if !toc.isEmpty {
                bodyParts.append(tocHTML(entries: toc))
            }
        }

        for (chapterIndex, chapter) in document.chapters.enumerated() {
            if document.chapters.count > 1, options.chapterPerSheet {
                let anchor = "chapter-\(chapterIndex)"
                bodyParts.append("""
                <section class="chapter" id="\(anchor)">
                  <h1 class="chapter-title">\(escapeHTML(chapter.title))</h1>
                """)
            }
            bodyParts.append(blocksHTML(
                BlockParser.parse(chapter.body),
                chapterIndex: chapterIndex,
                includeComments: options.includeComments
            ))
            if document.chapters.count > 1, options.chapterPerSheet {
                bodyParts.append("</section>")
            }
        }

        let title = escapeHTML(document.title)
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          <style>\(css)</style>
        </head>
        <body>
        \(bodyParts.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private static func titlePageHTML(document: ExportDocument) -> String {
        var meta: [String] = []
        if !document.options.author.isEmpty {
            meta.append(escapeHTML(document.options.author))
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.locale = Locale(identifier: "zh_CN")
        meta.append(dateFormatter.string(from: .now))
        let metaHTML = meta.map { "<div>\($0)</div>" }.joined()
        let subtitle = document.subtitle.map { "<p class=\"meta\">\(escapeHTML($0))</p>" } ?? ""
        return """
        <header class="title-page">
          <h1>\(escapeHTML(document.title))</h1>
          \(subtitle)
          <div class="meta">\(metaHTML)</div>
        </header>
        """
    }

    private static func tocHTML(entries: [ExportTOCEntry]) -> String {
        let items = entries.map { entry in
            let indent = max(0, entry.level - 1)
            return "<li style=\"margin-left: \(indent * 12)px\"><a href=\"#\(entry.anchor)\">\(escapeHTML(entry.title))</a></li>"
        }.joined(separator: "\n")
        return """
        <nav class="toc" aria-label="目录">
          <h2>目录</h2>
          <ol>
          \(items)
          </ol>
        </nav>
        """
    }

    private static func blocksHTML(
        _ blocks: [Block],
        chapterIndex: Int,
        includeComments: Bool
    ) -> String {
        var html: [String] = []
        var index = 0
        var headingCounter = 0

        while index < blocks.count {
            let block = blocks[index]
            if block.type == .comment, !includeComments {
                index += 1
                continue
            }

            if block.type == .list {
                var items: [Block] = []
                while index < blocks.count, blocks[index].type == .list {
                    items.append(blocks[index])
                    index += 1
                }
                let lis = items.map { "<li>\(inlineHTML($0.text))</li>" }.joined()
                html.append("<ul>\(lis)</ul>")
                continue
            }

            if block.type == .numberedList {
                var items: [Block] = []
                while index < blocks.count, blocks[index].type == .numberedList {
                    items.append(blocks[index])
                    index += 1
                }
                let lis = items.map { "<li>\(inlineHTML($0.text))</li>" }.joined()
                html.append("<ol>\(lis)</ol>")
                continue
            }

            if block.type == .code {
                var lines: [String] = []
                while index < blocks.count, blocks[index].type == .code {
                    lines.append(blocks[index].text)
                    index += 1
                }
                let code = escapeHTML(lines.joined(separator: "\n"))
                html.append("<pre><code>\(code)</code></pre>")
                continue
            }

            switch block.type {
            case .heading1, .heading2, .heading3:
                let level = BlockParser.headingLevel(for: block.type) ?? 1
                let tag = "h\(level)"
                let anchor = "h-\(chapterIndex)-\(headingCounter)"
                headingCounter += 1
                html.append("<\(tag) id=\"\(anchor)\">\(inlineHTML(block.text))</\(tag)>")
            case .quote:
                html.append("<blockquote><p>\(inlineHTML(block.text))</p></blockquote>")
            case .comment:
                html.append("<p class=\"comment\"><em>\(inlineHTML(block.text))</em></p>")
            case .paragraph:
                if block.rawLine.isEmpty && block.text.isEmpty {
                    html.append("<p>&nbsp;</p>")
                } else {
                    html.append("<p>\(inlineHTML(block.text.isEmpty ? block.rawLine : block.text))</p>")
                }
            default:
                html.append("<p>\(inlineHTML(block.text))</p>")
            }
            index += 1
        }
        return html.joined(separator: "\n")
    }

    // MARK: - Plain text / Markdown

    static func renderPlainText(document: ExportDocument, includeTitles: Bool = true) -> String {
        var parts: [String] = []
        if includeTitles, document.options.includeTitlePage {
            parts.append(document.title)
            parts.append("")
        }
        for chapter in document.chapters {
            if document.chapters.count > 1, !chapter.isGluedToPrevious {
                parts.append(chapter.title)
                parts.append(String(repeating: "─", count: min(40, chapter.title.count + 4)))
                parts.append("")
            }
            let blocks = BlockParser.parse(chapter.body)
            for block in blocks {
                if block.type == .comment, !document.options.includeComments { continue }
                let line = plainLine(for: block)
                parts.append(line)
            }
            parts.append("")
        }
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    static func renderMarkdown(document: ExportDocument) -> String {
        var parts: [String] = []
        if document.options.includeTitlePage {
            parts.append("# \(document.title)")
            parts.append("")
        }
        if document.options.includeTableOfContents {
            let toc = tableOfContents(for: document)
            if !toc.isEmpty {
                parts.append("## 目录")
                for entry in toc {
                    let indent = String(repeating: "  ", count: max(0, entry.level - 1))
                    parts.append("\(indent)- [\(entry.title)](#\(entry.anchor))")
                }
                parts.append("")
            }
        }
        parts.append(document.combinedMarkdown)
        return parts.joined(separator: "\n")
    }

    private static func plainLine(for block: Block) -> String {
        switch block.type {
        case .paragraph:
            return inlinePlainText(block.rawLine)
        case .heading1, .heading2, .heading3:
            let level = BlockParser.headingLevel(for: block.type) ?? 1
            return String(repeating: "#", count: level) + " " + inlinePlainText(block.text)
        case .quote:
            return "> " + inlinePlainText(block.text)
        case .list:
            return "- " + inlinePlainText(block.text)
        case .numberedList:
            if let value = BlockParser.numberedValue(in: block.rawLine) {
                return "\(value). " + inlinePlainText(block.text)
            }
            return inlinePlainText(block.rawLine)
        case .comment:
            return "%% " + inlinePlainText(block.text)
        case .code:
            return block.text
        }
    }

    // MARK: - Attributed string (PDF / RTF / pasteboard)

    static func renderAttributedString(document: ExportDocument) -> NSAttributedString {
        let storage = NSMutableAttributedString()
        let options = document.options
        let style = options.style
        let bodySize = options.bodyFontSize
        let bodyParagraph = bodyParagraphStyle(style: style)

        if options.includeTitlePage {
            let titleAttr = NSAttributedString(
                string: document.title + "\n\n",
                attributes: [
                    .font: style.headingFont(level: 1, bodySize: bodySize + 4),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: centeredParagraph()
                ]
            )
            storage.append(titleAttr)
            if !options.author.isEmpty {
                storage.append(NSAttributedString(
                    string: options.author + "\n",
                    attributes: [
                        .font: style.bodyFont(size: bodySize - 1),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: centeredParagraph()
                    ]
                ))
            }
            storage.append(NSAttributedString(string: "\n", attributes: [.font: style.bodyFont(size: bodySize)]))
        }

        if options.includeTableOfContents {
            let toc = tableOfContents(for: document)
            if !toc.isEmpty {
                storage.append(NSAttributedString(
                    string: "目录\n",
                    attributes: [
                        .font: style.headingFont(level: 2, bodySize: bodySize),
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: bodyParagraph
                    ]
                ))
                for entry in toc {
                    let prefix = String(repeating: "  ", count: max(0, entry.level - 1))
                    storage.append(NSAttributedString(
                        string: "\(prefix)• \(entry.title)\n",
                        attributes: [
                            .font: style.bodyFont(size: bodySize - 1),
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .paragraphStyle: bodyParagraph
                        ]
                    ))
                }
                storage.append(NSAttributedString(string: "\n", attributes: [.font: style.bodyFont(size: bodySize)]))
            }
        }

        for chapter in document.chapters {
            if document.chapters.count > 1, options.chapterPerSheet, !chapter.isGluedToPrevious {
                storage.append(NSAttributedString(
                    string: chapter.title + "\n\n",
                    attributes: [
                        .font: style.headingFont(level: 1, bodySize: bodySize),
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: bodyParagraph
                    ]
                ))
            }
            let chapterStorage = NSMutableAttributedString(string: chapter.body)
            MarkdownHighlighter.apply(
                to: chapterStorage,
                typography: EditorTypography(maxWidth: options.maxWidth),
                hideMarkers: true
            )
            applyExportStyleOverrides(to: chapterStorage, style: style, bodySize: bodySize)
            storage.append(chapterStorage)
            if !chapter.body.hasSuffix("\n") {
                storage.append(NSAttributedString(string: "\n", attributes: [.font: style.bodyFont(size: bodySize)]))
            }
        }
        return storage
    }

    private static func applyExportStyleOverrides(
        to storage: NSMutableAttributedString,
        style: ExportStyle,
        bodySize: CGFloat
    ) {
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let size = font.pointSize
            let traits = font.fontDescriptor.symbolicTraits
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)
            let isMono = font.fontName.lowercased().contains("mono") || font.fontName.contains("Menlo")

            let replacement: NSFont
            if isMono {
                replacement = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            } else if size >= bodySize * 1.15 {
                let level: Int = size >= bodySize * 1.7 ? 1 : (size >= bodySize * 1.35 ? 2 : 3)
                replacement = style.headingFont(level: level, bodySize: bodySize)
            } else if isBold {
                replacement = NSFontManager.shared.convert(style.bodyFont(size: size), toHaveTrait: .boldFontMask)
            } else if isItalic {
                replacement = NSFontManager.shared.convert(style.bodyFont(size: size), toHaveTrait: .italicFontMask)
            } else {
                replacement = style.bodyFont(size: size)
            }
            storage.addAttribute(.font, value: replacement, range: range)
        }
    }

    private static func bodyParagraphStyle(style: ExportStyle) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = style == .manuscript ? 2.0 : EditorTypographySpec.lineHeightMultiple
        p.paragraphSpacing = style == .minimal ? 6 : EditorTypographySpec.paragraphSpacing
        return p
    }

    private static func centeredParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        p.paragraphSpacing = 8
        return p
    }

    // MARK: - Inline helpers

    static func inlineHTML(_ text: String) -> String {
        var result = escapeHTML(text)
        let patterns: [(String, (String) -> String)] = [
            (#"\*\*(.+?)\*\*"#, { "<strong>\(escapeHTML($0))</strong>" }),
            (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, { "<em>\(escapeHTML($0))</em>" }),
            (#"`(.+?)`"#, { "<code>\(escapeHTML($0))</code>" }),
            (#"~~(.+?)~~"#, { "<del>\(escapeHTML($0))</del>" })
        ]
        for (pattern, wrap) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed()
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let full = match.range(at: 0)
                let inner = match.range(at: 1)
                let content = ns.substring(with: inner)
                let replacement = wrap(content)
                result = (result as NSString).replacingCharacters(in: full, with: replacement)
            }
        }
        return result
    }

    static func inlinePlainText(_ text: String) -> String {
        var result = text
        let patterns = [
            #"\*\*(.+?)\*\*"#,
            #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#,
            #"`(.+?)`"#,
            #"~~(.+?)~~"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed()
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: ns.substring(with: match.range(at: 1)))
            }
        }
        return result
    }

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
