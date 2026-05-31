//
//  AIService.swift
//  FWriting
//

import Foundation

enum AIAction: Identifiable {
    case polish
    case translate
    case continueWriting
    case brainstorm
    case quickCreate

    var id: String {
        switch self {
        case .polish: "polish"
        case .translate: "translate"
        case .continueWriting: "continueWriting"
        case .brainstorm: "brainstorm"
        case .quickCreate: "quickCreate"
        }
    }
}

enum AIPolishMode: String, CaseIterable, Identifiable {
    case standard
    case concise
    case expanded
    case formal
    case casual
    case academic
    case preserveStyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "润色"
        case .concise: "精简压缩"
        case .expanded: "扩写润色"
        case .formal: "口语 → 书面"
        case .casual: "书面 → 口语"
        case .academic: "学术/专业"
        case .preserveStyle: "保留原风格"
        }
    }

    var detail: String {
        switch self {
        case .standard: "表达更流畅、专业"
        case .concise: "删冗余，缩短篇幅"
        case .expanded: "在不改意思的前提下写得更饱满"
        case .formal: "日记、对话改正式文体"
        case .casual: "网文、公众号更自然"
        case .academic: "论文、报告语气"
        case .preserveStyle: "只修语病，不动文风"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "sparkles"
        case .concise: "text.badge.minus"
        case .expanded: "text.badge.plus"
        case .formal: "textformat"
        case .casual: "bubble.left"
        case .academic: "graduationcap"
        case .preserveStyle: "checkmark.seal"
        }
    }

    var instruction: String {
        switch self {
        case .standard:
            "保持原意，让表达更流畅、自然、专业。"
        case .concise:
            "删除冗余、重复和空泛表达，缩短篇幅，但保留关键信息。"
        case .expanded:
            "在不改变原意的前提下补足细节和衔接，让表达更饱满。"
        case .formal:
            "将口语、日记或对话式表达改为正式书面文体。"
        case .casual:
            "将偏书面的表达改为更自然的口语、网文或公众号语气。"
        case .academic:
            "调整为学术或专业写作语气，适合论文、报告和正式材料。"
        case .preserveStyle:
            "只修正语病、错别字、标点和不通顺处，不改变原有文风。"
        }
    }
}

enum AITranslateLanguage: String, CaseIterable, Identifiable {
    case chinese
    case english
    case french
    case russian
    case kazakh
    case uzbek
    case ukrainian
    case malay
    case indonesian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: "中文"
        case .english: "英语"
        case .french: "法语"
        case .russian: "俄语"
        case .kazakh: "哈萨克语"
        case .uzbek: "乌兹别克语"
        case .ukrainian: "乌克兰语"
        case .malay: "马来语"
        case .indonesian: "印尼语"
        }
    }

    var systemImage: String {
        switch self {
        case .chinese: "character"
        case .english: "textformat.abc"
        case .french: "f.circle"
        case .russian: "r.circle"
        case .kazakh: "k.circle"
        case .uzbek: "u.circle"
        case .ukrainian: "u.square"
        case .malay: "m.circle"
        case .indonesian: "i.circle"
        }
    }
}

