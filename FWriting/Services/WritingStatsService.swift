//
//  WritingStatsService.swift
//  FWriting
//

import Foundation

struct WritingStats {
    var characters: Int = 0
    var charactersNoSpaces: Int = 0
    var words: Int = 0
    var sentences: Int = 0
    var paragraphs: Int = 0
    var lines: Int = 0
    var pages: Double = 0

    var wordsPerSentence: Double {
        sentences > 0 ? Double(words) / Double(sentences) : 0
    }

    /// 各档阅读 / 朗读用时（秒）。
    var slowSeconds: Int { seconds(wpm: 200) }
    var averageSeconds: Int { seconds(wpm: 300) }
    var fastSeconds: Int { seconds(wpm: 450) }
    var readAloudSeconds: Int { seconds(wpm: 150) }

    private func seconds(wpm: Double) -> Int {
        guard words > 0 else { return 0 }
        return Int(ceil(Double(words) / wpm * 60))
    }
}

enum WritingStatsService {
    /// 中文字数：CJK 字符 + 英文单词
    static func wordCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        var count = 0
        var inWord = false

        for scalar in trimmed.unicodeScalars {
            if isCJK(scalar) {
                if inWord { inWord = false }
                count += 1
            } else if CharacterSet.letters.contains(scalar) {
                if !inWord {
                    count += 1
                    inWord = true
                }
            } else {
                inWord = false
            }
        }
        return count
    }

    static func characterCount(for text: String) -> Int {
        text.count
    }

    static func readingMinutes(for text: String) -> Int {
        let words = wordCount(for: text)
        guard words > 0 else { return 0 }
        let cjkRatio = cjkRatio(in: text)
        let wordsPerMinute = cjkRatio > 0.3 ? 350.0 : 200.0
        return max(1, Int(ceil(Double(words) / wordsPerMinute)))
    }

    /// 完整统计指标。
    static func stats(for text: String) -> WritingStats {
        var stats = WritingStats()
        stats.characters = text.count
        stats.charactersNoSpaces = text.unicodeScalars.reduce(into: 0) { partial, scalar in
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) { partial += 1 }
        }
        stats.words = wordCount(for: text)
        stats.sentences = sentenceCount(for: text)
        stats.paragraphs = paragraphCount(for: text)
        stats.lines = lineCount(for: text)
        stats.pages = stats.words > 0 ? max(0.1, (Double(stats.words) / 500).rounded(toPlaces: 1)) : 0
        return stats
    }

    static func sentenceCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let terminators = CharacterSet(charactersIn: "。．.!?！？…\n")
        let parts = trimmed
            .components(separatedBy: terminators)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return max(1, parts.count)
    }

    static func paragraphCount(for text: String) -> Int {
        let blocks = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var count = 0
        var inParagraph = false
        for line in blocks {
            if line.isEmpty {
                inParagraph = false
            } else if !inParagraph {
                count += 1
                inParagraph = true
            }
        }
        return count
    }

    static func lineCount(for text: String) -> Int {
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.count
    }

    static func formattedWordCount(_ count: Int) -> String {
        count.formatted(.number.grouping(.automatic))
    }

    static func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) 秒"
        }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(rest) 秒"
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF,
             0x3040...0x309F, 0x30A0...0x30FF, 0xAC00...0xD7AF:
            return true
        default:
            return false
        }
    }

    private static func cjkRatio(in text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        var cjk = 0
        var total = 0
        for scalar in text.unicodeScalars {
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                total += 1
                if isCJK(scalar) { cjk += 1 }
            }
        }
        return total > 0 ? Double(cjk) / Double(total) : 0
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
