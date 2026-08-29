import SwiftUI

@main
struct CodexFileManagerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Codex Tidy") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 660)
        }
        .defaultSize(width: 1_180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Codex Tidy") {
                Button("刷新") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