enum AIContinueMode: String, CaseIterable, Identifiable {
    case natural
    case complete
    case supplement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: "自然续写"
        case .complete: "完整续写"
        case .supplement: "补充续写"
        }
    }

    var systemImage: String {
        switch self {
        case .natural: "sparkles"
        case .complete: "doc.text.magnifyingglass"
        case .supplement: "text.badge.plus"
        }
    }

    var detail: String {
        switch self {
        case .natural: "从光标前文接着写，保持连贯"
        case .complete: "结合前面章节摘要与当前章前文续写"
        case .supplement: "仅丰富选中片段的细节描写，不使用前后文"
        }
    }

    var instruction: String {
        switch self {
        case .natural:
            "从最后一句直接接住当前场景，继续展开人物动作、对话、心理和情节因果，让剧情往下一步发展；不要把本段写成章节结尾、故事结局或总结陈词，不要用“终于、从此、多年以后、一切都结束了”这类收束语气。"
        case .complete:
            "结合前面章节摘要里的【人物与关系】【重要设定】【续写提醒】和当前章节最近原文续写，保持人物身份、称呼、关系、设定、伏笔和文风一致；仍然按接续式往下描写情节，不要快速收尾。"
        case .supplement:
            "只根据用户消息中的选中片段，丰富行为细节、动作、神态、心理、感官与环境描写，让画面更具体；保持原意、人称、时态和文风，不引入段外信息，不接龙续写后文，不改变情节走向。"
        }
    }

    /// 仅处理选中文字、替换选区，不读取光标前文或章节摘要。
    var usesSelectionOnly: Bool {
        self == .supplement
    }
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "请先在设置中配置 DeepSeek API Key"
        case .invalidResponse: "AI 返回了无效响应"
        case .apiError(let message): message
        }
    }
}

enum AIService {
    static let defaultModel = "deepseek-v4-flash"
    static let defaultBaseURL = "https://api.deepseek.com/chat/completions"

    static let apiKeyKey = "aiAPIKey"
    static let modelKey = "aiDefaultModel"
    static let polishPromptKey = "aiPolishPrompt"
    static let translatePromptKey = "aiTranslatePrompt"
    static let continuePromptKey = "aiContinuePrompt"
    static let baseURLKey = "aiBaseURL"
    static let disableThinkingKey = "aiDisableThinking"

    static let continueMaxWordCount = 1500
    static let continueHardMaxWordCount = 1600
    static let brainstormContinueMaxWordCount = 5000
    static let continueContextMaxCharacters = 5000
    static let summaryMaxWordCount = 800
    static let brainstormMaxWordCount = 800
    static let supplementMaxWordCount = 1200
    /// 快速创作目标篇幅（提示词参考，非硬截断）
    static let quickCreateTargetWordCount = 2000
    /// 超出此字数时在句末软截断，避免无限增长
    static let quickCreateHardMaxWordCount = 3200

    static let defaultPolishPrompt = """
你是写作润色工具。用户消息即为待润色原文。
要求：保持原意，表达更流畅、专业。
输出：仅输出润色后的正文，可直接替换原文。禁止前缀、后缀、解释、标题、引号、Markdown 或任何说明性文字。
"""

    static let defaultTranslatePrompt = """
你是翻译工具。用户消息即为待翻译原文。
要求：译为中文，准确、自然。
输出：仅输出译文，可直接替换原文。禁止前缀、后缀、解释、引号或任何说明性文字。
"""

    static let defaultContinuePrompt = """
你是写作续写工具。用户消息为已有前文。
要求：根据前文风格、语气与内容自然续写，保持连贯。
续写方式：从前文最后一处动作、对话或心理状态直接接着写，重点写“接下来发生什么”，通过具体场景、动作、对话、心理和因果推进情节。
禁止：不要快速结束剧情，不要总结全文或本章，不要写大结局、尾声、事后回顾或“从此以后、许多年后、一切结束”式收束；除非前文明确已经进入结局，否则保持故事仍可继续发展。
长度：续写正文以 1500 字左右为目标。接近 1500 字时只需要把当前句子写完整并在句末暂停，这是因为字数限制而暂停，不代表剧情结束；不要为了制造结尾而总结、告别或收束人物命运。
输出：仅输出续写正文，可直接接在前文之后。禁止前缀、后缀、解释、标题、引号、Markdown 或任何说明性文字。
"""

    private static let defaultSupplementPrompt = """
你是写作细节扩写工具。用户消息为作者选中的一段正文，不包含前后文。
要求：只根据这段文字本身，丰富行为细节、动作、神态、心理、感官与环境描写，让画面更具体可感；保持原意、人称、时态、语气与文风，不引入段外人物或事件。
禁止：不要参考或臆造前后文，不要接龙续写后文，不要改变情节走向，不要写成总结或说明。
长度：改写后篇幅不超过原文 3 倍，优先补足细节而非堆砌空话。
输出：仅输出改写后的完整片段，可直接替换原文。禁止前缀、后缀、解释、标题、引号、Markdown 或任何说明性文字。
"""

