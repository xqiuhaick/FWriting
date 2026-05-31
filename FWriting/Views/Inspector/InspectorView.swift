//
//  InspectorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct InspectorView: View {
    @Bindable var appState: AppState
    let allSheets: [Sheet]
    let sheet: Sheet?

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $appState.inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Image(systemName: tab.icon)
                        .help(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if let sheet {
                inspectorContent(for: sheet)
            } else {
                Spacer()
                Text("未选择文稿")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func inspectorContent(for sheet: Sheet) -> some View {
        switch appState.inspectorTab {
        case .characters:
            CharacterInspectorView(sheet: sheet)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .tags:
            TagInspectorView(appState: appState, sheet: sheet)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .stats:
            ScrollView {
                StatsInspectorView(sheet: sheet)
            }
        case .outline:
            ScrollView {
                OutlineInspectorView(sheet: sheet, allSheets: allSheets)
            }
        case .goal:
            ScrollView {
                GoalInspectorView(sheet: sheet)
            }
        }
    }
}
