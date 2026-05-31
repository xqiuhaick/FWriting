//
//  CharacterInspectorView.swift
//  FWriting
//

import SwiftData
import SwiftUI

struct CharacterInspectorView: View {
    @Environment(\.modelContext) private var modelContext
    let sheet: Sheet

    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @State private var selectedCharacterID: UUID?
    @State private var expandedSections: Set<CharacterFormSection> = [.basics]

    init(sheet: Sheet) {
        self.sheet = sheet
    }

    private var projectID: UUID? { sheet.project?.id }

    private var characters: [Character] {
        allCharacters
            .filter { $0.project?.id == projectID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var selectedCharacter: Character? {
        guard let id = selectedCharacterID else { return nil }
        return characters.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: 0) {
            if characters.isEmpty {
                emptyView
            } else {
                characterPickerBar
                Divider()
                if let character = selectedCharacter {
                    characterDetail(character)
                } else {
                    noSelectionView
                }
            }
        }
        .onAppear {
            if selectedCharacterID == nil, let first = characters.first {
                selectedCharacterID = first.id
            }
        }
        .onChange(of: characters.map(\.id)) { _, ids in
            if let selected = selectedCharacterID, !ids.contains(selected) {
                selectedCharacterID = ids.first
            } else if selectedCharacterID == nil {
                selectedCharacterID = ids.first
            }
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            ContentUnavailableView {
                Label("暂无人物", systemImage: "person.2")
            } description: {
                Text(projectID == nil ? "将文稿归入项目后可管理人物" : "为当前项目添加人物设定")
            }
            if projectID != nil {
                Button {
                    addCharacter()
                } label: {
                    Label("添加人物", systemImage: "plus")
                }
            }
            Spacer()
        }
        .padding(16)
    }

    // MARK: - 人物选择

    private var characterPickerBar: some View {
        HStack(spacing: 8) {
            Picker("人物", selection: $selectedCharacterID) {
                ForEach(characters) { character in
                    Text(character.displayName)
                        .tag(Optional(character.id))
                }
            }
            .labelsHidden()

            Button {
                addCharacter()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("添加人物")
            .disabled(projectID == nil)

            Button {
                if let character = selectedCharacter {
                    deleteCharacter(character)
                }
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .help("删除人物")
            .disabled(selectedCharacter == nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var noSelectionView: some View {
        VStack {
            Spacer()
            Text("选择要编辑的人物")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 人物详情

    @ViewBuilder
    private func characterDetail(_ character: Character) -> some View {
        @Bindable var c = character

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                formSection(.basics) {
                    fieldRow("姓名", text: $c.name, placeholder: "人物姓名", isRequired: true)
                    fieldRow("别名", text: $c.alias, placeholder: "多个别名以逗号分隔")
                    fieldRow("性别", text: $c.gender, placeholder: "男 / 女 / 其他")
                    fieldRow("年龄", text: $c.age, placeholder: "出场年龄")
                    fieldRow("身份", text: $c.identity, placeholder: "职业 / 地位 / 称号")
                }

                formSection(.portrait) {
                    fieldRow("性格", text: $c.personality, axis: .vertical, lineLimit: 2...4)
                    fieldRow("外貌", text: $c.appearance, axis: .vertical, lineLimit: 2...4)
                    fieldRow("说话风格", text: $c.speakingStyle, axis: .vertical, lineLimit: 2...4)
                }

                formSection(.story) {
                    fieldRow(
                        "人物关系",
                        text: $c.relationships,
                        axis: .vertical,
                        prompt: "与其他人物 / 势力的关系",
                        lineLimit: 2...5
                    )
                    fieldRow(
                        "约束",
                        text: $c.constraints,
                        axis: .vertical,
                        prompt: "不能写错：身份、称呼、秘密等",
                        lineLimit: 2...5
                    )
                    fieldRow(
                        "备注",
                        text: $c.notes,
                        axis: .vertical,
                        prompt: "经历、原型、参考等",
                        lineLimit: 2...5
                    )
                }

                Text("当前章节出现该人物姓名或别名时，AI 会参考以上设定。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: c.name) { _, _ in save(character) }
        .onChange(of: c.alias) { _, _ in save(character) }
        .onChange(of: c.gender) { _, _ in save(character) }
        .onChange(of: c.age) { _, _ in save(character) }
        .onChange(of: c.identity) { _, _ in save(character) }
        .onChange(of: c.personality) { _, _ in save(character) }
        .onChange(of: c.appearance) { _, _ in save(character) }
        .onChange(of: c.speakingStyle) { _, _ in save(character) }
        .onChange(of: c.relationships) { _, _ in save(character) }
        .onChange(of: c.constraints) { _, _ in save(character) }
        .onChange(of: c.notes) { _, _ in save(character) }
    }

    @ViewBuilder
    private func formSection<Content: View>(
        _ section: CharacterFormSection,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: binding(for: section)) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        } label: {
            Text(section.title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func binding(for section: CharacterFormSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { expanded in
                if expanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    // MARK: - 字段行

    private func fieldRow(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        axis: Axis = .horizontal,
        prompt: String = "",
        isRequired: Bool = false,
        lineLimit: ClosedRange<Int> = 2...4
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label + (isRequired ? " *" : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
            if axis == .vertical {
                TextField(
                    prompt.isEmpty ? placeholder : prompt,
                    text: text,
                    axis: .vertical
                )
                .font(.callout)
                .textFieldStyle(.roundedBorder)
                .lineLimit(lineLimit)
            } else {
                TextField(placeholder, text: text)
                    .font(.callout)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - 操作

    private func addCharacter() {
        guard projectID != nil else { return }
        let character = Character(
            name: "新人物",
            sortOrder: characters.count,
            project: sheet.project
        )
        modelContext.insert(character)
        try? modelContext.save()
        selectedCharacterID = character.id
        expandedSections = [.basics]
    }

    private func deleteCharacter(_ character: Character) {
        if selectedCharacterID == character.id {
            selectedCharacterID = nil
        }
        modelContext.delete(character)
        try? modelContext.save()
    }

    private func save(_ character: Character) {
        character.modifiedAt = .now
        try? modelContext.save()
    }
}

private enum CharacterFormSection: Hashable {
    case basics
    case portrait
    case story

    var title: String {
        switch self {
        case .basics: "基本信息"
        case .portrait: "性格与外貌"
        case .story: "关系与备注"
        }
    }
}