    private static let defaultQuickCreatePrompt = """
你是小说创作助手。用户消息为作者写下的故事梗概、剧情设想或片段灵感。
要求：将其扩写成可直接阅读的小说正文，写出具体场景、人物、对话与情节推进；必须尊重梗概中的人设、关系、背景与核心走向，可合理补足细节，不得推翻或无视原意。
篇幅：大约 2000 字左右即可，不必凑满；写完整句、完整场景，不要水字数，也不要为了收尾而写成结局或总结。
输出：仅输出小说正文。禁止标题、提纲、人设表、栏目名、前缀后缀、解释、引号包裹或 Markdown 标题列表。
"""

    private static let defaultBrainstormPrompt = """
你是写作策划助手。用户消息为已有前文（可能含前面章节摘要与当前章节最近原文）。
要求：严格基于前文已写内容，分析当前局面并给出下一步写作方向建议；所有判断必须能在前文中找到依据，不得引入前文中不存在的人物、设定、关系或事件，不得改错已有细节。
禁止：不要写正文、不要续写、不要替作者代写段落，不要脱离前文空想新剧情。
长度：800 字以内。
输出：仅输出策划建议。禁止前缀、后缀、解释性开场、引号或 Markdown 列表符号。
输出格式（栏目名必须保留）：

【当前局面】
前文停在哪里，人物在做什么，情绪与冲突处于什么状态。

【前文依据】
列出 3-5 条做出判断时所依赖的前文事实（人物、关系、伏笔、设定）。

【写作方向】
给出 2-3 个可继续发展的方向；每个方向说明如何承接前文、可能推动什么冲突或变化。

【续写提醒】
写接下来几段时需要遵守的约束（称呼、关系、基调、不要碰的雷区）。
"""

    private static let defaultSummaryPrompt = """
你是章节摘要工具。用户消息为当前章节正文。
要求：生成用于后续 AI 续写的结构化记忆，重点不是复述全文，而是保留人物、关系、设定、当前状态和不能写错的细节。
长度：800 字以内。
输出：仅输出以下七个栏目，栏目名必须保留，不要 Markdown 列表符号，不要解释。

【章节位置】
写清这是第几章、章节标题、在当前作品/项目中的位置；如果用户提供了上一章/下一章标题，也要写出承接关系。

【章节摘要】
概括本章主要事件、冲突和进展。

【发展脉络】
按时间顺序写清本章内容如何推进：开端是什么，中间发生了哪些变化，最后停在哪里；尤其写清人物关系、冲突和情绪怎么变化。

【人物与关系】
列出本章出现或被提及的人物；写清身份、称呼、性格倾向、彼此关系和关系变化。

【重要设定】
记录地点、职业、生活习惯、物品、背景规则、已埋伏笔和不能前后矛盾的细节。

【当前状态】
写清本章结束时人物所在位置、动作、情绪、关系状态和未解决的问题。

【续写提醒】
写给续写模型的注意事项：人物不能突然变性格，称呼不能乱，关系不能跳跃，不要引入无铺垫的新人物或设定。
"""

    private static let legacyWeakPolishPrompts: Set<String> = [
        "请润色以下文本，保持原意，使表达更流畅、专业：",
        "请润色以下文本，保持原意，使表达更流畅、专业。只返回润色后的正文，不要解释、不要加引号。",
    ]

    private static let legacyWeakTranslatePrompts: Set<String> = [
        "请将以下文本翻译为中文，保持专业、准确：",
        "请将以下文本翻译为中文，保持专业、准确。只返回译文，不要解释。",
    ]

