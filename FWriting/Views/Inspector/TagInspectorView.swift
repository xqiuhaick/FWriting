//
//  TagInspectorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct TagInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var appState: AppState
    let sheet: Sheet

    @Query(sort: \Tag.sortOrder) private var allTags: [Tag]
    @State private var newTagName = ""

    private var sortedTags: [Tag] {
        allTags.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private var assignedTags: [Tag] {
        sheet.tags.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("当前文稿")

                if assignedTags.isEmpty {
                    Text("尚未添加标签")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    TagFlowLayout(spacing: 6) {
                        ForEach(assignedTags) { tag in
                            assignedTagChip(tag)
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("新标签名", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTagFromField() }
                    Button("添加") { addTagFromField() }
                        .disabled(normalizedTagName(newTagName).isEmpty)
                }

                Divider()

                sectionHeader("全部标签")

                if sortedTags.isEmpty {
                    Text("创建标签后，可在侧栏按标签筛选文稿。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(sortedTags) { tag in
                        tagToggleRow(tag)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func assignedTagChip(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            Text(tag.displayName)
                .font(.caption)
            Button {
                removeTag(tag, from: sheet)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("从本篇文稿移除此标签")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private func tagToggleRow(_ tag: Tag) -> some View {
        let isAssigned = sheet.tags.contains(where: { $0.id == tag.id })
        return HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { isAssigned },
                set: { assigned in
                    if assigned {
                        assignTag(tag, to: sheet)
                    } else {
                        removeTag(tag, from: sheet)
                    }
                }
            )) {
                Text(tag.displayName)
                    .font(.callout)
            }
            .toggleStyle(.checkbox)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                deleteTag(tag)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("从库中删除此标签")
        }
        .contextMenu {
            Button("删除标签", role: .destructive) {
                deleteTag(tag)
            }
        }
    }

    private func addTagFromField() {
        let name = normalizedTagName(newTagName)
        guard !name.isEmpty else { return }

        let tag: Tag
        if let existing = sortedTags.first(where: { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }) {
            tag = existing
        } else {
            tag = Tag(name: name, sortOrder: sortedTags.count)
            modelContext.insert(tag)
        }

        assignTag(tag, to: sheet)
        newTagName = ""
        try? modelContext.save()
    }

    private func normalizedTagName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    }

    private func assignTag(_ tag: Tag, to sheet: Sheet) {
        guard !sheet.tags.contains(where: { $0.id == tag.id }) else { return }
        sheet.tags.append(tag)
        if !tag.sheets.contains(where: { $0.id == sheet.id }) {
            tag.sheets.append(sheet)
        }
        try? modelContext.save()
    }

    private func removeTag(_ tag: Tag, from sheet: Sheet) {
        sheet.tags.removeAll { $0.id == tag.id }
        tag.sheets.removeAll { $0.id == sheet.id }
        try? modelContext.save()
    }

    private func deleteTag(_ tag: Tag) {
        TagLibraryOperations.delete(tag, modelContext: modelContext, appState: appState)
    }
}

// MARK: - 标签流式布局

private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0 else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
