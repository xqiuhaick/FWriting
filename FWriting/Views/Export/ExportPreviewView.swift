//
//  ExportPreviewView.swift
//  FWriting
//

import SwiftUI
import WebKit
import PDFKit

struct ExportHTMLPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct ExportPreviewView: View {
    let html: String
    let pdfData: Data?
    let format: ExportFormat

    var body: some View {
        Group {
            switch format {
            case .html, .epub, .markdown:
                ExportHTMLPreview(html: html)
            case .pdf:
                if let pdfData {
                    ExportPDFPreview(data: pdfData)
                } else {
                    ContentUnavailableView("无法生成 PDF 预览", systemImage: "doc.richtext")
                }
            case .txt, .rtf, .docx:
                ScrollView {
                    Text(plainPreview)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var plainPreview: String {
        guard let start = html.range(of: "<body>"),
              let end = html.range(of: "</body>") else {
            return html.prefix(4000).description
        }
        let fragment = String(html[start.upperBound..<end.lowerBound])
        return fragment
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ExportPDFPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .textBackgroundColor
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
    }
}