    private static let legacyWeakContinuePrompts: Set<String> = [
        "请根据前文续写，保持风格一致：",
        "请根据前文自然续写，不超过 1500 字。只返回续写正文，不要解释。",
        """
你是写作续写工具。用户消息为已有前文。
要求：根据前文风格、语气与内容自然续写，保持连贯。
长度：续写正文以 1500 字左右为目标。接近 1500 字时必须把当前句子写完整，并在句末自然停止；不要为了展开新内容继续生成。
输出：仅输出续写正文，可直接接在前文之后。禁止前缀、后缀、解释、标题、引号、Markdown 或任何说明性文字。
""",
    ]

    private static let legacyWrongModels: Set<String> = [
        "DeepSeekv4flash",
        "DeepSeek-v4-flash",
        "gpt-4o",
        "deepseek-chat",
        "deepseek-reasoner",
    ]

    static var apiKey: String {
        UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
    }

    static var model: String {
        let stored = UserDefaults.standard.string(forKey: modelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if stored.isEmpty || legacyWrongModels.contains(stored) {
            return defaultModel
        }
        return stored
    }

    static var disableThinking: Bool {
        if UserDefaults.standard.object(forKey: disableThinkingKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: disableThinkingKey)
    }

    /// 润色/翻译/续写/头脑风暴需要直接流式输出正文，不能等推理阶段结束。
    private static func usesDirectOutput(for action: AIAction) -> Bool {
        switch action {
        case .polish, .translate, .continueWriting, .brainstorm, .quickCreate:
            return true
        }
    }

    private static func thinkingType(for action: AIAction) -> String {
        if usesDirectOutput(for: action) || disableThinking {
            return "disabled"
        }
        return "enabled"
    }

    static var baseURL: String {
        let stored = UserDefaults.standard.string(forKey: baseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty || stored == "https://api.openai.com/v1/chat/completions" ? defaultBaseURL : stored
    }

    static var modelsListURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        var path = components.path
        if path.hasSuffix("/chat/completions") {
            path = String(path.dropLast("/chat/completions".count))
        } else if path.hasSuffix("/v1/chat/completions") {
            path = String(path.dropLast("/v1/chat/completions".count))
        }
        components.path = path + "/models"
        return components.url
    }

    static func fetchModels() async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIServiceError.missingAPIKey }
        guard let url = modelsListURL else { throw AIServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }

