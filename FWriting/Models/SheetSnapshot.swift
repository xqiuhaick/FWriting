//
//  SheetSnapshot.swift
//  FWriting
//

import Foundation
import SwiftData

@Model
final class SheetSnapshot {
    var id: UUID
    var title: String
    var body: String
    var savedAt: Date

    var sheet: Sheet?

    init(title: String, body: String, sheet: Sheet?) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.savedAt = .now
        self.sheet = sheet
    }
}
