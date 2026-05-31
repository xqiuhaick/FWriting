//
//  FWritingApp.swift
//  FWriting
//

import SwiftData
import SwiftUI

@main
struct FWritingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Project.self, Sheet.self, Tag.self, Character.self, SheetSnapshot.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1280, height: 800)

        Settings {
            SettingsView()
        }
    }
}
