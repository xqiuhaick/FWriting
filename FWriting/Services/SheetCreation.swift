//
//  SheetCreation.swift
//  FWriting
//

import Foundation
import SwiftData

enum SheetCreation {
    static func create(
        in modelContext: ModelContext,
        appState: AppState,
        kind: SheetKind? = nil
    ) {
        let sheetKind = kind ?? inferredKind(for: appState)
        let project = projectForCurrentSelection(in: modelContext, appState: appState)
        guard ProjectSecurity.isAccessible(project, appState: appState) else { return }
        let sheet = Sheet(title: "无标题", project: project)
        sheet.kind = sheetKind
        modelContext.insert(sheet)
        try? modelContext.save()
        appState.selectedSheetID = sheet.id
    }

    private static func inferredKind(for appState: AppState) -> SheetKind {
        switch appState.librarySelection {
        case .materials:
            return .material
        case .textSheets:
            return .text
        default:
            return .text
        }
    }

    private static func projectForCurrentSelection(
        in modelContext: ModelContext,
        appState: AppState
    ) -> Project? {
        guard case .project(let projectID) = appState.librarySelection else { return nil }
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
