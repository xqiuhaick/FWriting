//
//  MarkdownTextView.swift
//  FWriting
//

import AppKit
import SwiftUI

final class FocusWritingTextView: NSTextView {
    var lineHighlightLayoutManager: LineHighlightLayoutManager? {
        layoutManager as? LineHighlightLayoutManager
    }

    func invalidateLineHighlight() {
        // 仅选区/光标变化时，AppKit 常把局部重绘优化成只重画插入点，
        // 导致当前行高亮要等到下一次真正重排（如回车）才更新。
        // 整体置脏可强制重走背景绘制，让高亮实时跟随光标。
        needsDisplay = true
    }

    /// 光标在文档坐标系中的矩形（与 clipView.bounds 同一坐标系）。
    func caretRect(for range: NSRange) -> NSRect? {
        guard let textContainer, let layoutManager else { return nil }
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        if rect.height == 0 {
            rect.size.height = (font ?? EditorTypography.bodyFont()).boundingRectForFont.height
        }
        let origin = textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        return rect
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard let scrollView = enclosingScrollView,
              let caretRect = caretRect(for: range) else {
            super.scrollRangeToVisible(range)
            return
        }
        guard needsScroll(for: caretRect, in: scrollView) else { return }
        super.scrollRangeToVisible(range)
    }

    override func scrollToVisible(_ rect: NSRect) -> Bool {
        guard let scrollView = enclosingScrollView else {
            return super.scrollToVisible(rect)
        }
        guard needsScroll(for: rect, in: scrollView) else { return false }
        return super.scrollToVisible(rect)
    }

