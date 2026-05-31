//
//  LineHighlightLayoutManager.swift
//  FWriting
//

import AppKit

final class LineHighlightLayoutManager: NSLayoutManager {
    weak var hostTextView: NSTextView?
    var showsLineHighlight = false
    var showsParagraphFocus = false
    private let horizontalHighlightPadding: CGFloat = 6

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard showsLineHighlight || showsParagraphFocus,
              let textView = hostTextView,
              let textContainer = textView.textContainer else { return }

        if showsParagraphFocus,
           let paragraphRange = currentParagraphRange(in: textView),
           drawParagraphHighlight(
                paragraphRange,
                glyphsToShow: glyphsToShow,
                origin: origin,
                textView: textView,
                textContainer: textContainer
           ) {
            return
        }

        guard showsLineHighlight,
              let glyphIndex = currentCaretGlyphIndex(in: textView) else { return }

        drawLineHighlight(
            forGlyphAt: glyphIndex,
            glyphsToShow: glyphsToShow,
            origin: origin,
            textView: textView,
            textContainer: textContainer
        )
    }

    @discardableResult
    private func drawParagraphHighlight(
        _ paragraphRange: NSRange,
        glyphsToShow: NSRange,
        origin: CGPoint,
        textView: NSTextView,
        textContainer: NSTextContainer
    ) -> Bool {
        let paragraphGlyphRange = glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
        guard paragraphGlyphRange.length > 0 else {
            guard let glyphIndex = currentCaretGlyphIndex(in: textView) else { return false }
            drawLineHighlight(
                forGlyphAt: glyphIndex,
                glyphsToShow: glyphsToShow,
                origin: origin,
                textView: textView,
                textContainer: textContainer
            )
            return true
        }

        var didDraw = false
        var glyphIndex = paragraphGlyphRange.location
        let paragraphGlyphUpperBound = NSMaxRange(paragraphGlyphRange)

        while glyphIndex < paragraphGlyphUpperBound {
            var fragmentRange = NSRange(location: 0, length: 0)
            _ = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentRange)
            let nextGlyphIndex = NSMaxRange(fragmentRange)

            if NSIntersectionRange(fragmentRange, paragraphGlyphRange).length > 0 {
                drawLineHighlight(
                    forGlyphAt: glyphIndex,
                    glyphsToShow: glyphsToShow,
                    origin: origin,
                    textView: textView,
                    textContainer: textContainer
                )
                didDraw = true
            }

            guard nextGlyphIndex > glyphIndex else { break }
            glyphIndex = nextGlyphIndex
        }

        return didDraw
    }

    private func drawLineHighlight(
        forGlyphAt glyphIndex: Int,
        glyphsToShow: NSRange,
        origin: CGPoint,
        textView: NSTextView,
        textContainer: NSTextContainer
    ) {
        var fragmentRange = NSRange(location: 0, length: 0)
        let fragmentRect = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentRange)
        guard fragmentRange.length == 0 || NSIntersectionRange(fragmentRange, glyphsToShow).length > 0 else { return }

        let minX = max(0, fragmentRect.minX - horizontalHighlightPadding)
        let highlightWidth = textContainer.containerSize.width - minX

        var highlightRect = fragmentRect
        highlightRect.origin.x = origin.x + minX
        highlightRect.origin.y += origin.y
        highlightRect.size.width = highlightWidth

        NSColor.labelColor.withAlphaComponent(0.05).setFill()
        NSBezierPath(roundedRect: highlightRect.insetBy(dx: 0, dy: 1), xRadius: 3, yRadius: 3).fill()
    }

    private func currentParagraphRange(in textView: NSTextView) -> NSRange? {
        let text = textView.string as NSString
        guard text.length > 0 else { return nil }
        let caretLocation = min(textView.selectedRange.location, text.length)
        return text.paragraphRange(for: NSRange(location: caretLocation, length: 0))
    }

    private func currentCaretGlyphIndex(in textView: NSTextView) -> Int? {
        guard let textContainer = textView.textContainer else { return nil }
        ensureLayout(for: textContainer)

        let glyphCount = numberOfGlyphs
        guard glyphCount > 0 else { return nil }

        let text = textView.string as NSString
        let charCount = text.length
        let caretLocation = min(textView.selectedRange.location, charCount)

        if caretLocation >= charCount {
            return glyphCount - 1
        }

        return min(glyphIndexForCharacter(at: caretLocation), glyphCount - 1)
    }
}
