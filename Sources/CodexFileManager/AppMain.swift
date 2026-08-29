import SwiftUI

@main
struct CodexFileManagerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Codex 文件管理器") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 660)
        }
        .defaultSize(width: 1_180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Codex 文件管理器") {
                Button("刷新") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
