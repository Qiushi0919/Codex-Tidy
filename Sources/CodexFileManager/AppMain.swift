import AppKit
import SwiftUI

private enum AboutPanel {
    static let releasesURL = URL(string: "https://github.com/Qiushi0919/Codex-Tidy/releases")!

    @MainActor
    static func show() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CodexTidyReleaseVersion") as? String ?? "0.1.0-beta.2"
        let alert = NSAlert()
        alert.messageText = "Codex Tidy"
        alert.informativeText = "版本 \(version)\n\n下载最新版：\n\(releasesURL.absoluteString)"
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "下载最新版")
        alert.addButton(withTitle: "关闭")
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(releasesURL) }
    }
}

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
            CommandGroup(replacing: .appInfo) {
                Button("关于 Codex Tidy") { AboutPanel.show() }
            }
            CommandGroup(replacing: .newItem) { }
            CommandMenu("操作") {
                Button("检查更新…") {
                    Task { await updateChecker.check(interactive: true) }
                }
                Button("下载最新版…") { NSWorkspace.shared.open(AboutPanel.releasesURL) }
                Divider()
                Button("刷新") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
