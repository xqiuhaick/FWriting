//
//  SheetLibraryOperations.swift
//  FWriting
//

import Foundation
import SwiftData

enum SheetLibraryOperations {
    static func splitAtSelection(
        sheet: Sheet,
        selectedRange: NSRange?,
        modelContext: ModelContext
    ) -> Sheet? {
        let body = sheet.body as NSString
        let location = selectedRange?.location ?? body.length
        guard location > 0, location < body.length else { return nil }

        let splitRange = body.paragraphRange(for: NSRange(location: location, length: 0))
        let splitLocation = max(1, min(splitRange.location, body.length - 1))
        let before = body.substring(to: splitLocation).trimmingCharacters(in: .whitespacesAndNewlines)
        let after = body.substring(from: splitLocation).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !before.isEmpty, !after.isEmpty else { return nil }

        sheet.body = before
        sheet.modifiedAt = .now

        let newSheet = Sheet(
            title: nextTitle(after: sheet.title),
            body: after,
            project: sheet.project,
            sortOrder: sheet.sortOrder + 1
        )
        newSheet.kind = sheet.kind
        modelContext.insert(newSheet)
        try? modelContext.save()
        return newSheet
    }

    static func merge(_ sheets: [Sheet], modelContext: ModelContext) -> Sheet? {
        let ordered = sheets
            .filter { !$0.isTrashed }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard ordered.count > 1, let first = ordered.first else { return nil }

        let mergedBody = ordered
            .map { $0.body.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        first.body = mergedBody
        first.title = first.title.isEmpty ? "合并文稿" : first.title
        first.modifiedAt = .now

        for sheet in ordered.dropFirst() {
            modelContext.delete(sheet)
        }

        try? modelContext.save()
        return first
    }

    static func glue(_ sheets: [Sheet], modelContext: ModelContext) -> Sheet? {
        let ordered = sheets
            .filter { !$0.isTrashed }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard ordered.count > 1, let first = ordered.first else { return nil }

        first.isGluedToPrevious = false
        for sheet in ordered.dropFirst() {
            sheet.isGluedToPrevious = true
            sheet.modifiedAt = .now
        }
        first.modifiedAt = .now
        try? modelContext.save()
        return first
    }

    private static func nextTitle(after title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "拆分文稿" : "\(trimmed) 续"
    }
}
