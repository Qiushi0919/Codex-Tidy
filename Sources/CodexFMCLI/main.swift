import CodexFileCore
import Foundation

private struct JSONOutput: Encodable {
    let threads: [CodexThreadRecord]?
    let candidates: [CleanupCandidate]?
    let storage: [StorageLocation]?
}

private func printJSON(_ output: JSONOutput) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(output)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments.first {
    case "list":
        let threads = try CodexAppServerClient().listThreads()
        try printJSON(JSONOutput(threads: threads, candidates: nil, storage: nil))
    case "scan":
        let path = arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
        let candidates = try ArtifactScanner().scan(rootPath: path)
        try printJSON(JSONOutput(threads: nil, candidates: candidates, storage: nil))
    case "storage":
        try printJSON(JSONOutput(threads: nil, candidates: nil, storage: StorageInspector.inspectDefaultLocations()))
    default:
        print("""
        codexfm — Codex 文件与空间检查命令

        用法：
          codexfm list              列出本地 Codex 对话及路径（JSON）
          codexfm scan [目录]       扫描可重建的构建产物（JSON）
          codexfm storage           显示 Codex 本地存储占用（JSON）

        CLI 第一版仅提供只读检查；清理请在窗口软件中确认后执行。
        """)
    }
} catch {
    FileHandle.standardError.write(Data("错误：\(error.localizedDescription)\n".utf8))
    exit(1)
}