    private func needsScroll(for rect: NSRect, in scrollView: NSScrollView) -> Bool {
        let visible = scrollView.contentView.bounds
        return rect.minY < visible.minY || rect.maxY > visible.maxY
    }
}

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var typography: EditorTypography
    var markdownHighlight: Bool
    var typewriterMode: Bool
    var currentLineHighlight: Bool
    var paragraphFocus: Bool
    var previousSummaries: String
    var horizontalTextInset: CGFloat
    var topTextInset: CGFloat
    var onTextChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textStorage = NSTextStorage()
        let layoutManager = LineHighlightLayoutManager()
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textContainer.lineFragmentPadding = 0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = FocusWritingTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        layoutManager.hostTextView = textView
        layoutManager.showsLineHighlight = currentLineHighlight
        layoutManager.showsParagraphFocus = paragraphFocus

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: horizontalTextInset, height: topTextInset)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        // 关键：默认 maxSize 等于初始 frame（.zero），文本视图无法随内容向下增高，
        // 导致超出可视区的内容被裁剪且无法滚动。设为极大值才能像 Word 那样连续滚动。
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.font = EditorTypography.bodyFont()
        textView.string = text
        textView.insertionPointColor = NSColor.controlAccentColor

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.syncedText = text
        context.coordinator.cacheStyleKey(from: self)
        context.coordinator.applyStyles()
        context.coordinator.installEditorActions()
        context.coordinator.setupAIController(scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FocusWritingTextView else { return }
        context.coordinator.parent = self

        if let layoutManager = textView.lineHighlightLayoutManager {
            let needsHighlightInvalidation = layoutManager.showsLineHighlight != currentLineHighlight
                || layoutManager.showsParagraphFocus != paragraphFocus
            layoutManager.showsLineHighlight = currentLineHighlight
            layoutManager.showsParagraphFocus = paragraphFocus
            if needsHighlightInvalidation {
                textView.invalidateLineHighlight()
            }
        }

        if !context.coordinator.isApplyingLocalEdit,
           !textView.hasMarkedText(),
           textView.string != text,
           context.coordinator.syncedText != text {
            context.coordinator.setText(text, in: textView)
        }

        if context.coordinator.styleKey != context.coordinator.makeStyleKey(from: self) {
            context.coordinator.cacheStyleKey(from: self)
            context.coordinator.scheduleApplyStyles()
        }

        context.coordinator.lastTypewriterMode = typewriterMode
        let nextInset = NSSize(width: horizontalTextInset, height: topTextInset)
        if textView.textContainerInset != nextInset {
            textView.textContainerInset = nextInset
            textView.invalidateLineHighlight()
        }
        context.coordinator.installEditorActions()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: FocusWritingTextView?
        var lastTypewriterMode = false
        var syncedText = ""
        var styleKey = ""
        var isApplyingLocalEdit = false
        private var isStyling = false
        private var isRestoringSelection = false
        private var pendingStyleWorkItem: DispatchWorkItem?
        private var aiController: AIInlineController?
        private var scrollObserver: NSObjectProtocol?

        init(parent: MarkdownTextView) {
            self.parent = parent
        }

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
        }

        @MainActor
        func setupAIController(scrollView: NSScrollView) {
            guard let textView else { return }
            let controller = AIInlineController(textView: textView)
            controller.previousSummariesProvider = { [weak self] in
                self?.parent.previousSummaries ?? ""
            }
            aiController = controller
            EditorFocusState.shared.beginInlineAI = { [weak controller] action in
                controller?.begin(action)
            }
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak controller] _ in
                MainActor.assumeIsolated {
                    controller?.viewportDidChange()
                }
            }
        }

        func makeStyleKey(from parent: MarkdownTextView) -> String {
            "\(parent.markdownHighlight)-\(parent.paragraphFocus)"
        }

        func cacheStyleKey(from parent: MarkdownTextView) {
            styleKey = makeStyleKey(from: parent)
        }

        func scheduleApplyStyles() {
            pendingStyleWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.applyStyles()
            }
            pendingStyleWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard parent.markdownHighlight else { return true }
            guard let replacement = replacementString else { return true }
            return BlockTypingHandler.shouldChangeText(
                in: textView,
                affectedRange: affectedCharRange,
                replacement: replacement
            )
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isStyling else { return }

            isApplyingLocalEdit = true
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isApplyingLocalEdit = false
                }
            }

            let newText = textView.string
            syncedText = newText
            if parent.text != newText {
                parent.text = newText
            }

            scheduleApplyStyles()
            updateFocusState(from: textView)
            (textView as? FocusWritingTextView)?.invalidateLineHighlight()
            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isStyling,
                  !isRestoringSelection else { return }
            updateFocusState(from: textView)
            aiController?.selectionDidChange()
            if parent.paragraphFocus {
                scheduleApplyStyles()
            }
            (textView as? FocusWritingTextView)?.invalidateLineHighlight()
            if parent.typewriterMode, !textView.hasMarkedText() {
                centerSelection(in: textView)
            }
        }

        func setText(_ newText: String, in textView: NSTextView) {
            let savedSelection = textView.selectedRange
            textView.string = newText
            syncedText = newText
            restoreSelection(savedSelection, in: textView)
            applyStyles()
        }

        private func updateFocusState(from textView: NSTextView) {
            let selected = textView.string as NSString
            let range = clampedRange(textView.selectedRange, length: selected.length)
            let text = range.length > 0 ? selected.substring(with: range) : ""
            EditorFocusState.shared.selectedText = text
            EditorFocusState.shared.selectedRange = range
            EditorFocusState.shared.replaceSelection = { [weak textView] newText in
                guard let textView else { return }
                let textLength = (textView.string as NSString).length
                let range = self.clampedRange(textView.selectedRange, length: textLength)
                if range.length > 0 {
                    textView.insertText(newText, replacementRange: range)
                } else {
                    textView.insertText(newText, replacementRange: NSRange(location: textLength, length: 0))
                }
            }
        }

        /// 安装底部插入栏等编辑器操作。
        func installEditorActions() {
            EditorFocusState.shared.insertBlockPrefix = { [weak textView] prefix in
                guard let textView else { return }
                let ns = textView.string as NSString
                let caret = min(textView.selectedRange.location, ns.length)
                let paragraph = ns.lineRange(for: NSRange(location: caret, length: 0))
                let lineString = ns.substring(with: paragraph).trimmingCharacters(in: .newlines)

                // 行首已有块级标记时替换它，避免 "## # " 叠加。
                let replaceRange: NSRange
                if let existing = BlockParser.markerRange(in: lineString) {
                    replaceRange = NSRange(location: paragraph.location + existing.location, length: existing.length)
                } else {
                    replaceRange = NSRange(location: paragraph.location, length: 0)
                }

                guard textView.shouldChangeText(in: replaceRange, replacementString: prefix) else { return }
                textView.textStorage?.replaceCharacters(in: replaceRange, with: prefix)
                textView.didChangeText()

                let prefixLen = (prefix as NSString).length
                let delta = prefixLen - replaceRange.length
                var newCaret = caret >= replaceRange.upperBound ? caret + delta : replaceRange.location + prefixLen
                newCaret = min(max(newCaret, 0), (textView.string as NSString).length)
                textView.setSelectedRange(NSRange(location: newCaret, length: 0))
            }

            EditorFocusState.shared.wrapSelection = { [weak textView] prefix, suffix in
                guard let textView else { return }
                let ns = textView.string as NSString
                let range = self.clampedRange(textView.selectedRange, length: ns.length)
                if range.length > 0 {
                    let selected = ns.substring(with: range)
                    let wrapped = prefix + selected + suffix
                    if textView.shouldChangeText(in: range, replacementString: wrapped) {
                        textView.textStorage?.replaceCharacters(in: range, with: wrapped)
                        textView.didChangeText()
                        textView.setSelectedRange(NSRange(location: range.location + (prefix as NSString).length, length: (selected as NSString).length))
                    }
                } else {
                    let combined = prefix + suffix
                    if textView.shouldChangeText(in: range, replacementString: combined) {
                        textView.textStorage?.replaceCharacters(in: range, with: combined)
                        textView.didChangeText()
                        textView.setSelectedRange(NSRange(location: range.location + (prefix as NSString).length, length: 0))
                    }
                }
            }

            EditorFocusState.shared.scrollToRange = { [weak textView] target in
                guard let textView else { return }
                let length = (textView.string as NSString).length
                let clamped = NSRange(location: min(target.location, length), length: min(target.length, max(0, length - min(target.location, length))))
                textView.setSelectedRange(clamped)
                textView.scrollRangeToVisible(clamped)
                textView.window?.makeFirstResponder(textView)
            }
        }

        private func clampedRange(_ range: NSRange, length: Int) -> NSRange {
            guard range.location != NSNotFound, range.location >= 0, range.length >= 0 else {
                return NSRange(location: length, length: 0)
            }
            let location = min(range.location, length)
            let maxLength = max(0, length - location)
            return NSRange(location: location, length: min(range.length, maxLength))
        }

        func applyStyles() {
            guard let textView, let storage = textView.textStorage, !isStyling else { return }

            let savedSelection = textView.selectedRange
            isStyling = true
            defer { isStyling = false }

            if parent.markdownHighlight {
                MarkdownHighlighter.apply(to: storage, typography: parent.typography, hideMarkers: true)
            } else {
                let fullRange = NSRange(location: 0, length: storage.length)
                storage.beginEditing()
                storage.setAttributes([
                    .font: EditorTypography.bodyFont(),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: EditorTypography.bodyParagraphStyle()
                ], range: fullRange)
                storage.endEditing()
            }

            if parent.paragraphFocus {
                applyParagraphFocus(to: storage, cursorLocation: savedSelection.location)
            }

            restoreSelection(savedSelection, in: textView)
            textView.invalidateLineHighlight()
        }

        private func restoreSelection(_ range: NSRange, in textView: NSTextView) {
            let length = (textView.string as NSString).length
            let location = min(range.location, length)
            let end = min(range.location + range.length, length)
            let clamped = NSRange(location: location, length: max(0, end - location))
            guard textView.selectedRange != clamped else { return }

            isRestoringSelection = true
            textView.setSelectedRange(clamped)
            isRestoringSelection = false
        }

        private func applyParagraphFocus(to textStorage: NSTextStorage, cursorLocation: Int) {
            let text = textStorage.string as NSString
            guard text.length > 0 else { return }

            var location = 0
            while location < text.length {
                let range = text.paragraphRange(for: NSRange(location: location, length: 0))
                let isCurrent = NSLocationInRange(cursorLocation, range)
                    || (cursorLocation == text.length && range.upperBound == text.length)
                if !isCurrent {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
                }
                location = NSMaxRange(range)
            }
        }

        private func centerSelection(in textView: NSTextView) {
            guard let scrollView = textView.enclosingScrollView,
                  let focusTextView = textView as? FocusWritingTextView,
                  let caretRect = focusTextView.caretRect(for: textView.selectedRange) else { return }

            let visible = scrollView.contentView.bounds
            let lineHeight = (textView.font ?? EditorTypography.bodyFont()).boundingRectForFont.height
            // 光标仍在视口中间区域时不滚动，避免内容尚短时每换行就被顶下去一行。
            let comfortBand = max(lineHeight * 2, visible.height * 0.25)
            let midY = visible.midY
            if caretRect.midY >= midY - comfortBand, caretRect.midY <= midY + comfortBand {
                return
            }

            let targetY = caretRect.midY - visible.height / 2
            let maxY = max(0, (scrollView.documentView?.frame.height ?? 0) - visible.height)
            scrollView.contentView.scroll(to: NSPoint(x: visible.origin.x, y: min(max(0, targetY), maxY)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
