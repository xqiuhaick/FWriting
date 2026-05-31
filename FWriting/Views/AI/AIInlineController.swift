//
//  AIInlineController.swift
//  FWriting
//
//  就地 AI 体验：选中文字时浮现操作药丸，触发后在选区旁弹出流式气泡，
//  回车就地替换并高亮闪烁，Esc 取消。替代旧的居中模态面板。
//

import AppKit
import Combine
import SwiftUI

// MARK: - 流式会话

@MainActor
final class AIInlineSession: ObservableObject {
    @Published var output = ""
    @Published var isStreaming = true
    @Published var errorMessage: String?

    let action: AIAction
    let polishMode: AIPolishMode?
    let translateLanguage: AITranslateLanguage?
    let continueMode: AIContinueMode?
    let continueTargetWordCount: Int?
    private let sourceText: String
    private var task: Task<Void, Never>?

    var onReplace: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?
    var onContinueWriting: (() -> Void)?

    init(
        action: AIAction,
        sourceText: String,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) {
        self.action = action
        self.sourceText = sourceText
        self.polishMode = polishMode
        self.translateLanguage = translateLanguage
        self.continueMode = continueMode
        self.continueTargetWordCount = continueTargetWordCount
    }

    var canApply: Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && errorMessage == nil
    }

    var resultText: String {
        switch action {
        case .brainstorm:
            output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            AIService.finalizeOutput(
                output,
                for: action,
                continueMode: continueMode,
                continueTargetWordCount: continueTargetWordCount
            )
        }
    }

    func start() {
        task?.cancel()
        output = ""
        errorMessage = nil
        isStreaming = true
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isStreaming = false }
            do {
                for try await chunk in AIService.processStream(
                    text: sourceText,
                    action: action,
                    polishMode: polishMode,
                    translateLanguage: translateLanguage,
                    continueMode: continueMode,
                    continueTargetWordCount: continueTargetWordCount
                ) {
                    if Task.isCancelled { return }
                    output += chunk
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
            output = AIService.finalizeOutput(
                output,
                for: action,
                continueMode: continueMode,
                continueTargetWordCount: continueTargetWordCount
            )
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

// MARK: - 控制器

@MainActor
final class AIInlineController: NSObject, NSPopoverDelegate {
    private weak var textView: NSTextView?
    var previousSummariesProvider: () -> String = { "" }

    private var pillPanel: NSPanel?
    private var popover: NSPopover?
    private var session: AIInlineSession?
    private var keyMonitor: Any?

    private var targetRange: NSRange?
    private var lastPillRange: NSRange?

    init(textView: NSTextView) {
        self.textView = textView
        super.init()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    // MARK: 选区变化 → 浮动药丸

    func selectionDidChange() {
        if popover != nil { hidePill(); return }
        guard let tv = textView, tv.window != nil else { hidePill(); return }
        let range = tv.selectedRange
        guard range.length > 0, !tv.string.isEmpty else { hidePill(); return }
        lastPillRange = range
        showPill(for: range)
    }

    func viewportDidChange() {
        if let range = textView?.selectedRange, range.length > 0, popover == nil {
            showPill(for: range)
        } else {
            hidePill()
        }
    }

    private func showPill(for range: NSRange) {
        guard let tv = textView, let rect = selectionRectInScreen(for: range) else { return }

        let pill = AISelectionPill(
            onPolish: { [weak self] mode in self?.begin(.polish, polishMode: mode) },
            onTranslate: { [weak self] language in self?.begin(.translate, translateLanguage: language) },
            onContinue: { [weak self] mode in self?.begin(.continueWriting, continueMode: mode) },
            onBrainstorm: { [weak self] in self?.begin(.brainstorm) },
            onQuickCreate: { [weak self] in self?.begin(.quickCreate) }
        )

        let panel: NSPanel
        if let existing = pillPanel {
            panel = existing
            (panel.contentView as? NSHostingView<AISelectionPill>)?.rootView = pill
        } else {
            panel = NSPanel(contentRect: .zero,
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered,
                            defer: true)
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.contentView = NSHostingView(rootView: pill)
            tv.window?.addChildWindow(panel, ordered: .above)
            pillPanel = panel
        }

        let size = panel.contentView?.fittingSize ?? NSSize(width: 180, height: 34)
        panel.setContentSize(size)

        var origin = NSPoint(x: rect.minX, y: rect.maxY + 8)
        if let screen = tv.window?.screen ?? NSScreen.main {
            let maxX = screen.visibleFrame.maxX - size.width - 8
            origin.x = min(max(screen.visibleFrame.minX + 8, origin.x), maxX)
            if origin.y + size.height > screen.visibleFrame.maxY {
                origin.y = rect.minY - size.height - 8
            }
        }
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    private func hidePill() {
        pillPanel?.orderOut(nil)
        lastPillRange = nil
    }

    // MARK: 发起 AI（药丸 / 快捷键 / 菜单）

    func begin(
        _ action: AIAction,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        brainstormPlan: String? = nil
    ) {
        guard let tv = textView else { return }
        hidePill()
        dismissPopover()

        let ns = tv.string as NSString
        var range = clamp(tv.selectedRange, length: ns.length)
        let source: String

        if action == .quickCreate {
            range = quickCreateSourceRange(in: ns, selected: range)
            guard range.length > 0 else { return }
            let seed = ns.substring(with: range)
            guard WritingStatsService.wordCount(for: seed) >= 8 else { return }
            targetRange = range
            source = seed
        } else if action == .continueWriting || action == .brainstorm {
            if action == .continueWriting, (continueMode ?? .natural).usesSelectionOnly {
                guard range.length > 0 else { return }
                targetRange = range
                source = ns.substring(with: range)
            } else {
                let insertionPoint = range.length > 0 ? range.upperBound : range.location
                guard insertionPoint > 0 else { return }
                let contextStart = max(0, insertionPoint - AIService.continueContextMaxCharacters)
                let recentText = ns.substring(with: NSRange(location: contextStart, length: insertionPoint - contextStart))
                if action == .continueWriting {
                    let resolvedMode = continueMode ?? .natural
                    source = continueSource(
                        recentText: recentText,
                        mode: resolvedMode,
                        brainstormPlan: brainstormPlan
                    )
                } else {
                    source = brainstormSource(recentText: recentText)
                }
                targetRange = NSRange(location: insertionPoint, length: 0)
                range = targetRange ?? range
            }
        } else {
            if range.length == 0 {
                var para = ns.paragraphRange(for: NSRange(location: range.location, length: 0))
                while para.length > 0, ns.character(at: para.location + para.length - 1) == 0x0A {
                    para.length -= 1
                }
                range = para
                tv.setSelectedRange(range)
            }
            guard range.length > 0 else { return }
            targetRange = range
            source = ns.substring(with: range)
        }

        let isBrainstormContinue = action == .continueWriting
            && !(brainstormPlan?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let session = AIInlineSession(
            action: action,
            sourceText: source,
            polishMode: action == .polish ? (polishMode ?? .standard) : nil,
            translateLanguage: action == .translate ? (translateLanguage ?? .chinese) : nil,
            continueMode: action == .continueWriting ? (continueMode ?? .natural) : nil,
            continueTargetWordCount: isBrainstormContinue ? AIService.brainstormContinueMaxWordCount : nil
        )
        session.onReplace = { [weak self] in self?.applyResult() }
        session.onCancel = { [weak self] in self?.dismissPopover() }
        session.onRetry = { [weak self] in self?.session?.start() }
        if action == .brainstorm {
            session.onContinueWriting = { [weak self] in self?.beginNaturalContinueAfterBrainstorm() }
        }
        self.session = session

        showBubble(for: session, anchorRange: range)
        hidePill()
        session.start()
        installKeyMonitor()
    }

    private static let quickCreateShortDocumentMaxWords = 400

    /// 有选区用选区；否则当前段；极短全文时整篇当作梗概。
    private func quickCreateSourceRange(in ns: NSString, selected range: NSRange) -> NSRange {
        if range.length > 0 { return range }
        var paragraph = ns.paragraphRange(for: NSRange(location: min(range.location, max(0, ns.length - 1)), length: 0))
        while paragraph.length > 0, ns.character(at: paragraph.location + paragraph.length - 1) == 0x0A {
            paragraph.length -= 1
        }
        if paragraph.length > 0 { return paragraph }
        let full = (ns as String).trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty,
           WritingStatsService.wordCount(for: full) <= Self.quickCreateShortDocumentMaxWords {
            return NSRange(location: 0, length: ns.length)
        }
        return NSRange(location: range.location, length: 0)
    }

    private func continueSource(
        recentText: String,
        mode: AIContinueMode,
        brainstormPlan: String? = nil
    ) -> String {
        let plan = brainstormPlan?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if mode == .complete {
            let previousSummaries = previousSummariesProvider()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var sections = [
                """
                前面章节结构化摘要（不包含当前章节；已按章节顺序排列。续写时必须先理解章节位置和发展脉络，再优先遵守人物与关系、重要设定、当前状态和续写提醒）：
                \(previousSummaries.isEmpty ? "暂无可用摘要。" : previousSummaries)

                当前章节最近原文：
                \(recentText)
                """,
            ]
            if !plan.isEmpty {
                sections.append("""
                写作方向规划（作者已确认，续写时必须严格遵循，不得偏离）：
                \(plan)
                """)
            }
            sections.append("""
            续写位置：从"当前章节最近原文"的结尾继续写。必须承接前面章节的发展顺序，不得改错人物身份、称呼、关系、性格基调或已出现设定。
            """)
            return sections.joined(separator: "\n\n")
        }

        guard !plan.isEmpty else { return recentText }

        return """
        当前章节最近原文：
        \(recentText)

        写作方向规划（作者已确认，续写时必须严格遵循，不得偏离）：
        \(plan)
        """
    }

    private func brainstormSource(recentText: String) -> String {
        let previousSummaries = previousSummariesProvider()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !previousSummaries.isEmpty else { return recentText }
        return """
        前面章节结构化摘要（不包含当前章节；已按章节顺序排列）：
        \(previousSummaries)

        当前章节最近原文：
        \(recentText)

        分析截止位置：以上「当前章节最近原文」的结尾。所有建议必须严格基于已出现的信息，不得臆造人物、设定或事件。
        """
    }

    private func showBubble(for session: AIInlineSession, anchorRange: NSRange) {
        guard let tv = textView, let rectInView = selectionRectInView(for: anchorRange) else { return }

        let bubble = AIInlineBubble(session: session)
        let hosting = NSHostingController(rootView: bubble)

        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 380, height: 300)
        popover.delegate = self
        self.popover = popover

        popover.show(relativeTo: rectInView, of: tv, preferredEdge: .maxY)
    }

    private func dismissPopover() {
        let closingPopover = popover
        session?.stop()
        closingPopover?.performClose(nil)
        if popover === closingPopover {
            popover = nil
        }
        session = nil
        targetRange = nil
        removeKeyMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closedPopover = notification.object as? NSPopover,
              closedPopover === popover else { return }
        session?.stop()
        session = nil
        popover = nil
        targetRange = nil
        removeKeyMonitor()
    }

    private func beginNaturalContinueAfterBrainstorm() {
        guard let anchor = targetRange, let session, session.action == .brainstorm else { return }
        let plan = session.resultText
        guard !plan.isEmpty else { return }
        dismissPopover()
        textView?.setSelectedRange(anchor)
        begin(.continueWriting, continueMode: .natural, brainstormPlan: plan)
    }

    // MARK: 就地替换 + 高亮闪烁

    private func applyResult() {
        guard let session else { return }
        let text = session.resultText
        guard !text.isEmpty else { return }
        applyReplacement(text: text)
    }

    private func applyReplacement(text: String? = nil) {
        guard let tv = textView, let session, let target = targetRange else { return }
        let resolvedText = text ?? session.resultText
        guard !resolvedText.isEmpty else { return }

        let clamped = clamp(target, length: (tv.string as NSString).length)
        guard tv.shouldChangeText(in: clamped, replacementString: resolvedText) else { return }
        tv.textStorage?.replaceCharacters(in: clamped, with: resolvedText)
        tv.didChangeText()

        let newRange = NSRange(location: clamped.location, length: (resolvedText as NSString).length)
        tv.setSelectedRange(NSRange(location: newRange.upperBound, length: 0))
        flashHighlight(newRange, in: tv)
        dismissPopover()
    }

    private func flashHighlight(_ range: NSRange, in tv: NSTextView) {
        guard let lm = tv.layoutManager else { return }
        let length = (tv.string as NSString).length
        let clamped = clamp(range, length: length)
        guard clamped.length > 0 else { return }

        let steps = 7
        let total = 0.75
        let base = NSColor.controlAccentColor
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + total * t) { [weak lm] in
                guard let lm else { return }
                let alpha = (1 - t) * 0.30
                if alpha <= 0.001 {
                    lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: clamped)
                } else {
                    lm.addTemporaryAttributes([.backgroundColor: base.withAlphaComponent(alpha)],
                                              forCharacterRange: clamped)
                }
            }
        }
    }

    // MARK: 键盘

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover != nil else { return event }
            switch event.keyCode {
            case 53: // esc
                self.dismissPopover()
                return nil
            case 36, 76: // return / enter
                if self.session?.action == .brainstorm {
                    return event
                }
                if self.session?.canApply == true {
                    self.applyResult()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: 几何

    /// 选区在文本视图坐标系中的矩形（用于 NSPopover 锚点）。
    private func selectionRectInView(for range: NSRange) -> NSRect? {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return nil }
        let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let origin = tv.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        return rect
    }

    private func selectionRectInScreen(for range: NSRange) -> NSRect? {
        guard let tv = textView, let window = tv.window, let rect = selectionRectInView(for: range) else { return nil }
        let inWindow = tv.convert(rect, to: nil)
        return window.convertToScreen(inWindow)
    }

    private func clamp(_ range: NSRange, length: Int) -> NSRange {
        guard range.location != NSNotFound, range.location >= 0 else {
            return NSRange(location: length, length: 0)
        }
        let location = min(range.location, length)
        let maxLength = max(0, length - location)
        return NSRange(location: location, length: min(range.length, maxLength))
    }
}

// MARK: - 浮动药丸

struct AISelectionPill: View {
    let onPolish: (AIPolishMode) -> Void
    let onTranslate: (AITranslateLanguage) -> Void
    let onContinue: (AIContinueMode) -> Void
    let onBrainstorm: () -> Void
    let onQuickCreate: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            polishMenu
            Divider().frame(height: 16)
            translateMenu
            Divider().frame(height: 16)
            continueMenu
            Divider().frame(height: 16)
            brainstormButton
            Divider().frame(height: 16)
            quickCreateButton
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .padding(6)
        .fixedSize()
    }

    private var polishMenu: some View {
        pillMenu(title: "润色", systemImage: "sparkles") {
            ForEach(AIPolishMode.allCases) { mode in
                Button {
                    onPolish(mode)
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                }
                .help(mode.detail)
            }
        }
    }

    private var translateMenu: some View {
        pillMenu(title: "翻译", systemImage: "character.bubble") {
            ForEach(AITranslateLanguage.allCases) { language in
                Button {
                    onTranslate(language)
                } label: {
                    Label(language.title, systemImage: language.systemImage)
                }
            }
        }
    }

    private var continueMenu: some View {
        pillMenu(title: "续写", systemImage: "text.append") {
            ForEach(AIContinueMode.allCases) { mode in
                Button {
                    onContinue(mode)
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                }
                .help(mode.detail)
            }
        }
    }

    private var brainstormButton: some View {
        pillButton(title: "头脑风暴", systemImage: "lightbulb", action: onBrainstorm)
            .help("根据前文分析局面，给出写作方向建议")
    }

    private var quickCreateButton: some View {
        pillButton(title: "快速创作", systemImage: "wand.and.stars", action: onQuickCreate)
            .help("根据梗概扩写成约两千字的小说正文")
    }

    private func pillButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title: title, systemImage: systemImage)
        }
        .controlSize(.small)
        .buttonStyle(.plain)
        .frame(height: 24)
        .fixedSize()
    }

    private func pillLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 14, height: 14)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(minWidth: 54, minHeight: 24)
        .contentShape(Rectangle())
    }

    private func pillMenu<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            pillLabel(title: title, systemImage: systemImage)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.plain)
        .frame(height: 24)
        .fixedSize()
    }
}

