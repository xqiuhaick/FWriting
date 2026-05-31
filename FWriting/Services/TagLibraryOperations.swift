//
//  TagLibraryOperations.swift
//  FWriting
//

import SwiftData

enum TagLibraryOperations {
    @MainActor
    static func delete(_ tag: Tag, modelContext: ModelContext, appState: AppState) {
        for sheet in tag.sheets {
            sheet.tags.removeAll { $0.id == tag.id }
        }
        modelContext.delete(tag)
        try? modelContext.save()

        if case .tag(let id) = appState.librarySelection, id == tag.id {
            appState.librarySelection = .all
        }
    }
}
