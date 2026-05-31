//
//  BlockModel.swift
//  FWriting
//

import Foundation

enum BlockType: Equatable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case quote
    case list
    case numberedList
    case comment
    case code
}

struct Block: Equatable {
    var type: BlockType
    /// 不含块级标记的正文
    var text: String
    /// 原始行（含标记，不含换行）
    var rawLine: String
}

enum BlockParser {
    static func parse(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let type = blockType(forLine: line)
            blocks.append(Block(
                type: type,
                text: contentText(in: line, type: type),
                rawLine: line
            ))
        }
        return blocks
    }

    static func serialize(_ blocks: [Block]) -> String {
        blocks.map { block in
            if block.rawLine.isEmpty && block.text.isEmpty { return "" }
            if !block.rawLine.isEmpty { return block.rawLine }
            return prefix(for: block.type) + block.text
        }.joined(separator: "\n")
    }

    static func blockType(forLine line: String) -> BlockType {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if headingMarkerRange(in: line, level: 3) != nil { return .heading3 }
        if headingMarkerRange(in: line, level: 2) != nil { return .heading2 }
        if headingMarkerRange(in: line, level: 1) != nil { return .heading1 }
        if trimmed.hasPrefix("> ") { return .quote }
        if trimmed.hasPrefix("%% ") { return .comment }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") { return .list }
        if numberedMarkerRange(in: line) != nil { return .numberedList }
        if trimmed.hasPrefix("```") { return .code }
        if line.hasPrefix("    ") && !trimmed.isEmpty { return .code }
        return .paragraph
    }

    static func prefix(for type: BlockType) -> String {
        switch type {
        case .paragraph: ""
        case .heading1: "# "
        case .heading2: "## "
        case .heading3: "### "
        case .quote: "> "
        case .list: "- "
        case .numberedList: "1. "
        case .comment: "%% "
        case .code: "    "
        }
    }

    /// 行首数字列表标记（如 "12. "）的 UTF-16 范围，跳过行首空白。
    static func numberedMarkerRange(in line: String) -> NSRange? {
        let ns = line as NSString
        var index = 0
        while index < ns.length {
            let char = ns.substring(with: NSRange(location: index, length: 1))
            if char != " " && char != "\t" { break }
            index += 1
        }
        var digitsEnd = index
        while digitsEnd < ns.length {
            let char = ns.substring(with: NSRange(location: digitsEnd, length: 1))
            guard char.count == 1, let scalar = char.unicodeScalars.first,
                  CharacterSet.decimalDigits.contains(scalar) else { break }
            digitsEnd += 1
        }
        guard digitsEnd > index else { return nil }
        // 需要紧跟 ". "
        guard digitsEnd + 1 < ns.length,
              ns.substring(with: NSRange(location: digitsEnd, length: 1)) == ".",
              ns.substring(with: NSRange(location: digitsEnd + 1, length: 1)) == " " else { return nil }
        return NSRange(location: index, length: (digitsEnd - index) + 2)
    }

    /// 数字列表当前序号。
    static func numberedValue(in line: String) -> Int? {
        guard let range = numberedMarkerRange(in: line) else { return nil }
        let ns = line as NSString
        let marker = ns.substring(with: range)
        let digits = marker.prefix { $0.isNumber }
        return Int(digits)
    }

    static func listMarkerPrefix(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") { return "- " }
        if trimmed.hasPrefix("* ") { return "* " }
        if trimmed.hasPrefix("+ ") { return "+ " }
        return nil
    }

    static func contentText(in line: String, type: BlockType) -> String {
        guard let marker = markerRange(in: line, type: type) else { return line }
        let ns = line as NSString
        let start = marker.location + marker.length
        let length = max(0, ns.length - start)
        return ns.substring(with: NSRange(location: start, length: length))
    }

    /// 标记在整行字符串中的 UTF-16 范围（跳过行首空白）
    static func markerRange(in line: String, type: BlockType) -> NSRange? {
        if type == .numberedList { return numberedMarkerRange(in: line) }
        if let level = headingLevel(for: type) {
            return headingMarkerRange(in: line, level: level)
        }
        let prefix: String?
        switch type {
        case .list: prefix = listMarkerPrefix(in: line)
        default: prefix = Self.prefix(for: type).isEmpty ? nil : Self.prefix(for: type)
        }
        guard let prefix, !prefix.isEmpty else { return nil }
        let ns = line as NSString
        var index = 0
        while index < ns.length {
            let char = ns.substring(with: NSRange(location: index, length: 1))
            if char != " " && char != "\t" { break }
            index += 1
        }
        let prefixLen = (prefix as NSString).length
        guard index + prefixLen <= ns.length else { return nil }
        let candidate = ns.substring(with: NSRange(location: index, length: prefixLen))
        guard candidate == prefix else { return nil }
        return NSRange(location: index, length: prefixLen)
    }

    static func headingMarkerRange(in line: String, level: Int) -> NSRange? {
        guard (1...3).contains(level) else { return nil }
        let ns = line as NSString
        var index = 0
        while index < ns.length {
            let char = ns.substring(with: NSRange(location: index, length: 1))
            if char != " " && char != "\t" { break }
            index += 1
        }

        guard index + level <= ns.length else { return nil }
        let marker = String(repeating: "#", count: level)
        guard ns.substring(with: NSRange(location: index, length: level)) == marker else { return nil }

        let afterMarker = index + level
        if afterMarker < ns.length {
            let next = ns.substring(with: NSRange(location: afterMarker, length: 1))
            if next == "#" { return nil }
            let markerLength = (next == " " || next == "\t") ? level + 1 : level
            return NSRange(location: index, length: markerLength)
        }

        return NSRange(location: index, length: level)
    }

    static func markerRange(in line: String) -> NSRange? {
        markerRange(in: line, type: blockType(forLine: line))
    }

    /// 有结构标记但尚无正文（如 `# `、`- `、`> `）
    static func isEmptyStructuralLine(_ line: String) -> Bool {
        let type = blockType(forLine: line)
        switch type {
        case .paragraph, .code:
            return false
        default:
            return contentText(in: line, type: type).trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    static func firstHeadingTitle(in markdown: String, level: Int = 1) -> String? {
        let targetType: BlockType
        switch level {
        case 1: targetType = .heading1
        case 2: targetType = .heading2
        case 3: targetType = .heading3
        default: return nil
        }

        for line in markdown.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            guard blockType(forLine: line) == targetType else { return nil }
            let text = contentText(in: line, type: targetType)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return nil
    }

    static func headingLevel(for type: BlockType) -> Int? {
        switch type {
        case .heading1: 1
        case .heading2: 2
        case .heading3: 3
        default: nil
        }
    }
}
