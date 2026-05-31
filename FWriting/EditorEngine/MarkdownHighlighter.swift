//
//  MarkdownHighlighter.swift
//  FWriting
//

import AppKit

enum MarkdownHighlighter {
    private static func markerAttributes(font: NSFont = EditorTypography.markerFont()) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.tertiaryLabelColor,
            .font: font
        ]
    }

    static func apply(to textStorage: NSTextStorage, typography: EditorTypography, hideMarkers: Bool = true) {
        applyHighlighting(to: textStorage, typography: typography, hideMarkers: hideMarkers)
    }

    static func apply(to attributedString: NSMutableAttributedString, typography: EditorTypography, hideMarkers: Bool = true) {
        if let textStorage = attributedString as? NSTextStorage {
            applyHighlighting(to: textStorage, typography: typography, hideMarkers: hideMarkers)
        } else {
            let textStorage = NSTextStorage(attributedString: attributedString)
            applyHighlighting(to: textStorage, typography: typography, hideMarkers: hideMarkers)
            attributedString.setAttributedString(textStorage)
        }
    }

    private static func applyHighlighting(to textStorage: NSTextStorage, typography: EditorTypography, hideMarkers: Bool) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let bodyFont = EditorTypography.bodyFont()
        let paragraph = EditorTypography.bodyParagraphStyle()

        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ], range: fullRange)

        let text = textStorage.string as NSString
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: .byLines) { substring, range, _, _ in
            guard let line = substring else { return }
            let blockType = BlockParser.blockType(forLine: line)

            switch blockType {
            case .heading1:
                styleBlock(textStorage, line: line, lineRange: range, level: 1, paragraph: paragraph, hideMarkers: hideMarkers)
            case .heading2:
                styleBlock(textStorage, line: line, lineRange: range, level: 2, paragraph: paragraph, hideMarkers: hideMarkers)
            case .heading3:
                styleBlock(textStorage, line: line, lineRange: range, level: 3, paragraph: paragraph, hideMarkers: hideMarkers)
            case .quote:
                styleQuote(textStorage, line: line, lineRange: range, paragraph: paragraph, hideMarkers: hideMarkers)
            case .list:
                styleList(textStorage, line: line, lineRange: range, paragraph: paragraph, hideMarkers: hideMarkers)
            case .numberedList:
                // 数字列表保留序号可见，仅用正文段落样式。
                textStorage.addAttributes([
                    .font: EditorTypography.bodyFont(),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ], range: range)
            case .comment:
                styleComment(textStorage, line: line, lineRange: range, paragraph: paragraph, hideMarkers: hideMarkers)
            case .code:
                styleCode(textStorage, lineRange: range, paragraph: paragraph, hideMarkers: hideMarkers, line: line)
            case .paragraph:
                break
            }

            applyInlineStyles(to: textStorage, in: range, paragraph: paragraph)
        }
        textStorage.endEditing()
    }

    private static func styleBlock(
        _ textStorage: NSTextStorage,
        line: String,
        lineRange: NSRange,
        level: Int,
        paragraph: NSParagraphStyle,
        hideMarkers: Bool
    ) {
        let blockType: BlockType = level == 1 ? .heading1 : (level == 2 ? .heading2 : .heading3)
        let headingFont = EditorTypography.headingFont(level: level)

        if hideMarkers, let marker = BlockParser.markerRange(in: line, type: blockType) {
            let globalMarker = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttributes(markerAttributes(), range: globalMarker)
            let contentStart = globalMarker.upperBound
            let contentLength = max(0, lineRange.upperBound - contentStart)
            if contentLength > 0 {
                textStorage.addAttributes([
                    .font: headingFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ], range: NSRange(location: contentStart, length: contentLength))
            }
        } else {
            textStorage.addAttributes([
                .font: headingFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ], range: lineRange)
        }
    }

    private static func styleQuote(
        _ textStorage: NSTextStorage,
        line: String,
        lineRange: NSRange,
        paragraph: NSParagraphStyle,
        hideMarkers: Bool
    ) {
        if hideMarkers, let marker = BlockParser.markerRange(in: line, type: .quote) {
            let globalMarker = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttributes(markerAttributes(), range: globalMarker)
            let contentStart = globalMarker.upperBound
            let contentLength = max(0, lineRange.upperBound - contentStart)
            if contentLength > 0 {
                textStorage.addAttributes([
                    .font: EditorTypography.bodyFont(),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraph
                ], range: NSRange(location: contentStart, length: contentLength))
            }
        } else {
            textStorage.addAttributes([
                .font: EditorTypography.bodyFont(),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ], range: lineRange)
        }
    }

    private static func styleComment(
        _ textStorage: NSTextStorage,
        line: String,
        lineRange: NSRange,
        paragraph: NSParagraphStyle,
        hideMarkers: Bool
    ) {
        if hideMarkers, let marker = BlockParser.markerRange(in: line, type: .comment) {
            let globalMarker = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttributes(markerAttributes(), range: globalMarker)
            let contentStart = globalMarker.upperBound
            let contentLength = max(0, lineRange.upperBound - contentStart)
            if contentLength > 0 {
                textStorage.addAttributes([
                    .font: EditorTypography.bodyFont(),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                    .paragraphStyle: paragraph
                ], range: NSRange(location: contentStart, length: contentLength))
            }
        } else {
            textStorage.addAttributes([
                .font: EditorTypography.bodyFont(),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: paragraph
            ], range: lineRange)
        }
    }

    private static func styleList(
        _ textStorage: NSTextStorage,
        line: String,
        lineRange: NSRange,
        paragraph: NSParagraphStyle,
        hideMarkers: Bool
    ) {
        if hideMarkers, let marker = BlockParser.markerRange(in: line, type: .list) {
            let globalMarker = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttributes(markerAttributes(), range: globalMarker)
            let contentStart = globalMarker.upperBound
            let contentLength = max(0, lineRange.upperBound - contentStart)
            if contentLength > 0 {
                textStorage.addAttributes([
                    .font: EditorTypography.bodyFont(),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ], range: NSRange(location: contentStart, length: contentLength))
            }
        } else {
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: lineRange)
        }
    }

    private static func styleCode(
        _ textStorage: NSTextStorage,
        lineRange: NSRange,
        paragraph: NSParagraphStyle,
        hideMarkers: Bool,
        line: String
    ) {
        let codeFont = NSFont.monospacedSystemFont(ofSize: EditorTypographySpec.codeFontSize, weight: .regular)
        if hideMarkers, let marker = BlockParser.markerRange(in: line, type: .code) {
            let globalMarker = NSRange(location: lineRange.location + marker.location, length: marker.length)
            textStorage.addAttributes(markerAttributes(font: codeFont), range: globalMarker)
            let contentStart = globalMarker.upperBound
            let contentLength = max(0, lineRange.upperBound - contentStart)
            if contentLength > 0 {
                textStorage.addAttributes([
                    .font: codeFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph,
                    .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.2)
                ], range: NSRange(location: contentStart, length: contentLength))
            }
        } else {
            textStorage.addAttributes([
                .font: codeFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.2)
            ], range: lineRange)
        }
    }

    private static func applyInlineStyles(
        to textStorage: NSTextStorage,
        in lineRange: NSRange,
        paragraph: NSParagraphStyle
    ) {
        let line = (textStorage.string as NSString).substring(with: lineRange)
        let bodySize = EditorTypographySpec.bodyFontSize

        applyPattern("\\*\\*(.+?)\\*\\*", in: line, lineRange: lineRange, storage: textStorage) { matchRange in
            textStorage.addAttributes([
                .font: NSFont.systemFont(ofSize: bodySize, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ], range: matchRange)
        }

        applyPattern("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", in: line, lineRange: lineRange, storage: textStorage) { matchRange in
            textStorage.addAttributes([
                .font: NSFontManager.shared.convert(EditorTypography.bodyFont(), toHaveTrait: .italicFontMask),
                .foregroundColor: NSColor.labelColor
            ], range: matchRange)
        }

        applyPattern("`(.+?)`", in: line, lineRange: lineRange, storage: textStorage) { matchRange in
            textStorage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: EditorTypographySpec.codeFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.25)
            ], range: matchRange)
        }

        applyPattern("~~(.+?)~~", in: line, lineRange: lineRange, storage: textStorage) { matchRange in
            textStorage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: matchRange)
        }
    }

    private static func applyPattern(
        _ pattern: String,
        in line: String,
        lineRange: NSRange,
        storage: NSTextStorage,
        apply: (NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let nsLine = line as NSString
        regex.enumerateMatches(in: line, range: NSRange(location: 0, length: nsLine.length)) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            let contentRange = match.range(at: 1)
            let globalRange = NSRange(location: lineRange.location + contentRange.location, length: contentRange.length)
            apply(globalRange)
        }
    }
}
