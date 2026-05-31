//
//  DOCXExporter.swift
//  FWriting
//

import Foundation

enum DOCXExporter {
    static func export(document: ExportDocument, to url: URL) throws {
        try ExportZip.withTemporaryDirectory { tempDir in
            let wordDir = tempDir.appendingPathComponent("word", isDirectory: true)
            let relsDir = tempDir.appendingPathComponent("_rels", isDirectory: true)
            let wordRelsDir = wordDir.appendingPathComponent("_rels", isDirectory: true)
            try FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)

            let bodyXML = documentBodyXML(document: document)
            let documentXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body>
                \(bodyXML)
                <w:sectPr>
                  <w:pgSz w:w="11906" w:h="16838"/>
                  <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
                </w:sectPr>
              </w:body>
            </w:document>
            """

            let stylesXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:style w:type="paragraph" w:styleId="Title">
                <w:name w:val="Title"/>
                <w:pPr><w:jc w:val="center"/></w:pPr>
                <w:rPr><w:sz w:val="48"/><w:b/></w:rPr>
              </w:style>
              <w:style w:type="paragraph" w:styleId="Heading1">
                <w:name w:val="heading 1"/>
                <w:pPr><w:outlineLvl w:val="0"/></w:pPr>
                <w:rPr><w:sz w:val="36"/><w:b/></w:rPr>
              </w:style>
              <w:style w:type="paragraph" w:styleId="Heading2">
                <w:name w:val="heading 2"/>
                <w:pPr><w:outlineLvl w:val="1"/></w:pPr>
                <w:rPr><w:sz w:val="30"/><w:b/></w:rPr>
              </w:style>
              <w:style w:type="paragraph" w:styleId="Heading3">
                <w:name w:val="heading 3"/>
                <w:pPr><w:outlineLvl w:val="2"/></w:pPr>
                <w:rPr><w:sz w:val="26"/><w:b/></w:rPr>
              </w:style>
              <w:style w:type="paragraph" w:styleId="Quote">
                <w:name w:val="Quote"/>
                <w:pPr>
                  <w:ind w:left="720"/>
                  <w:spacing w:before="120" w:after="120"/>
                </w:pPr>
                <w:rPr><w:i/><w:color w:val="666666"/></w:rPr>
              </w:style>
              <w:style w:type="paragraph" w:styleId="CodeBlock">
                <w:name w:val="Code Block"/>
                <w:pPr>
                  <w:shd w:val="clear" w:color="auto" w:fill="F4F4F5"/>
                  <w:spacing w:before="120" w:after="120"/>
                </w:pPr>
                <w:rPr><w:rFonts w:ascii="Menlo" w:hAnsi="Menlo"/><w:sz w:val="22"/></w:rPr>
              </w:style>
            </w:styles>
            """

            let contentTypes = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
              <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
            </Types>
            """

            let rels = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
            </Relationships>
            """

            let documentRels = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            </Relationships>
            """

            try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
            try stylesXML.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)
            try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
            try contentTypes.write(to: tempDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
            try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

            try ExportZip.zip(directory: tempDir, to: url)
        }
    }

    /// 兼容旧 API
    static func export(sheet: Sheet, to url: URL) throws {
        try export(document: .single(sheet), to: url)
    }

    private static func documentBodyXML(document: ExportDocument) -> String {
        var parts: [String] = []
        let options = document.options

        if options.includeTitlePage {
            parts.append(paragraph(styleId: "Title", runs: [.init(text: document.title, bold: true, sizeHalfPoints: 48)]))
            if !options.author.isEmpty {
                parts.append(paragraph(runs: [.init(text: options.author, italic: true, color: "666666")], center: true))
            }
            parts.append(emptyParagraph())
        }

        if options.includeTableOfContents {
            let toc = MarkdownExportRenderer.tableOfContents(for: document)
            if !toc.isEmpty {
                parts.append(paragraph(styleId: "Heading2", runs: [.init(text: "目录", bold: true)]))
                for entry in toc {
                    let indent = String(repeating: "    ", count: max(0, entry.level - 1))
                    parts.append(paragraph(runs: [.init(text: indent + entry.title)]))
                }
                parts.append(emptyParagraph())
            }
        }

        for chapter in document.chapters {
            if document.chapters.count > 1, options.chapterPerSheet {
                parts.append(paragraph(styleId: "Heading1", runs: [.init(text: chapter.title, bold: true)]))
            }
            parts.append(blocksXML(BlockParser.parse(chapter.body), includeComments: options.includeComments))
        }
        return parts.joined(separator: "\n")
    }

    private static func blocksXML(_ blocks: [Block], includeComments: Bool) -> String {
        var parts: [String] = []
        var index = 0

        while index < blocks.count {
            let block = blocks[index]
            if block.type == .comment, !includeComments {
                index += 1
                continue
            }

            if block.type == .list {
                var items: [Block] = []
                while index < blocks.count, blocks[index].type == .list {
                    items.append(blocks[index])
                    index += 1
                }
                for item in items {
                    parts.append(bulletParagraph(text: item.text))
                }
                continue
            }

            if block.type == .numberedList {
                var number = 1
                while index < blocks.count, blocks[index].type == .numberedList {
                    let item = blocks[index]
                    let value = BlockParser.numberedValue(in: item.rawLine) ?? number
                    parts.append(numberedParagraph(number: value, text: item.text))
                    number = value + 1
                    index += 1
                }
                continue
            }

            if block.type == .code {
                var lines: [String] = []
                while index < blocks.count, blocks[index].type == .code {
                    lines.append(blocks[index].text)
                    index += 1
                }
                parts.append(paragraph(styleId: "CodeBlock", runs: [.init(text: lines.joined(separator: "\n"), mono: true)]))
                continue
            }

            switch block.type {
            case .heading1:
                parts.append(paragraph(styleId: "Heading1", runs: inlineRuns(block.text, bold: true)))
            case .heading2:
                parts.append(paragraph(styleId: "Heading2", runs: inlineRuns(block.text, bold: true)))
            case .heading3:
                parts.append(paragraph(styleId: "Heading3", runs: inlineRuns(block.text, bold: true)))
            case .quote:
                parts.append(paragraph(styleId: "Quote", runs: inlineRuns(block.text, italic: true)))
            case .comment:
                parts.append(paragraph(runs: inlineRuns(block.text, italic: true, color: "999999")))
            case .paragraph:
                let text = block.text.isEmpty ? " " : block.text
                parts.append(paragraph(runs: inlineRuns(text)))
            default:
                parts.append(paragraph(runs: inlineRuns(block.text)))
            }
            index += 1
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - XML builders

    private struct TextRun {
        var text: String
        var bold = false
        var italic = false
        var strike = false
        var mono = false
        var color: String?
        var sizeHalfPoints: Int?
    }

    private static func emptyParagraph() -> String {
        paragraph(runs: [.init(text: " ")])
    }

    private static func bulletParagraph(text: String) -> String {
        """
        <w:p>
          <w:pPr>
            <w:pStyle w:val="ListParagraph"/>
            <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
            <w:ind w:left="720"/>
          </w:pPr>
          \(runsXML(inlineRuns(text)))
        </w:p>
        """
    }

    private static func numberedParagraph(number: Int, text: String) -> String {
        """
        <w:p>
          <w:pPr><w:ind w:left="720"/></w:pPr>
          \(runsXML([.init(text: "\(number). ", bold: true)] + inlineRuns(text)))
        </w:p>
        """
    }

    private static func paragraph(
        styleId: String? = nil,
        runs: [TextRun],
        center: Bool = false
    ) -> String {
        var pPr = "<w:pPr>"
        if let styleId {
            pPr += "<w:pStyle w:val=\"\(styleId)\"/>"
        }
        if center {
            pPr += "<w:jc w:val=\"center\"/>"
        }
        pPr += "</w:pPr>"
        return "<w:p>\(pPr)\(runsXML(runs))</w:p>"
    }

    private static func runsXML(_ runs: [TextRun]) -> String {
        runs.map { run in
            var rPr = "<w:rPr>"
            if run.bold { rPr += "<w:b/>" }
            if run.italic { rPr += "<w:i/>" }
            if run.strike { rPr += "<w:strike/>" }
            if run.mono { rPr += "<w:rFonts w:ascii=\"Menlo\" w:hAnsi=\"Menlo\"/>" }
            if let color = run.color { rPr += "<w:color w:val=\"\(color)\"/>" }
            if let size = run.sizeHalfPoints { rPr += "<w:sz w:val=\"\(size)\"/>" }
            rPr += "</w:rPr>"
            let text = xmlEscape(run.text)
            let preserve = run.text.hasPrefix(" ") || run.text.hasSuffix(" ") ? " xml:space=\"preserve\"" : ""
            return "<w:r>\(rPr)<w:t\(preserve)>\(text)</w:t></w:r>"
        }.joined()
    }

    private static func inlineRuns(
        _ text: String,
        bold: Bool = false,
        italic: Bool = false,
        color: String? = nil
    ) -> [TextRun] {
        if text.isEmpty { return [.init(text: " ", bold: bold, italic: italic, color: color)] }
        var runs: [TextRun] = []
        let pattern = #"(?:(\*\*(.+?)\*\*)|(?:(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*))|(`(.+?)`)|(~~(.+?)~~)|([^*`~]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.init(text: text, bold: bold, italic: italic, color: color)]
        }
        let ns = text as NSString
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            if match.range(at: 2).location != NSNotFound {
                runs.append(.init(text: ns.substring(with: match.range(at: 2)), bold: true))
            } else if match.range(at: 3).location != NSNotFound {
                runs.append(.init(text: ns.substring(with: match.range(at: 3)), italic: true))
            } else if match.range(at: 4).location != NSNotFound {
                runs.append(.init(text: ns.substring(with: match.range(at: 4)), mono: true))
            } else if match.range(at: 5).location != NSNotFound {
                runs.append(.init(text: ns.substring(with: match.range(at: 5)), strike: true))
            } else if match.range(at: 6).location != NSNotFound {
                runs.append(.init(text: ns.substring(with: match.range(at: 6)), bold: bold, italic: italic, color: color))
            }
        }
        if runs.isEmpty {
            runs.append(.init(text: text, bold: bold, italic: italic, color: color))
        }
        return runs
    }

    private static func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
