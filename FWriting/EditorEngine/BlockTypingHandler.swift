//
//  BlockTypingHandler.swift
//  FWriting
//

import AppKit

enum BlockTypingHandler {
    /// `true` = 允许系统默认处理；`false` = 已自行改写文本
    static func shouldChangeText(
        in textView: NSTextView,
        affectedRange: NSRange,
        replacement: String
    ) -> Bool {
        if replacement == "\n" {
            return handleNewline(in: textView, at: affectedRange)
        }
        if replacement.isEmpty {
            return handleDelete(in: textView, range: affectedRange)
        }
        prepareTypingAttributes(in: textView, affectedRange: affectedRange, replacement: replacement)
        if replacement == " " {
            return handleSpace(in: textView, at: affectedRange)
        }
        return true
    }

    private static func handleNewline(in textView: NSTextView, at range: NSRange) -> Bool {
        let ns = textView.string as NSString
        guard let lineContext = lineContext(in: ns, for: range) else { return true }
        let line = lineContext.text
        let type = BlockParser.blockType(forLine: line)

        switch type {
        case .list:
            if BlockParser.isEmptyStructuralLine(line) {
                return true
            }
            let bullet = BlockParser.listMarkerPrefix(in: line) ?? "- "
            replace(in: textView, range: range, with: "\n" + bullet)
            return false
        case .numberedList:
            if BlockParser.isEmptyStructuralLine(line) {
                return true
            }
            let next = (BlockParser.numberedValue(in: line) ?? 1) + 1
            replace(in: textView, range: range, with: "\n\(next). ")
            return false
        case .quote:
            if BlockParser.isEmptyStructuralLine(line) {
                return true
            }
            replace(in: textView, range: range, with: "\n> ")
            return false
        case .heading1, .heading2, .heading3:
            if BlockParser.contentText(in: line, type: type).isEmpty {
                return true
            }
            return true
        default:
            return true
        }
    }

    private static func handleDelete(in textView: NSTextView, range: NSRange) -> Bool {
        let ns = textView.string as NSString
        guard range.length <= 1,
              let lineContext = lineContext(in: ns, for: range) else { return true }

        let line = lineContext.text
        let type = BlockParser.blockType(forLine: line)

        guard type != .paragraph else { return true }

        if BlockParser.isEmptyStructuralLine(line) {
            clearLine(in: textView, lineRange: lineContext.range)
            return false
        }

        return true
    }

    private static func handleSpace(in textView: NSTextView, at range: NSRange) -> Bool {
        let ns = textView.string as NSString
        guard let lineContext = lineContext(in: ns, for: range) else { return true }
        let line = lineContext.text

        guard range.location == lineContext.range.location + (line as NSString).length else { return true }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "#" || trimmed == "##" || trimmed == "###" {
            return true
        }
        if trimmed == ">" || trimmed == "-" || trimmed == "*" || trimmed == "+" {
            return true
        }
        return true
    }

    private static func replace(in textView: NSTextView, range: NSRange, with string: String) {
        guard isValid(range, in: textView.string as NSString) else { return }
        textView.textStorage?.replaceCharacters(in: range, with: string)
        textView.didChangeText()
        let newLocation = range.location + (string as NSString).length
        let clampedLocation = min(max(newLocation, 0), (textView.string as NSString).length)
        textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
    }

    private static func clearLine(in textView: NSTextView, lineRange: NSRange) {
        var clearRange = lineRange
        let ns = textView.string as NSString
        guard isValid(clearRange, in: ns) else { return }

        if clearRange.length > 0 {
            let lastRange = NSRange(location: clearRange.upperBound - 1, length: 1)
            guard isValid(lastRange, in: ns) else { return }
            let last = ns.substring(with: lastRange)
            if last == "\n" {
                clearRange.length -= 1
            }
        }
        if clearRange.length == 0 {
            textView.setSelectedRange(NSRange(location: clearRange.location, length: 0))
            return
        }
        replace(in: textView, range: clearRange, with: "")
    }

    private static func prepareTypingAttributes(
        in textView: NSTextView,
        affectedRange: NSRange,
        replacement: String
    ) {
        guard !replacement.contains("\n") else { return }
        let ns = textView.string as NSString
        guard isValid(affectedRange, in: ns) else { return }

        let lineRange = ns.lineRange(for: affectedRange)
        guard isValid(lineRange, in: ns),
              affectedRange.location >= lineRange.location,
              affectedRange.upperBound <= lineRange.upperBound else { return }

        let line = ns.substring(with: lineRange).trimmingCharacters(in: CharacterSet.newlines)
        let localRange = NSRange(location: affectedRange.location - lineRange.location, length: affectedRange.length)
        let lineNS = line as NSString
        guard isValid(localRange, in: lineNS) else { return }

        let predictedLine = lineNS.replacingCharacters(in: localRange, with: replacement)
        let predictedType = BlockParser.blockType(forLine: predictedLine)
        let paragraph = EditorTypography.bodyParagraphStyle()

        if let level = BlockParser.headingLevel(for: predictedType) {
            let headingFont = EditorTypography.headingFont(level: level)
            if let marker = BlockParser.markerRange(in: predictedLine, type: predictedType),
               localRange.location < marker.upperBound {
                textView.typingAttributes = [
                    .font: EditorTypography.markerFont(),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                    .paragraphStyle: paragraph
                ]
            } else {
                textView.typingAttributes = [
                    .font: headingFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ]
            }
        } else {
            textView.typingAttributes = [
                .font: EditorTypography.bodyFont(),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        }
    }

    private static func lineContext(in text: NSString, for range: NSRange) -> (range: NSRange, text: String)? {
        guard isValid(range, in: text) else { return nil }
        let lineRange = text.lineRange(for: range)
        guard isValid(lineRange, in: text) else { return nil }
        let line = text.substring(with: lineRange).trimmingCharacters(in: CharacterSet.newlines)
        return (lineRange, line)
    }

    private static func isValid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length >= 0,
              range.location <= text.length else { return false }
        return range.length <= text.length - range.location
    }
}
