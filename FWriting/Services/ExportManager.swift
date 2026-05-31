//
//  ExportManager.swift
//  FWriting
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case txt
    case pdf
    case html
    case rtf
    case docx
    case epub

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .txt: "纯文本"
        case .pdf: "PDF"
        case .html: "HTML"
        case .rtf: "富文本 (RTF)"
        case .docx: "Word (DOCX)"
        case .epub: "ePub 电子书"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .txt: "txt"
        case .pdf: "pdf"
        case .html: "html"
        case .rtf: "rtf"
        case .docx: "docx"
        case .epub: "epub"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown: .plainText
        case .txt: .plainText
        case .pdf: .pdf
        case .html: .html
        case .rtf: .rtf
        case .docx: UTType(filenameExtension: "docx") ?? .data
        case .epub: UTType(filenameExtension: "epub") ?? .data
        }
    }

    var supportsPreview: Bool {
        switch self {
        case .html, .pdf, .epub, .markdown: true
        default: false
        }
    }
}

enum ExportManager {
    static func buildDocument(
        primarySheet: Sheet,
        projectSheets: [Sheet],
        options: ExportOptions
    ) -> ExportDocument {
        switch options.scope {
        case .currentSheet:
            return .single(primarySheet, options: options)
        case .project:
            let sheets = projectSheets.isEmpty ? [primarySheet] : projectSheets
            let projectName = primarySheet.project?.name
            return .from(sheets: sheets, options: options, bundleTitle: projectName)
        }
    }

    static func previewHTML(document: ExportDocument) -> String {
        MarkdownExportRenderer.renderHTML(document: document)
    }

    static func previewPDFData(document: ExportDocument) -> Data? {
        makePDFData(document: document)
    }

    static func export(document: ExportDocument, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.title = "导出"
        panel.nameFieldStringValue = sanitizedFilename(document.title) + ".\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        export(document: document, format: format, to: url)
    }

    static func export(document: ExportDocument, format: ExportFormat, to url: URL) {
        switch format {
        case .markdown:
            try? MarkdownExportRenderer.renderMarkdown(document: document)
                .write(to: url, atomically: true, encoding: .utf8)
        case .txt:
            try? MarkdownExportRenderer.renderPlainText(document: document)
                .write(to: url, atomically: true, encoding: .utf8)
        case .html:
            try? MarkdownExportRenderer.renderHTML(document: document)
                .write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            exportPDF(document: document, to: url)
        case .rtf:
            exportRTF(document: document, to: url)
        case .docx:
            try? DOCXExporter.export(document: document, to: url)
        case .epub:
            try? EPUBExporter.export(document: document, to: url)
        }
    }

    static func copyAsRichText(document: ExportDocument) {
        let attr = MarkdownExportRenderer.renderAttributedString(document: document)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([attr])
    }

    static func copyHTML(document: ExportDocument) {
        let html = MarkdownExportRenderer.renderHTML(document: document)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .html)
        NSPasteboard.general.setString(MarkdownExportRenderer.renderPlainText(document: document), forType: .string)
    }

    /// 兼容旧调用
    static func export(sheet: Sheet, format: ExportFormat) {
        export(document: .single(sheet), format: format)
    }

    static func plainTextContent(for sheet: Sheet) -> String {
        MarkdownExportRenderer.renderPlainText(document: .single(sheet), includeTitles: true)
    }

    private static func sanitizedFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "未命名" : cleaned
    }

    private static func exportRTF(document: ExportDocument, to url: URL) {
        let attr = MarkdownExportRenderer.renderAttributedString(document: document)
        let range = NSRange(location: 0, length: attr.length)
        guard let data = try? attr.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }
        try? data.write(to: url)
    }

    private static func exportPDF(document: ExportDocument, to url: URL) {
        guard let data = makePDFData(document: document) else { return }
        try? data.write(to: url)
    }

    private static func makePDFData(document: ExportDocument) -> Data? {
        let style = document.options.style
        let paperSize = style.pdfPaperSize
        let margins = style.pdfMargins
        let printableWidth = paperSize.width - margins.left - margins.right
        let printableHeight = paperSize.height - margins.top - margins.bottom
        guard printableWidth > 0, printableHeight > 0 else { return nil }

        let textStorage = NSTextStorage(attributedString: MarkdownExportRenderer.renderAttributedString(document: document))
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: printableWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let glyphCount = layoutManager.numberOfGlyphs
        let usedRect = layoutManager.usedRect(for: textContainer)
        let pageCount = max(1, Int(ceil(max(usedRect.maxY, 1) / printableHeight)))

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: paperSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        for pageIndex in 0..<pageCount {
            let pageY = CGFloat(pageIndex) * printableHeight
            let pageRect = NSRect(x: 0, y: pageY, width: printableWidth, height: printableHeight)
            let glyphRange = layoutManager.glyphRange(forBoundingRect: pageRect, in: textContainer)
            guard glyphCount == 0 || glyphRange.length > 0 else { continue }

            context.beginPDFPage(nil)
            context.saveGState()
            // PDF 页为左下角原点；NSLayoutManager 需要左上角坐标系。
            context.translateBy(x: 0, y: paperSize.height)
            context.scaleBy(x: 1.0, y: -1.0)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

            let drawingOrigin = NSPoint(x: margins.left, y: margins.top - pageY)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: drawingOrigin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawingOrigin)

            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }
}
