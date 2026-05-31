//
//  EditorFocusState.swift
//  FWriting
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class EditorFocusState {
    static let shared = EditorFocusState()

    var selectedText: String = ""
    var selectedRange: NSRange?
    var replaceSelection: ((String) -> Void)?
    var insertText: ((String) -> Void)?

    /// 在当前段落（行）行首插入前缀，如 "# "、"> "、"- "。
    var insertBlockPrefix: ((String) -> Void)?
    /// 用前后缀包裹选区，无选区则插入并把光标置于中间，如 ("`", "`")。
    var wrapSelection: ((String, String) -> Void)?
    /// 滚动并选中指定字符范围。
    var scrollToRange: ((NSRange) -> Void)?
    /// 在当前选区（无选区时取当前段落）上就地发起 AI 处理。
    var beginInlineAI: ((AIAction) -> Void)?

    func clear() {
        selectedText = ""
        selectedRange = nil
        replaceSelection = nil
        insertText = nil
        insertBlockPrefix = nil
        wrapSelection = nil
        scrollToRange = nil
        beginInlineAI = nil
    }
}
