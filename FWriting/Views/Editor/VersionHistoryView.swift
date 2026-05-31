//
//  VersionHistoryView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct VersionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sheet: Sheet

    private var snapshots: [SheetSnapshot] {
        sheet.snapshots.sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("版本历史")
                    .font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }
            }

            if snapshots.isEmpty {
                ContentUnavailableView("暂无历史版本", systemImage: "clock.arrow.circlepath", description: Text("编辑文稿后会自动保存版本快照"))
            } else {
                List(snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.savedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        Text(snapshot.title)
                            .font(.subheadline)
                        Text(snapshot.body.prefix(120) + (snapshot.body.count > 120 ? "…" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("恢复此版本") {
                            restore(snapshot)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .frame(width: 480, height: 400)
    }

    private func restore(_ snapshot: SheetSnapshot) {
        sheet.title = snapshot.title
        sheet.body = snapshot.body
        sheet.modifiedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
