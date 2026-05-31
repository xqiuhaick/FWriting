//
//  SheetListView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct SheetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var appState: AppState

    @Query(sort: \Sheet.modifiedAt, order: .reverse) private var allSheets: [Sheet]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]

    @State private var sortOrder: SortOrder = .modifiedNewest
    @State private var kindFilter: SheetKind?

    enum SortOrder: String, CaseIterable, Identifiable {
        case manual = "手动排序"
        case modifiedNewest = "最近修改"
        case modifiedOldest = "最早修改"
        case title = "标题"

        var id: String { rawValue }
    }

    private var filteredSheets: [Sheet] {
        var sheets = allSheets

        switch appState.librarySelection {
        case .all:
            sheets = sheets.filter { isUnprojected($0) && !$0.isTrashed }
        case .textSheets:
            sheets = sheets.filter { isUnprojected($0) && $0.kind == .text && !$0.isTrashed }
        case .materials:
            sheets = sheets.filter { isUnprojected($0) && $0.kind == .material && !$0.isTrashed }
        case .favorites:
            sheets = sheets.filter { isUnprojected($0) && $0.isFavorite && !$0.isTrashed }
        case .recent:
            sheets = sheets.filter { isUnprojected($0) && !$0.isTrashed }.prefix(30).map { $0 }
        case .trash:
            sheets = sheets.filter { $0.isTrashed }
        case .tag(let id):
            sheets = sheets.filter { !$0.isTrashed && $0.tags.contains(where: { $0.id == id }) }
        case .project(let id):
            if let project = projects.first(where: { $0.id == id }) {
                sheets = LibraryMetrics.sheets(for: project, projects: projects, sheets: sheets)
            } else {
                sheets = []
            }
        }

        if let kindFilter {
            sheets = sheets.filter { $0.kind == kindFilter }
        }

        if !appState.searchText.isEmpty {
            let results = SearchService.search(query: appState.searchText, in: sheets)
            let ids = Set(results.map(\.sheet.id))
            sheets = sheets.filter { ids.contains($0.id) }
        }

        switch sortOrder {
        case .manual:
            sheets.sort {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
        case .modifiedNewest:
            sheets.sort { $0.modifiedAt > $1.modifiedAt }
        case .modifiedOldest:
            sheets.sort { $0.modifiedAt < $1.modifiedAt }
        case .title:
            sheets.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        }

        return sheets
    }

    private func isUnprojected(_ sheet: Sheet) -> Bool {
        sheet.project == nil
    }

    private var selectedProject: Project? {
        guard case .project(let id) = appState.librarySelection else { return nil }
        return projects.first { $0.id == id }
    }

    private var lockedProject: Project? {
        guard let project = selectedProject,
              let protectedProject = ProjectSecurity.protectingProject(for: project),
              !appState.isProjectUnlocked(protectedProject.id)
        else { return nil }
        return protectedProject
    }

    private var listTitle: String {
        switch appState.librarySelection {
        case .all: "全部文稿"
        case .textSheets: "正文"
        case .materials: "资料库"
        case .favorites: "收藏"
        case .recent: "最近编辑"
        case .trash: "废纸篓"
        case .tag(let id):
            tags.first(where: { $0.id == id })?.displayName ?? "标签"
        case .project(let id):
            projects.first(where: { $0.id == id })?.name ?? "项目"
        }
    }

    private var emptyStateCreateTitle: String {
        appState.librarySelection == .materials ? "新建资料" : "新建文稿"
    }

    private var emptyStateDescription: String {
        switch appState.librarySelection {
        case .trash:
            return "废纸篓是空的"
        case .tag:
            return "为文稿添加标签后，会显示在这里"
        case .materials:
            return "点击工具栏新建按钮，或下方按钮创建资料"
        default:
            return "点击工具栏新建按钮开始写作"
        }
    }

    var body: some View {
        Group {
            if let lockedProject {
                lockedProjectView(lockedProject)
            } else if filteredSheets.isEmpty {
                ContentUnavailableView {
                    Label("暂无文稿", systemImage: "doc.text")
                } description: {
                    Text(emptyStateDescription)
                } actions: {
                    if appState.librarySelection != .trash {
                        Button(emptyStateCreateTitle) {
                            SheetCreation.create(in: modelContext, appState: appState)
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    if case .project = appState.librarySelection {
                        projectSummary
                    }

                    List(selection: $appState.selectedSheetID) {
                        ForEach(filteredSheets) { sheet in
                            SheetRowView(sheet: sheet)
                                .tag(sheet.id)
                                .draggable(SheetTransferable(sheetID: sheet.id))
                                .dropDestination(for: SheetTransferable.self) { items, location in
                                    reorderDroppedSheets(items, near: sheet, dropLocation: location)
                                }
                                .contextMenu { sheetContextMenu(for: sheet) }
                        }
                        .onMove(perform: moveSheets)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle(listTitle)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("全部") { kindFilter = nil }
                    Button("正文") { kindFilter = .text }
                    Button("资料") { kindFilter = .material }
                } label: {
                    Image(systemName: kindFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .help("筛选正文 / 资料")
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("排序", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("排序")
            }
        }
        .onChange(of: appState.librarySelection.id) { _, _ in
            if lockedProject != nil {
                appState.selectedSheetID = nil
            }
            switch appState.librarySelection {
            case .materials, .textSheets:
                kindFilter = nil
            default:
                break
            }
        }
        .onChange(of: filteredSheets.map(\.id)) { _, ids in
            if lockedProject != nil {
                appState.selectedSheetID = nil
                return
            }
            if let selected = appState.selectedSheetID, !ids.contains(selected) {
                appState.selectedSheetID = ids.first
            } else if appState.selectedSheetID == nil {
                appState.selectedSheetID = ids.first
            }
        }
        .onAppear {
            if lockedProject != nil {
                appState.selectedSheetID = nil
            } else if appState.selectedSheetID == nil {
                appState.selectedSheetID = filteredSheets.first?.id
            }
        }
    }

    private func lockedProjectView(_ project: Project) -> some View {
        ContentUnavailableView {
            Label("项目已加密", systemImage: "lock.fill")
        } description: {
            Text("输入密码或使用指纹解锁后查看文稿")
        } actions: {
            Button("解锁项目") {
                ProjectSecurityUI.unlock(project, appState: appState)
            }
        }
    }

    @ViewBuilder
    private var projectSummary: some View {
        if case .project(let id) = appState.librarySelection,
           let project = projects.first(where: { $0.id == id }) {
            let metrics = LibraryMetrics.metrics(for: project, projects: projects, sheets: allSheets)
            HStack(spacing: 10) {
                Label("\(metrics.textSheetCount) 篇正文", systemImage: "doc.text")
                Label("\(metrics.materialSheetCount) 份资料", systemImage: "paperclip")
                Label("\(WritingStatsService.formattedWordCount(metrics.wordCount)) 字", systemImage: "textformat.size")
                if let goal = project.wordGoal, goal > 0 {
                    ProgressView(value: Double(metrics.wordCount), total: Double(goal))
                        .frame(width: 72)
                    Text("\(Int((metrics.progress(goal: goal) ?? 0) * 100))%")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    @ViewBuilder
    private func sheetContextMenu(for sheet: Sheet) -> some View {
        Button(sheet.isFavorite ? "取消收藏" : "收藏") {
            sheet.isFavorite.toggle()
            try? modelContext.save()
        }
        Menu("移动到项目") {
            Button("无项目") { sheet.project = nil; try? modelContext.save() }
            ForEach(projects) { project in
                Button(project.name) {
                    sheet.project = project
                    try? modelContext.save()
                }
            }
        }
        Menu("类型") {
            Button("正文") {
                sheet.kind = .text
                try? modelContext.save()
            }
            Button("资料") {
                sheet.kind = .material
                try? modelContext.save()
            }
        }
        if !tags.isEmpty {
            Menu("标签") {
                ForEach(tags.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { tag in
                    let isAssigned = sheet.tags.contains(where: { $0.id == tag.id })
                    Button(isAssigned ? "移除 \(tag.displayName)" : "添加 \(tag.displayName)") {
                        if isAssigned {
                            sheet.tags.removeAll { $0.id == tag.id }
                            tag.sheets.removeAll { $0.id == sheet.id }
                        } else {
                            sheet.tags.append(tag)
                            if !tag.sheets.contains(where: { $0.id == sheet.id }) {
                                tag.sheets.append(sheet)
                            }
                        }
                        try? modelContext.save()
                    }
                }
            }
        }
        Divider()
        Button("从光标处拆分") {
            if let newSheet = SheetLibraryOperations.splitAtSelection(
                sheet: sheet,
                selectedRange: EditorFocusState.shared.selectedRange,
                modelContext: modelContext
            ) {
                appState.selectedSheetID = newSheet.id
            }
        }
        .disabled(sheet.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if case .project = appState.librarySelection, filteredSheets.count > 1 {
            Button("合并当前列表文稿") {
                if let merged = SheetLibraryOperations.merge(filteredSheets, modelContext: modelContext) {
                    appState.selectedSheetID = merged.id
                }
            }
            Button("粘连当前列表文稿") {
                if let glued = SheetLibraryOperations.glue(filteredSheets, modelContext: modelContext) {
                    appState.selectedSheetID = glued.id
                }
            }
        }
        Divider()
        if sheet.isTrashed {
            Button("恢复") {
                sheet.isTrashed = false
                try? modelContext.save()
            }
            Button("永久删除", role: .destructive) {
                modelContext.delete(sheet)
                try? modelContext.save()
            }
        } else {
            Button("移到废纸篓", role: .destructive) {
                sheet.isTrashed = true
                try? modelContext.save()
            }
        }
    }

    private func moveSheets(from source: IndexSet, to destination: Int) {
        var ordered = filteredSheets
        ordered.move(fromOffsets: source, toOffset: destination)
        applyManualOrder(ordered)
    }

    private func reorderDroppedSheets(
        _ items: [SheetTransferable],
        near target: Sheet,
        dropLocation: CGPoint
    ) -> Bool {
        guard let item = items.first,
              item.sheetID != target.id,
              let dragged = allSheets.first(where: { $0.id == item.sheetID }),
              filteredSheets.contains(where: { $0.id == dragged.id })
        else { return false }

        var ordered = filteredSheets.filter { $0.id != dragged.id }
        guard let targetIndex = ordered.firstIndex(where: { $0.id == target.id }) else { return false }

        let insertIndex = dropLocation.y > 56 ? targetIndex + 1 : targetIndex
        ordered.insert(dragged, at: min(insertIndex, ordered.count))
        applyManualOrder(ordered)
        appState.selectedSheetID = dragged.id
        return true
    }

    private func applyManualOrder(_ ordered: [Sheet]) {
        sortOrder = .manual
        for (index, sheet) in ordered.enumerated() {
            sheet.sortOrder = index
        }
        try? modelContext.save()
    }
}
