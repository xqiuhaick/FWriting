//
//  AppState.swift
//  FWriting
//

import Foundation
import Observation
import SwiftUI

enum SaveStatus: Equatable {
    case saved
    case saving
    case error(String)

    var label: String {
        switch self {
        case .saved: "已保存"
        case .saving: "保存中…"
        case .error: "保存失败"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case stats
    case outline
    case goal
    case characters
    case tags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: "统计"
        case .outline: "摘要"
        case .goal: "目标"
        case .characters: "人物"
        case .tags: "标签"
        }
    }

    var icon: String {
        switch self {
        case .stats: "chart.bar"
        case .outline: "text.alignleft"
        case .goal: "target"
        case .characters: "person.2"
        case .tags: "tag"
        }
    }
}

@Observable
final class AppState {
    var librarySelection: LibrarySelection = .all
    var selectedSheetID: UUID?
    var searchText = ""
    var isFocusMode = false
    var isShowingExportPanel = false
    var isShowingInspector = false
    var inspectorTab: InspectorTab = .stats
    var saveStatus: SaveStatus = .saved
    var columnVisibility: NavigationSplitViewVisibility = .all
    private var unlockedProjectIDs: Set<UUID> = []
    private var previousColumnVisibility: NavigationSplitViewVisibility?

    func isProjectUnlocked(_ id: UUID) -> Bool {
        unlockedProjectIDs.contains(id)
    }

    func unlockProject(_ id: UUID) {
        unlockedProjectIDs.insert(id)
    }

    func lockProject(_ id: UUID) {
        unlockedProjectIDs.remove(id)
        if case .project(let selectedID) = librarySelection, selectedID == id {
            selectedSheetID = nil
        }
    }

    func enterFocusMode() {
        withAnimation {
            previousColumnVisibility = columnVisibility
            columnVisibility = .detailOnly
            isFocusMode = true
        }
    }

    func exitFocusMode() {
        withAnimation {
            columnVisibility = previousColumnVisibility ?? .all
            isFocusMode = false
            previousColumnVisibility = nil
        }
    }
}
