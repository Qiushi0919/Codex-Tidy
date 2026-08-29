import Foundation

public enum StorageInspector {
    public static func inspectDefaultLocations() -> [StorageLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codexHome: URL
        if let configured = ProcessInfo.processInfo.environment["CODEX_HOME"], !configured.isEmpty {
            codexHome = URL(fileURLWithPath: configured)
        } else {
            codexHome = home.appendingPathComponent(".codex", isDirectory: true)
        }

        let locations: [(String, String, URL, String)] = [
            ("sessions", "对话日志", codexHome.appendingPathComponent("sessions"), "当前未归档的 Codex 对话记录"),
            ("archived", "已归档对话", codexHome.appendingPathComponent("archived_sessions"), "已归档但仍占空间的对话记录"),
            ("worktrees", "Codex Worktrees", codexHome.appendingPathComponent("worktrees"), "Codex 管理的隔离工作目录"),
            ("cache", "Codex 缓存", home.appendingPathComponent("Library/Caches/Codex"), "可由 Codex 重新生成的应用缓存"),
            ("support", "Codex 应用数据", home.appendingPathComponent("Library/Application Support/Codex"), "浏览器组件与本地应用数据，不建议整体删除")
        ]

        return locations.map { id, title, url, detail in
            StorageLocation(
                id: id,
                title: title,
                path: url.path,
                size: sizeOfItem(atPath: url.path),
                detail: detail
            )
        }
    }

    public static func sizeOfItem(atPath path: String) -> Int64 {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            guard let attributes = try? fileManager.attributesOfItem(atPath: path),
                  let number = attributes[.size] as? NSNumber else { return 0 }
            return number.int64Value
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8),
                  let first = text.split(whereSeparator: { $0 == "\t" || $0 == " " }).first,
                  let kilobytes = Int64(first) else {
                return 0
            }
            return kilobytes * 1_024
        } catch {
            return 0
        }
    }
}
