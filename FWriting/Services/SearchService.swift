//
//  SearchService.swift
//  FWriting
//

import Foundation
import SwiftData

struct SearchResult: Identifiable {
    let id: UUID
    let sheet: Sheet
    let matchedField: String
    let snippet: String
}

enum SearchService {
    static func search(query: String, in sheets: [Sheet]) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        return sheets.compactMap { sheet in
            if sheet.title.lowercased().contains(q) {
                return SearchResult(id: sheet.id, sheet: sheet, matchedField: "标题", snippet: sheet.title)
            }
            if sheet.body.lowercased().contains(q) {
                return SearchResult(id: sheet.id, sheet: sheet, matchedField: "正文", snippet: snippet(from: sheet.body, matching: q))
            }
            return nil
        }
    }

    private static func snippet(from text: String, matching query: String) -> String {
        let lower = text.lowercased()
        guard let range = lower.range(of: query) else {
            return String(text.prefix(80))
        }
        let start = lower.index(range.lowerBound, offsetBy: -20, limitedBy: lower.startIndex) ?? lower.startIndex
        let end = lower.index(range.upperBound, offsetBy: 40, limitedBy: lower.endIndex) ?? lower.endIndex
        var result = String(text[start..<end])
        if start > lower.startIndex { result = "…" + result }
        if end < lower.endIndex { result += "…" }
        return result
    }
}