// MARK: - 流式气泡

struct AIInlineBubble: View {
    @ObservedObject var session: AIInlineSession

    private var title: String {
        switch session.action {
        case .polish:
            if let mode = session.polishMode, mode != .standard {
                "AI 润色 · \(mode.title)"
            } else {
                "AI 润色"
            }
        case .translate:
            if let language = session.translateLanguage {
                "AI 翻译 · \(language.title)"
            } else {
                "AI 翻译"
            }
        case .continueWriting:
            if let mode = session.continueMode, mode != .natural {
                "AI 续写 · \(mode.title)"
            } else {
                "AI 续写"
            }
        case .brainstorm:
            "头脑风暴"
        case .quickCreate:
            "快速创作"
        }
    }

    private var applyLabel: String {
        if session.action == .continueWriting, session.continueMode?.usesSelectionOnly != true {
            return "插入 ↵"
        }
        return "替换 ↵"
    }

    private var showsRetry: Bool {
        session.errorMessage != nil
            || (!session.isStreaming && session.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if session.isStreaming {
                    ProgressView().controlSize(.small)
                }
            }

            Divider()

            outputView

            HStack(spacing: 8) {
                if showsRetry {
                    Button("重试") { session.onRetry?() }
                        .controlSize(.small)
                }
                Spacer()
                Button("取消") { session.onCancel?() }
                    .controlSize(.small)
                if session.action == .brainstorm {
                    Button("续写") { session.onContinueWriting?() }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .disabled(session.isStreaming || !session.canApply)
                } else {
                    Button {
                        session.onReplace?()
                    } label: {
                        Text(applyLabel)
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(!session.canApply)
                }
            }
        }
        .padding(14)
        .frame(width: 380)
    }

    @ViewBuilder
    private var outputView: some View {
        Group {
            if let error = session.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            } else if session.output.isEmpty, session.isStreaming {
                Text("正在生成…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if session.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("未生成内容。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if session.action == .brainstorm {
                TextEditor(text: $session.output)
                    .font(.system(size: 13))
                    .disabled(session.isStreaming)
                    .frame(minHeight: 140, maxHeight: 200, alignment: .topLeading)
            } else {
                ScrollView {
                    Text(session.output)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topLeading)
    }
}
