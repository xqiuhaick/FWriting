//
//  SheetTitleSync.swift
//  FWriting
//

import Foundation

enum SheetTitleSync {
    /// 正文首行若为一级标题，则同步到文稿标题（列表 / 标题栏）。
    static func applyFirstHeading(to sheet: Sheet) {
        guard let derived = BlockParser.firstHeadingTitle(in: sheet.body, level: 1),
              !derived.isEmpty else { return }
        sheet.title = derived
    }
}
