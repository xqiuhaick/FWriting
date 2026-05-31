//
//  SheetRowView.swift
//  FWriting
//

import SwiftUI

struct SheetRowView: View {
    let sheet: Sheet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sheet.displayTitle)
                .font(.headline)
                .lineLimit(1)

            Text(sheet.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}
