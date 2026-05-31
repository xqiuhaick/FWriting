//
//  SidebarView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var appState: AppState

    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]
    @Query private var allSheets: [Sheet]

    @State private var newProjectName = ""
    @State private var isShowingAddProjectSheet = false
    @State private var addingParent: Project?

    var body: some View {
        List(selection: $appState.librarySelection) {
            Section {
                sidebarRow(.all)
                sidebarRow(.textSheets)
                sidebarRow(.materials)
                sidebarRow(.favorites)
                sidebarRow(.recent)
                sidebarRow(.trash)
            }

            if !sortedTags.isEmpty {
                Section("标签") {
                    ForEach(sortedTags) { tag in
                        Label(tag.displayName, systemImage: "tag")
                            .tag(LibrarySelection.tag(tag.id))
                            .contextMenu {
                                Button("删除标签", role: .destructive) {
                                    TagLibraryOperations.delete(tag, modelContext: modelContext, appState: appState)
                                }
                            }
                    }
                }
            }

            Section("项目") {
                ForEach(rootProjects) { project in
                    ProjectSidebarRow(
                        project: project,
                        projects: projects,
                        allSheets: allSheets,
                        appState: appState,
                        onBeginAddingSubproject: { beginAddingProject(parent: $0, title: "新建子项目") },
                        onRename: renameProject,
                        onDelete: deleteProject,
                        onSetGoal: setProjectGoal,
                        onEnableEncryption: enableProjectEncryption,
                        onUnlockProject: unlockProject,
                        onLockProject: lockProject,
                        onDisableEncryption: disableProjectEncryption
                    )
                }

                Button {
                    beginAddingProject(parent: nil, title: "新建项目")
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

        }
        .listStyle(.sidebar)
        .background(.ultraThinMaterial)
        .navigationTitle("文档库")
        .sheet(isPresented: $isShowingAddProjectSheet) {
            addProjectSheet
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    beginAddingProject(parent: nil, title: "新建项目")
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(.secondary)
                }
                .help("新建项目")
            }
        }
    }

    private var rootProjects: [Project] {
        projects
            .filter { $0.parent == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedTags: [Tag] {
        tags.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    @ViewBuilder
    private func sidebarRow(_ selection: LibrarySelection) -> some View {
        Label {
            Text(selection.title)
        } icon: {
            Image(systemName: selection.icon)
                .foregroundStyle(.secondary)
        }
        .tag(selection)
    }

    private var addProjectSheet: some View {
        VStack(spacing: 16) {
            Text(addingParent == nil ? "新建项目" : "新建子项目")
                .font(.headline)
            TextField(addingParent == nil ? "项目名称" : "子项目名称", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack(spacing: 8) {
                Button("取消") {
                    newProjectName = ""
                    isShowingAddProjectSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Button("添加") { addProject() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    private func beginAddingProject(parent: Project?, title: String) {
        addingParent = parent
        newProjectName = ""
        isShowingAddProjectSheet = true
    }

    private func addProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let siblings = projects.filter { $0.parent?.id == addingParent?.id }
        let project = Project(name: name, sortOrder: siblings.count, parent: addingParent)
        modelContext.insert(project)
        try? modelContext.save()
        newProjectName = ""
        isShowingAddProjectSheet = false
        addingParent = nil
        appState.librarySelection = .project(project.id)
    }

    private func renameProject(_ project: Project) {
        let alert = NSAlert()
        alert.messageText = "重命名项目"
        alert.informativeText = "输入新的项目名称"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = project.name
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            project.name = input.stringValue.trimmingCharacters(in: .whitespaces)
            try? modelContext.save()
        }
    }

    private func deleteProject(_ project: Project) {
        for child in LibraryMetrics.descendants(of: project, in: projects) {
            child.parent = nil
        }
        modelContext.delete(project)
        try? modelContext.save()
        if case .project(let id) = appState.librarySelection, id == project.id {
            appState.librarySelection = .all
        }
    }

    private func setProjectGoal(_ project: Project) {
        let alert = NSAlert()
        alert.messageText = "组目标字数"
        alert.informativeText = "目标会按当前项目和所有子项目的正文文稿累计"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        input.stringValue = project.wordGoal.map(String.init) ?? "30000"
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "移除")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let value = Int(input.stringValue), value > 0 {
            project.wordGoal = value
            try? modelContext.save()
        } else if response == .alertSecondButtonReturn {
            project.wordGoal = nil
            try? modelContext.save()
        }
    }

    private func enableProjectEncryption(_ project: Project) {
        ProjectSecurityUI.enableEncryption(for: project, appState: appState, modelContext: modelContext)
    }

    private func unlockProject(_ project: Project) {
        let protectedProject = ProjectSecurity.protectingProject(for: project) ?? project
        ProjectSecurityUI.unlock(protectedProject, appState: appState)
    }

    private func lockProject(_ project: Project) {
        let protectedProject = ProjectSecurity.protectingProject(for: project) ?? project
        ProjectSecurityUI.lock(protectedProject, appState: appState)
    }

    private func disableProjectEncryption(_ project: Project) {
        ProjectSecurityUI.disableEncryption(for: project, appState: appState, modelContext: modelContext)
    }

    private func moveProjects(from source: IndexSet, to destination: Int) {
        var ordered = projects
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in ordered.enumerated() {
            project.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct ProjectSidebarRow: View {
    @Environment(\.modelContext) private var modelContext

    let project: Project
    let projects: [Project]
    let allSheets: [Sheet]
    @Bindable var appState: AppState
    let onBeginAddingSubproject: (Project) -> Void
    let onRename: (Project) -> Void
    let onDelete: (Project) -> Void
    let onSetGoal: (Project) -> Void
    let onEnableEncryption: (Project) -> Void
    let onUnlockProject: (Project) -> Void
    let onLockProject: (Project) -> Void
    let onDisableEncryption: (Project) -> Void

    private var children: [Project] {
        projects
            .filter { $0.parent?.id == project.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        if children.isEmpty {
            projectLabel
        } else {
            DisclosureGroup {
                ForEach(children) { child in
                    ProjectSidebarRow(
                        project: child,
                        projects: projects,
                        allSheets: allSheets,
                        appState: appState,
                        onBeginAddingSubproject: onBeginAddingSubproject,
                        onRename: onRename,
                        onDelete: onDelete,
                        onSetGoal: onSetGoal,
                        onEnableEncryption: onEnableEncryption,
                        onUnlockProject: onUnlockProject,
                        onLockProject: onLockProject,
                        onDisableEncryption: onDisableEncryption
                    )
                }
            } label: {
                projectLabel
            }
        }
    }

    private var projectLabel: some View {
        let metrics = LibraryMetrics.metrics(for: project, projects: projects, sheets: allSheets)
        let protectingProject = ProjectSecurity.protectingProject(for: project)
        let isLocked = protectingProject.map { !appState.isProjectUnlocked($0.id) } ?? false
        return Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                if isLocked {
                    Text("已加密")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if metrics.textSheetCount > 0 || metrics.materialSheetCount > 0 || (project.wordGoal ?? 0) > 0 {
                    HStack(spacing: 4) {
                        if metrics.textSheetCount > 0 {
                            Text("\(metrics.textSheetCount) 篇")
                        }
                        if metrics.materialSheetCount > 0 {
                            if metrics.textSheetCount > 0 { Text("·") }
                            Text("\(metrics.materialSheetCount) 份资料")
                        }
                        if let goal = project.wordGoal, goal > 0 {
                            if metrics.textSheetCount > 0 || metrics.materialSheetCount > 0 { Text("·") }
                            Text("\(Int((metrics.progress(goal: goal) ?? 0) * 100))%")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: projectIcon(isLocked: isLocked))
                .foregroundStyle(.secondary)
        }
        .tag(LibrarySelection.project(project.id))
        .padding(.leading, CGFloat(project.depth) * 8)
        .dropDestination(for: SheetTransferable.self) { items, _ in
            guard !isLocked else { return false }
            guard let item = items.first,
                  let sheet = allSheets.first(where: { $0.id == item.sheetID }) else { return false }
            sheet.project = project
            try? modelContext.save()
            return true
        }
        .contextMenu {
            Button("新建子项目") { onBeginAddingSubproject(project) }
                .disabled(isLocked)
            Button("新建资料") {
                appState.librarySelection = .project(project.id)
                SheetCreation.create(in: modelContext, appState: appState, kind: .material)
            }
            .disabled(isLocked)
            Button("设置组目标…") { onSetGoal(project) }
                .disabled(isLocked)
            Divider()
            encryptionMenuItems(isLocked: isLocked, protectingProject: protectingProject)
            Divider()
            Button("重命名") { onRename(project) }
                .disabled(isLocked)
            Button("删除", role: .destructive) { onDelete(project) }
                .disabled(isLocked)
        }
    }

    @ViewBuilder
    private func encryptionMenuItems(isLocked: Bool, protectingProject: Project?) -> some View {
        if project.isEncryptionEnabled {
            if isLocked {
                Button("解锁项目…") { onUnlockProject(project) }
            } else {
                Button("锁定项目") { onLockProject(project) }
            }
            Button("关闭加密…") { onDisableEncryption(project) }
        } else if let protectingProject {
            if isLocked {
                Button("解锁上级加密项目…") { onUnlockProject(protectingProject) }
            } else {
                Button("锁定上级加密项目") { onLockProject(protectingProject) }
            }
        } else {
            Button("启用加密…") { onEnableEncryption(project) }
        }
    }

    private func projectIcon(isLocked: Bool) -> String {
        if isLocked { return "lock.fill" }
        if project.isEncryptionEnabled { return "lock.open.fill" }
        return children.isEmpty ? "folder" : "folder.fill"
    }
}
