//
//  AutoSaveService.swift
//  FWriting
//

import Foundation
import SwiftData

@MainActor
final class AutoSaveService {
    private var saveTask: Task<Void, Never>?

    func scheduleSave(
        sheet: Sheet,
        modelContext: ModelContext,
        appState: AppState,
        debounceSeconds: Double = 1.5
    ) {
        if appState.saveStatus != .saving {
            appState.saveStatus = .saving
        }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(debounceSeconds))
            guard !Task.isCancelled else { return }
            sheet.modifiedAt = .now
            createSnapshotIfNeeded(sheet: sheet, modelContext: modelContext)
            do {
                try modelContext.save()
                appState.saveStatus = .saved
            } catch {
                appState.saveStatus = .error(error.localizedDescription)
            }
        }
    }

    func saveImmediately(
        sheet: Sheet,
        modelContext: ModelContext,
        appState: AppState
    ) {
        saveTask?.cancel()
        sheet.modifiedAt = .now
        createSnapshotIfNeeded(sheet: sheet, modelContext: modelContext)
        do {
            try modelContext.save()
            appState.saveStatus = .saved
        } catch {
            appState.saveStatus = .error(error.localizedDescription)
        }
    }

    private func createSnapshotIfNeeded(sheet: Sheet, modelContext: ModelContext) {
        let recent = sheet.snapshots.sorted { $0.savedAt > $1.savedAt }
        if let last = recent.first {
            let interval = Date.now.timeIntervalSince(last.savedAt)
            if interval < 300, last.body == sheet.body, last.title == sheet.title { return }
        }
        let snapshot = SheetSnapshot(title: sheet.title, body: sheet.body, sheet: sheet)
        modelContext.insert(snapshot)
        let overflow = sheet.snapshots.sorted { $0.savedAt > $1.savedAt }.dropFirst(20)
        for old in overflow {
            modelContext.delete(old)
        }
    }
}
