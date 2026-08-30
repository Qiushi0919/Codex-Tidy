import SwiftUI

@main
struct CodexFileManagerApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updateChecker = UpdateChecker()

    var body: some Scene {
        WindowGroup("Codex Tidy") {
            ContentView()
                .environmentObject(model)
                .environmentObject(updateChecker)
                .frame(minWidth: 980, minHeight: 660)
        }
        .defaultSize(width: 1_180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("操作") {
                Button("检查更新…") {
                    Task { await updateChecker.check(interactive: true) }
                }
                Divider()
                Button("刷新") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
