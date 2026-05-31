//
//  MarkdownInsertBar.swift
//  FWriting
//

import SwiftUI

struct MarkdownInsertBar: View {
    @State private var isShowingMore = false

    var body: some View {
        HStack(spacing: 4) {
            Spacer()

            Menu {
                button("# 标题", systemImage: "1.square") { insertBlock("# ") }
                button("## 小标题", systemImage: "2.square") { insertBlock("## ") }
                button("### 副标题", systemImage: "3.square") { insertBlock("### ") }
            } label: {
                barLabel("标题", systemImage: "number")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                button("带虚线的列表", systemImage: "list.bullet") { insertBlock("- ") }
                button("带数字的列表", systemImage: "list.number") { insertBlock("1. ") }
            } label: {
                barLabel("列表", systemImage: "list.bullet")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                insertBlock("> ")
            } label: {
                barLabel("引用块", systemImage: "text.quote")
            }
            .buttonStyle(.plain)

            Button {
                isShowingMore = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingMore, arrowEdge: .top) {
                morePopover
            }

            Spacer()
        }
        .font(.callout)
        .frame(height: 36)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var morePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            popoverRow("%% 注释") { insertBlock("%% ") }
            popoverRow("` 代码") { wrap("`", "`") }
            popoverRow("~~ 删除线") { wrap("~~", "~~") }
        }
        .padding(14)
        .frame(width: 160)
    }

    private func barLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(title)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
    }

    private func popoverRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            isShowingMore = false
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func insertBlock(_ prefix: String) {
        EditorFocusState.shared.insertBlockPrefix?(prefix)
    }

    private func wrap(_ prefix: String, _ suffix: String) {
        EditorFocusState.shared.wrapSelection?(prefix, suffix)
    }
}
