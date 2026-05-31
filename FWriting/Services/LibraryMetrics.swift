//
//  LibraryMetrics.swift
//  FWriting
//

import Foundation

struct ProjectMetrics {
    var textSheetCount = 0
    var materialSheetCount = 0
    var wordCount = 0

    var totalSheetCount: Int {
        textSheetCount + materialSheetCount
    }

    func progress(goal: Int?) -> Double? {
        guard let goal, goal > 0 else { return nil }
        return min(Double(wordCount) / Double(goal), 1)
    }
}

enum LibraryMetrics {
    static func descendants(of project: Project, in projects: [Project]) -> [Project] {
        var result: [Project] = []
        var stack = projects
            .filter { $0.parent?.id == project.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        while let current = stack.first {
            stack.removeFirst()
            result.append(current)
            let children = projects
                .filter { $0.parent?.id == current.id }
                .sorted { $0.sortOrder < $1.sortOrder }
            stack.insert(contentsOf: children, at: 0)
        }

        return result
    }

    static func projectAndDescendantIDs(_ project: Project, in projects: [Project]) -> Set<UUID> {
        Set(([project] + descendants(of: project, in: projects)).map(\.id))
    }

    static func sheets(for project: Project, projects: [Project], sheets: [Sheet]) -> [Sheet] {
        let ids = projectAndDescendantIDs(project, in: projects)
        return sheets.filter { sheet in
            guard let projectID = sheet.project?.id else { return false }
            return ids.contains(projectID) && !sheet.isTrashed
        }
    }

    static func metrics(for project: Project, projects: [Project], sheets: [Sheet]) -> ProjectMetrics {
        Self.sheets(for: project, projects: projects, sheets: sheets).reduce(into: ProjectMetrics()) { metrics, sheet in
            switch sheet.kind {
            case .text:
                metrics.textSheetCount += 1
                metrics.wordCount += sheet.wordCount
            case .material:
                metrics.materialSheetCount += 1
            }
        }
    }
}