        if http.statusCode != 200 {
            throw apiError(from: data, statusCode: http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let models = json["data"] as? [[String: Any]]
        else {
            throw AIServiceError.invalidResponse
        }

        let ids = models.compactMap { $0["id"] as? String }.sorted()
        guard !ids.isEmpty else { throw AIServiceError.invalidResponse }
        return ids
    }

    static func normalizeLegacyModel(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || legacyWrongModels.contains(trimmed) {
            return defaultModel
        }
        return trimmed
    }

    static func prompt(
        for action: AIAction,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) -> String {
        switch action {
        case .polish:
            let stored = UserDefaults.standard.string(forKey: polishPromptKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let basePrompt = stored.isEmpty || legacyWeakPolishPrompts.contains(stored) ? defaultPolishPrompt : stored
            return promptWithPolishMode(basePrompt, mode: polishMode)
        case .translate:
            let stored = UserDefaults.standard.string(forKey: translatePromptKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let basePrompt = stored.isEmpty || legacyWeakTranslatePrompts.contains(stored) ? defaultTranslatePrompt : stored
            return promptWithTranslateLanguage(basePrompt, language: translateLanguage)
        case .continueWriting:
            if continueMode == .supplement {
                return defaultSupplementPrompt
            }
            let stored = UserDefaults.standard.string(forKey: continuePromptKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let basePrompt = stored.isEmpty || legacyWeakContinuePrompts.contains(stored) ? defaultContinuePrompt : stored
            return promptWithContinueMode(basePrompt, mode: continueMode, targetWordCount: continueTargetWordCount)
        case .brainstorm:
            return defaultBrainstormPrompt
        case .quickCreate:
            return defaultQuickCreatePrompt
        }
    }

    private static func promptWithPolishMode(_ prompt: String, mode: AIPolishMode?) -> String {
        guard let mode, mode != .standard else { return prompt }
        return """
        \(prompt)
        本次润色方式：\(mode.instruction)
        """
    }

    private static func promptWithTranslateLanguage(_ prompt: String, language: AITranslateLanguage?) -> String {
        guard let language else { return prompt }
        return """
        \(prompt)
        本次翻译目标语言：\(language.title)。必须译为\(language.title)，仅输出译文正文。
        """
    }

    private static func promptWithContinueMode(
        _ prompt: String,
        mode: AIContinueMode?,
        targetWordCount: Int? = nil
    ) -> String {
        let resolvedMode = mode ?? .natural
        let target = targetWordCount ?? continueMaxWordCount
        let hardLimit = "长度限制：续写以 \(target) 字左右为目标，按中文字符和英文单词计数；接近目标后必须写完整当前句子并在句末暂停，不要开启新句或新段；这个暂停只是因为字数限制，不是剧情结尾，不要额外写总结、告别、尾声或命运收束。"
        switch resolvedMode {
        case .natural:
            return """
            \(prompt)
            \(hardLimit)
            本次续写方向：\(resolvedMode.instruction)
            """
        case .complete:
            return """
            \(prompt)
            \(hardLimit)
            本次续写方向：\(resolvedMode.instruction)
            如果用户消息包含前面章节摘要，请优先遵守其中的【人物与关系】【重要设定】【当前状态】【续写提醒】；不得改错人物身份、称呼、关系、性格基调或已出现设定。
            """
        case .supplement:
            return defaultSupplementPrompt
        }
    }

    static func normalizeLegacyPrompts() {
        let polish = UserDefaults.standard.string(forKey: polishPromptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if polish.isEmpty || legacyWeakPolishPrompts.contains(polish) {
            UserDefaults.standard.set(defaultPolishPrompt, forKey: polishPromptKey)
        }

        let translate = UserDefaults.standard.string(forKey: translatePromptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if translate.isEmpty || legacyWeakTranslatePrompts.contains(translate) {
            UserDefaults.standard.set(defaultTranslatePrompt, forKey: translatePromptKey)
        }

        let continuePrompt = UserDefaults.standard.string(forKey: continuePromptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if continuePrompt.isEmpty || legacyWeakContinuePrompts.contains(continuePrompt) {
            UserDefaults.standard.set(defaultContinuePrompt, forKey: continuePromptKey)
        }
    }

    /// 剥离模型偶发返回的前缀说明、引号包裹等，只保留可替换正文。
    static func sanitizeOutput(_ text: String, for action: AIAction) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        if action == .continueWriting || action == .quickCreate {
            return sanitizeContinueOutput(result)
        }
        if action == .brainstorm {
            return sanitizeBrainstormOutput(result)
        }

        if let unwrapped = unwrapQuotedContent(from: result) {
            result = unwrapped
        }

        let blocks = result.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if blocks.count > 1, isPreamble(blocks[0], for: action) {
            result = blocks.dropFirst().joined(separator: "\n\n")
        } else if let colonSplit = splitAfterPreambleColon(result, for: action) {
            result = colonSplit
        }

        if let unwrapped = unwrapQuotedContent(from: result) {
            result = unwrapped
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 续写正文里常出现「继续」「接着」和对话冒号，不能用通用前言规则处理全文。
    private static func sanitizeContinueOutput(_ text: String) -> String {
        var result = text

        let blocks = result.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if blocks.count > 1, isContinuePreamble(blocks[0]) {
            result = blocks.dropFirst().joined(separator: "\n\n")
        } else if let firstLine = result.components(separatedBy: .newlines).first,
                  isContinuePreamble(firstLine),
                  let stripped = stripLeadingContinuePreamble(from: result) {
            result = stripped
        }

        if let unwrapped = unwrapQuotedContent(from: result) {
            result = unwrapped
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isContinuePreamble(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120 else { return false }
        let metaPhrases = [
            "以下", "续写如下", "续写内容", "为您续写", "我来续写", "接着续写",
            "好的，", "当然，", "明白，", "以下是",
        ]
        return metaPhrases.contains { trimmed.contains($0) }
    }

    private static func stripLeadingContinuePreamble(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              isContinuePreamble(firstLine) else { return nil }

        if let separatorIndex = firstLine.lastIndex(where: { $0 == "：" || $0 == ":" }) {
            let tail = String(firstLine[firstLine.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                return rest.isEmpty ? tail : tail + "\n" + rest
            }
        }

        let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    private static func sanitizeBrainstormOutput(_ text: String) -> String {
        var result = text
        if let firstLine = result.components(separatedBy: .newlines).first,
           isBrainstormPreamble(firstLine),
           let stripped = stripLeadingBrainstormPreamble(from: result) {
            result = stripped
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isBrainstormPreamble(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120 else { return false }
        let metaPhrases = ["以下", "好的，", "当然，", "明白，", "以下是", "头脑风暴", "写作建议", "策划建议"]
        return metaPhrases.contains { trimmed.contains($0) }
    }

    private static func stripLeadingBrainstormPreamble(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              isBrainstormPreamble(firstLine) else { return nil }

        if let separatorIndex = firstLine.lastIndex(where: { $0 == "：" || $0 == ":" }) {
            let tail = String(firstLine[firstLine.index(after: separatorIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                return rest.isEmpty ? tail : tail + "\n" + rest
            }
        }

        let rest = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    static func truncateBrainstormOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingStatsService.wordCount(for: result) > brainstormMaxWordCount else { return result }
        while !result.isEmpty, WritingStatsService.wordCount(for: result) > brainstormMaxWordCount {
            result = String(result.dropLast())
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func truncateSupplementOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingStatsService.wordCount(for: result) > supplementMaxWordCount else { return result }
        while !result.isEmpty, WritingStatsService.wordCount(for: result) > supplementMaxWordCount {
            result = String(result.dropLast())
        }
        return trimToSentenceEnd(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func truncateContinueOutput(_ text: String, hardLimit: Int = continueHardMaxWordCount) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingStatsService.wordCount(for: result) > hardLimit else { return result }
        while !result.isEmpty, WritingStatsService.wordCount(for: result) > hardLimit {
            result = String(result.dropLast())
        }
        return trimToSentenceEnd(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizeSummaryOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let unwrapped = unwrapQuotedContent(from: result) {
            result = unwrapped
        }
        let prefixes = ["摘要：", "摘要:", "章节摘要：", "章节摘要:"]
        for prefix in prefixes where result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private static func truncateSummaryOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingStatsService.wordCount(for: result) > summaryMaxWordCount else { return result }
        while !result.isEmpty, WritingStatsService.wordCount(for: result) > summaryMaxWordCount {
            result = String(result.dropLast())
        }
        return trimToSentenceEnd(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isPreamble(_ text: String, for action: AIAction) -> Bool {
        let keywords: [String]
        switch action {
        case .polish:
            keywords = ["以下", "润色", "版本", "为您", "修改", "优化", "明白", "好的，"]
        case .translate:
            keywords = ["以下", "翻译", "译文", "为您", "中文"]
        case .continueWriting:
            keywords = ["以下", "续写", "为您", "接着", "继续"]
        case .brainstorm:
            keywords = ["以下", "头脑风暴", "写作建议", "策划建议", "为您", "好的，"]
        case .quickCreate:
            keywords = ["以下", "快速创作", "扩写", "正文如下", "为您", "好的，"]
        }
        return keywords.contains { text.contains($0) }
    }

    private static func splitAfterPreambleColon(_ text: String, for action: AIAction) -> String? {
        guard isPreamble(text, for: action) else { return nil }
        let separators: [Swift.Character] = ["：", ":"]
        for separator in separators where text.contains(separator) {
            if let index = text.lastIndex(of: separator) {
                let tail = String(text[text.index(after: index)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty, tail.count < text.count {
                    return tail
                }
            }
        }
        return nil
    }

    private static func unwrapQuotedContent(from text: String) -> String? {
        let pairs: [(String, String)] = [
            ("\"", "\""),
            ("「", "」"),
            ("『", "』"),
            ("“", "”"),
            ("‘", "’"),
        ]
        for (open, close) in pairs {
            guard text.hasPrefix(open), text.hasSuffix(close), text.count >= open.count + close.count else { continue }
            let inner = String(text.dropFirst(open.count).dropLast(close.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty { return inner }
        }
        return nil
    }

    private static func temperature(for action: AIAction, continueMode: AIContinueMode? = nil) -> Double {
        if action == .continueWriting, continueMode == .supplement {
            return 0.5
        }
        switch action {
        case .continueWriting:
            return 0.7
        case .brainstorm:
            return 0.4
        case .quickCreate:
            return 0.75
        default:
            return 0.3
        }
    }

    private static func makeRequest(
        text: String,
        action: AIAction,
        stream: Bool,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIServiceError.missingAPIKey }

        let body: [String: Any] = {
            var payload: [String: Any] = [
                "model": model,
                "messages": [
                    [
                        "role": "system",
                        "content": prompt(
                            for: action,
                            polishMode: polishMode,
                            translateLanguage: translateLanguage,
                            continueMode: continueMode,
                            continueTargetWordCount: continueTargetWordCount
                        )
                    ],
                    ["role": "user", "content": text]
                ],
                "thinking": ["type": thinkingType(for: action)],
                "temperature": temperature(for: action, continueMode: continueMode),
                "stream": stream
            ]
            switch action {
            case .continueWriting:
                if continueMode == .supplement {
                    payload["max_tokens"] = 1024
                } else if (continueTargetWordCount ?? continueMaxWordCount) >= brainstormContinueMaxWordCount {
                    payload["max_tokens"] = 7000
                } else {
                    payload["max_tokens"] = 2048
                }
            case .brainstorm:
                payload["max_tokens"] = 900
            case .quickCreate:
                payload["max_tokens"] = 4096
            default:
                break
            }
            return payload
        }()

        guard let url = URL(string: baseURL) else { throw AIServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func parseStreamPayload(_ payload: String) -> (content: String?, error: String?) {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return (nil, message)
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty else {
            return (nil, nil)
        }

        return (content, nil)
    }

    private static func makeSummaryRequest(text: String, title: String, chapterContext: String) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIServiceError.missingAPIKey }

        let userContent = """
        章节标题：\(title)

        章节信息：
        \(chapterContext)

        章节正文：
        \(text)
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": defaultSummaryPrompt],
                ["role": "user", "content": userContent]
            ],
            "thinking": ["type": thinkingType(for: .continueWriting)],
            "temperature": 0.2,
            "max_tokens": 700,
            "stream": false
        ]

        guard let url = URL(string: baseURL) else { throw AIServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func summarize(text: String, title: String, chapterContext: String = "未提供") async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let request = try makeSummaryRequest(text: trimmed, title: title, chapterContext: chapterContext)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }

        if http.statusCode != 200 {
            throw apiError(from: data, statusCode: http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIServiceError.invalidResponse
        }

        return truncateSummaryOutput(sanitizeSummaryOutput(content))
    }

    static func process(
        text: String,
        action: AIAction,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        let request = try makeRequest(
            text: text,
            action: action,
            stream: false,
            polishMode: polishMode,
            translateLanguage: translateLanguage,
            continueMode: continueMode,
            continueTargetWordCount: continueTargetWordCount
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }

        if http.statusCode != 200 {
            throw apiError(from: data, statusCode: http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIServiceError.invalidResponse
        }

        return finalizeOutput(
            content,
            for: action,
            continueMode: continueMode,
            continueTargetWordCount: continueTargetWordCount
        )
    }

    static func finalizeOutput(
        _ text: String,
        for action: AIAction,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) -> String {
        let sanitized = sanitizeOutput(text, for: action)
        switch action {
        case .continueWriting:
            if continueMode == .supplement {
                return truncateSupplementOutput(sanitized)
            }
            let hardLimit = continueTargetWordCount ?? continueHardMaxWordCount
            return truncateContinueOutput(sanitized, hardLimit: hardLimit)
        case .brainstorm:
            return truncateBrainstormOutput(sanitized)
        case .quickCreate:
            return truncateQuickCreateOutput(sanitized)
        default:
            return sanitized
        }
    }

    private static func truncateQuickCreateOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard WritingStatsService.wordCount(for: result) > quickCreateHardMaxWordCount else { return result }
        while !result.isEmpty, WritingStatsService.wordCount(for: result) > quickCreateHardMaxWordCount {
            result = String(result.dropLast())
        }
        return trimToSentenceEnd(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 流式处理：逐段返回增量文本（token delta）。
    static func processStream(
        text: String,
        action: AIAction,
        polishMode: AIPolishMode? = nil,
        translateLanguage: AITranslateLanguage? = nil,
        continueMode: AIContinueMode? = nil,
        continueTargetWordCount: Int? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continuation.finish()
                        return
                    }
                    let request = try makeRequest(
                        text: text,
                        action: action,
                        stream: true,
                        polishMode: polishMode,
                        translateLanguage: translateLanguage,
                        continueMode: continueMode,
                        continueTargetWordCount: continueTargetWordCount
                    )
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }

                    if http.statusCode != 200 {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        throw apiError(from: data, statusCode: http.statusCode)
                    }

                    var continueOutput = ""
                    var receivedContent = false
                    let streamStart = Date()
                    let streamTimeout: TimeInterval = 300
                    let continueTarget = continueTargetWordCount ?? continueMaxWordCount
                    let continueHardLimit = continueTargetWordCount ?? continueHardMaxWordCount

                    for try await line in bytes.lines {
                        if Date().timeIntervalSince(streamStart) > streamTimeout {
                            throw AIServiceError.apiError("AI 响应超时，请稍后重试。")
                        }

                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }

                        let parsed = parseStreamPayload(payload)
                        if let error = parsed.error {
                            throw AIServiceError.apiError(error)
                        }
                        guard let content = parsed.content else { continue }

                        receivedContent = true

                        if action == .continueWriting, continueMode != .supplement {
                            let candidate = continueOutput + content
                            if WritingStatsService.wordCount(for: candidate) > continueHardLimit {
                                let allowed = continueAllowedChunk(
                                    current: continueOutput,
                                    chunk: content,
                                    hardLimit: continueHardLimit
                                )
                                if !allowed.isEmpty {
                                    continuation.yield(allowed)
                                }
                                break
                            }

                            continuation.yield(content)
                            continueOutput = candidate
                            if WritingStatsService.wordCount(for: continueOutput) >= continueTarget,
                               endsAtSentenceBoundary(continueOutput) {
                                break
                            }
                            continue
                        }

                        continuation.yield(content)
                    }

                    if usesDirectOutput(for: action), !receivedContent {
                        throw AIServiceError.apiError("AI 未返回内容，请确认 API Key、模型与网络连接。")
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func continueAllowedChunk(current: String, chunk: String, hardLimit: Int = continueHardMaxWordCount) -> String {
        var allowed = chunk
        while !allowed.isEmpty,
              WritingStatsService.wordCount(for: current + allowed) > hardLimit {
            allowed = String(allowed.dropLast())
        }
        return trimToSentenceEnd(allowed).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func endsAtSentenceBoundary(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return isSentenceTerminator(last)
    }

    private static func trimToSentenceEnd(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !endsAtSentenceBoundary(trimmed) else { return trimmed }
        guard let index = trimmed.lastIndex(where: { isSentenceTerminator($0) }) else {
            return trimmed
        }
        return String(trimmed[...index])
    }

    private static let sentenceTerminators = CharacterSet(charactersIn: "。．.!?！？…")

    private static func isSentenceTerminator(_ character: Swift.Character) -> Bool {
        character.unicodeScalars.contains { sentenceTerminators.contains($0) }
    }

    private static func apiError(from data: Data, statusCode: Int) -> AIServiceError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .apiError(message)
        }
        return .apiError("HTTP \(statusCode)")
    }
}
