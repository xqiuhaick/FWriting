//
//  SheetTransferable.swift
//  FWriting
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct SheetTransferable: Codable, Transferable {
    let sheetID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sheetTransfer)
    }
}

extension UTType {
    static let sheetTransfer = UTType(exportedAs: "com.yourcompany.fwriting.sheet")
}
