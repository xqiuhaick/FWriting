//
//  LibrarySelection.swift
//  FWriting
//

import Foundation

enum LibrarySelection: Hashable, Identifiable {
    case all
    case textSheets
    case materials
    case favorites
    case recent
    case trash
    case tag(UUID)
    case project(UUID)

    var id: String {
        switch self {
        case .all: "all"
        case .textSheets: "textSheets"
        case .materials: "materials"
        case .favorites: "favorites"
        case .recent: "recent"
        case .trash: "trash"
        case .tag(let id): "tag-\(id.uuidString)"
        case .project(let id): "project-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .all: "全部文稿"
        case .textSheets: "正文"
        case .materials: "资料库"
        case .favorites: "收藏"
        case .recent: "最近编辑"
        case .trash: "废纸篓"
        case .tag: "标签"
        case .project: "项目"
        }
    }

    var icon: String {
        switch self {
        case .all: "books.vertical"
        case .textSheets: "doc.text"
        case .materials: "paperclip"
        case .favorites: "star"
        case .recent: "clock"
        case .trash: "trash"
        case .tag: "tag"
        case .project: "folder"
        }
    }
}
