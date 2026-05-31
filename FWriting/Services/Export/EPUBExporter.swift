//
//  EPUBExporter.swift
//  FWriting
//

import Foundation

enum EPUBExporter {
    static func export(document: ExportDocument, to url: URL) throws {
        try ExportZip.withTemporaryDirectory { tempDir in
            let oebps = tempDir.appendingPathComponent("OEBPS", isDirectory: true)
            let metaInf = tempDir.appendingPathComponent("META-INF", isDirectory: true)
            try FileManager.default.createDirectory(at: oebps, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: metaInf, withIntermediateDirectories: true)

            try "application/epub+zip".write(
                to: tempDir.appendingPathComponent("mimetype"),
                atomically: true,
                encoding: .ascii
            )

            let container = """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """
            try container.write(to: metaInf.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

            let css = document.options.style.css(
                bodySize: document.options.bodyFontSize,
                maxWidth: document.options.maxWidth
            )
            try css.write(to: oebps.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)

            var manifestItems: [String] = []
            var spineItems: [String] = []
            var navLinks: [(href: String, label: String)] = []

            if document.options.includeTitlePage {
                let fileName = "title.xhtml"
                let html = wrapXHTML(
                    title: document.title,
                    body: titlePageBody(document: document),
                    css: "style.css"
                )
                try html.write(to: oebps.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
                manifestItems.append(itemRef(id: "title", href: fileName, mediaType: "application/xhtml+xml"))
                spineItems.append(#"<itemref idref="title"/>"#)
                navLinks.append((fileName, document.title))
            }

            for (chapterIndex, chapter) in document.chapters.enumerated() {
                let fileName = "chapter-\(chapterIndex).xhtml"
                var body = ""
                if document.chapters.count > 1, document.options.chapterPerSheet {
                    body += "<h1 class=\"chapter-title\">\(MarkdownExportRenderer.escapeHTML(chapter.title))</h1>\n"
                }
                body += chapterBodyHTML(chapter: chapter, chapterIndex: chapterIndex, options: document.options)
                let html = wrapXHTML(title: chapter.title, body: body, css: "style.css")
                try html.write(to: oebps.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
                let id = "ch\(chapterIndex)"
                manifestItems.append(itemRef(id: id, href: fileName, mediaType: "application/xhtml+xml"))
                spineItems.append(#"<itemref idref="\#(id)"/>"#)
                navLinks.append((fileName, chapter.title))
            }

            let navBody = navDocumentHTML(
                title: document.title,
                links: navLinks,
                toc: MarkdownExportRenderer.tableOfContents(for: document)
            )
            try navBody.write(to: oebps.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
            manifestItems.append(itemRef(id: "nav", href: "nav.xhtml", mediaType: "application/xhtml+xml", properties: "nav"))
            manifestItems.append(#"<item id="css" href="style.css" media-type="text/css"/>"#)

            let uuid = UUID().uuidString
            let opf = packageOPF(
                title: document.title,
                author: document.options.author,
                uuid: uuid,
                manifest: manifestItems,
                spine: spineItems
            )
            try opf.write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

            try ExportZip.zip(directory: tempDir, to: url)
        }
    }

    private static func wrapXHTML(title: String, body: String, css: String) -> String {
        let safeTitle = MarkdownExportRenderer.escapeHTML(title)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="zh-CN">
        <head>
          <meta charset="utf-8"/>
          <title>\(safeTitle)</title>
          <link rel="stylesheet" type="text/css" href="\(css)"/>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func titlePageBody(document: ExportDocument) -> String {
        var meta: [String] = []
        if !document.options.author.isEmpty {
            meta.append("<div>\(MarkdownExportRenderer.escapeHTML(document.options.author))</div>")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "zh_CN")
        meta.append("<div>\(MarkdownExportRenderer.escapeHTML(formatter.string(from: .now)))</div>")
        return """
        <header class="title-page">
          <h1>\(MarkdownExportRenderer.escapeHTML(document.title))</h1>
          <div class="meta">\(meta.joined())</div>
        </header>
        """
    }

    private static func chapterBodyHTML(chapter: ExportChapter, chapterIndex: Int, options: ExportOptions) -> String {
        let html = MarkdownExportRenderer.renderHTML(document: ExportDocument(
            title: chapter.title,
            chapters: [chapter],
            options: ExportOptions(
                scope: options.scope,
                style: options.style,
                includeTableOfContents: false,
                includeComments: options.includeComments,
                includeTitlePage: false,
                chapterPerSheet: false,
                author: options.author,
                bodyFontSize: options.bodyFontSize,
                maxWidth: options.maxWidth
            )
        ))
        guard let bodyStart = html.range(of: "<body>"),
              let bodyEnd = html.range(of: "</body>") else { return "" }
        return String(html[bodyStart.upperBound..<bodyEnd.lowerBound])
    }

    private static func navDocumentHTML(title: String, links: [(href: String, label: String)], toc: [ExportTOCEntry]) -> String {
        let chapterItems = links.map { link in
            "<li><a href=\"\(link.href)\">\(MarkdownExportRenderer.escapeHTML(link.label))</a></li>"
        }.joined(separator: "\n")
        let headingItems = toc.map { entry in
            let indent = String(repeating: "  ", count: max(0, entry.level - 1))
            return "\(indent)<li><a href=\"\(entry.anchor)\">\(MarkdownExportRenderer.escapeHTML(entry.title))</a></li>"
        }.joined(separator: "\n")
        return wrapXHTML(
            title: "目录",
            body: """
            <nav epub:type="toc" id="toc">
              <h1>目录</h1>
              <ol>
              \(chapterItems)
              </ol>
              \(headingItems.isEmpty ? "" : "<h2>正文结构</h2><ol>\(headingItems)</ol>")
            </nav>
            """,
            css: "style.css"
        )
    }

    private static func itemRef(id: String, href: String, mediaType: String, properties: String? = nil) -> String {
        if let properties {
            return #"<item id="\#(id)" href="\#(href)" media-type="\#(mediaType)" properties="\#(properties)"/>"#
        }
        return #"<item id="\#(id)" href="\#(href)" media-type="\#(mediaType)"/>"#
    }

    private static func packageOPF(
        title: String,
        author: String,
        uuid: String,
        manifest: [String],
        spine: [String]
    ) -> String {
        let creator = author.isEmpty ? "FWriting" : MarkdownExportRenderer.escapeHTML(author)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(MarkdownExportRenderer.escapeHTML(title))</dc:title>
            <dc:creator>\(creator)</dc:creator>
            <dc:language>zh-CN</dc:language>
            <dc:identifier id="uid">urn:uuid:\(uuid)</dc:identifier>
            <meta property="dcterms:modified">\(iso8601Now())</meta>
          </metadata>
          <manifest>
            \(manifest.joined(separator: "\n    "))
          </manifest>
          <spine toc="nav">
            \(spine.joined(separator: "\n    "))
          </spine>
        </package>
        """
    }

    private static func iso8601Now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: .now)
    }
}
