//
//  ProjectSecurity.swift
//  FWriting
//

import CryptoKit
import Foundation
import LocalAuthentication

enum ProjectSecurity {
    static func protectingProject(for project: Project?) -> Project? {
        var current = project
        while let candidate = current {
            if candidate.isEncryptionEnabled {
                return candidate
            }
            current = candidate.parent
        }
        return nil
    }

    static func protectingProject(for sheet: Sheet?) -> Project? {
        protectingProject(for: sheet?.project)
    }

    static func isAccessible(_ project: Project?, appState: AppState) -> Bool {
        guard let lockedProject = protectingProject(for: project) else { return true }
        return appState.isProjectUnlocked(lockedProject.id)
    }

    static func isAccessible(_ sheet: Sheet?, appState: AppState) -> Bool {
        guard let lockedProject = protectingProject(for: sheet) else { return true }
        return appState.isProjectUnlocked(lockedProject.id)
    }

    static func enableEncryption(for project: Project, password: String) {
        let salt = UUID().uuidString
        project.encryptionSalt = salt
        project.encryptionPasswordHash = hash(password: password, salt: salt)
    }

    static func disableEncryption(for project: Project) {
        project.encryptionSalt = nil
        project.encryptionPasswordHash = nil
    }

    static func verify(password: String, for project: Project) -> Bool {
        guard let salt = project.encryptionSalt,
              let storedHash = project.encryptionPasswordHash else { return false }
        return hash(password: password, salt: salt) == storedHash
    }

    static func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func authenticateWithSystem(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private static func hash(password: String, salt: String) -> String {
        let data = Data("\(salt)\n\(password)".utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
