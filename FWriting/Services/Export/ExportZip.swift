//
//  ExportZip.swift
//  FWriting
//

import Foundation

enum ExportZip {
    static func zip(directory: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-rqX", destination.path, "."]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "ExportZip",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法创建压缩包"]
            )
        }
    }

    static func withTemporaryDirectory<T>(_ work: (URL) throws -> T) throws -> T {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        return try work(tempDir)
    }
}
