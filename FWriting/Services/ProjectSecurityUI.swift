//
//  ProjectSecurityUI.swift
//  FWriting
//

import AppKit
import SwiftData

@MainActor
enum ProjectSecurityUI {
    static func enableEncryption(
        for project: Project,
        appState: AppState,
        modelContext: ModelContext
    ) {
        guard let password = promptNewPassword(projectName: project.name) else { return }
        ProjectSecurity.enableEncryption(for: project, password: password)
        appState.unlockProject(project.id)
        try? modelContext.save()
    }

    static func unlock(_ project: Project, appState: AppState) {
        guard project.isEncryptionEnabled else { return }
        if appState.isProjectUnlocked(project.id) { return }

        if ProjectSecurity.canUseBiometrics() {
            Task { @MainActor in
                let success = await ProjectSecurity.authenticateWithSystem(
                    reason: "解锁项目「\(project.name)」"
                )
                if success {
                    appState.unlockProject(project.id)
                } else {
                    showMessage(title: "解锁失败", message: "未能通过系统验证。")
                }
            }
            return
        }

        guard let password = promptPassword(title: "解锁项目", message: "输入项目「\(project.name)」的密码") else {
            return
        }
        if ProjectSecurity.verify(password: password, for: project) {
            appState.unlockProject(project.id)
        } else {
            showMessage(title: "密码错误", message: "请重新输入项目密码。")
        }
    }

    static func lock(_ project: Project, appState: AppState) {
        appState.lockProject(project.id)
    }

    static func disableEncryption(
        for project: Project,
        appState: AppState,
        modelContext: ModelContext
    ) {
        guard project.isEncryptionEnabled else { return }
        guard let password = promptPassword(title: "关闭项目加密", message: "输入项目「\(project.name)」的密码") else {
            return
        }
        guard ProjectSecurity.verify(password: password, for: project) else {
            showMessage(title: "密码错误", message: "无法关闭项目加密。")
            return
        }

        ProjectSecurity.disableEncryption(for: project)
        appState.lockProject(project.id)
        try? modelContext.save()
    }

    private static func promptNewPassword(projectName: String) -> String? {
        let form = passwordPairForm()

        let alert = NSAlert()
        alert.messageText = "启用项目加密"
        alert.informativeText = "为项目「\(projectName)」设置解锁密码。"
        alert.accessoryView = form.view
        alert.addButton(withTitle: "启用")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = form.password.stringValue
        guard !value.isEmpty else {
            showMessage(title: "密码不能为空", message: "请设置一个项目密码。")
            return nil
        }
        guard value == form.confirm.stringValue else {
            showMessage(title: "密码不一致", message: "两次输入的密码不一致。")
            return nil
        }
        return value
    }

    private static func promptPassword(title: String, message: String) -> String? {
        let form = passwordForm()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = form.view
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return form.password.stringValue
    }

    private static func passwordField(placeholder: String) -> NSSecureTextField {
        let field = NSSecureTextField(frame: .zero)
        field.placeholderString = placeholder
        return field
    }

    private static func passwordForm() -> (view: NSView, password: NSSecureTextField) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 46))
        let password = passwordField(placeholder: "输入密码")
        addPasswordRow(title: "密码", field: password, y: 0, to: view)
        return (view, password)
    }

    private static func passwordPairForm() -> (view: NSView, password: NSSecureTextField, confirm: NSSecureTextField) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 94))
        let password = passwordField(placeholder: "输入密码")
        let confirm = passwordField(placeholder: "再次输入密码")
        addPasswordRow(title: "密码", field: password, y: 48, to: view)
        addPasswordRow(title: "确认密码", field: confirm, y: 0, to: view)
        return (view, password, confirm)
    }

    private static func addPasswordRow(title: String, field: NSSecureTextField, y: CGFloat, to view: NSView) {
        let label = NSTextField(labelWithString: title)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.frame = NSRect(x: 0, y: y + 30, width: 280, height: 16)
        field.frame = NSRect(x: 0, y: y, width: 280, height: 26)
        view.addSubview(label)
        view.addSubview(field)
    }

    private static func showMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
