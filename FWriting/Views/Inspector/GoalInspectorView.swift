//
//  GoalInspectorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct GoalInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    let sheet: Sheet

    @State private var goalText = ""

    private var currentWords: Int {
        WritingStatsService.wordCount(for: sheet.body)
    }

    private var progress: Double {
        guard let goal = sheet.wordGoal, goal > 0 else { return 0 }
        return min(Double(currentWords) / Double(goal), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("写作目标")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let goal = sheet.wordGoal, goal > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(.title2.monospacedDigit())
                        Text("\(currentWords) / \(goal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            HStack(spacing: 6) {
                TextField("目标字数", text: $goalText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyGoal() }
                Button("设定") { applyGoal() }
            }

            if sheet.wordGoal != nil {
                Button("移除目标", role: .destructive) {
                    sheet.wordGoal = nil
                    goalText = ""
                    try? modelContext.save()
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            goalText = sheet.wordGoal.map(String.init) ?? ""
        }
        .onChange(of: sheet.id) {
            goalText = sheet.wordGoal.map(String.init) ?? ""
        }
    }

    private func applyGoal() {
        if let value = Int(goalText.trimmingCharacters(in: .whitespaces)), value > 0 {
            sheet.wordGoal = value
            try? modelContext.save()
        }
    }
}
