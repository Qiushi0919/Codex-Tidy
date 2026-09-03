import Foundation

public struct CodexThreadRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let preview: String
    public let cwd: String
    public let logPaths: [String]
    public let projectID: String?
    public let source: String
    public let status: String
    public let isArchived: Bool
    public let createdAt: TimeInterval
    public let updatedAt: TimeInterval
    public let logSize: Int64
    public let sourceCwd: String
    public let resolvedProjectName: String?
    public let resolvedProjectPath: String?
    public let workingDirectorySize: Int64
    public let projectDirectorySize: Int64

    public init(
        id: String,
        title: String,
        preview: String,
        cwd: String,
        logPaths: [String],
        projectID: String?,
        source: String,
        status: String,
        isArchived: Bool,
        createdAt: TimeInterval,
        updatedAt: TimeInterval,
        logSize: Int64,
        sourceCwd: String? = nil,
        resolvedProjectName: String? = nil,
        resolvedProjectPath: String? = nil,
        workingDirectorySize: Int64 = 0,
        projectDirectorySize: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.cwd = cwd
        self.logPaths = logPaths
        self.projectID = projectID
        self.source = source
        self.status = status
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.logSize = logSize
        self.sourceCwd = sourceCwd ?? cwd
        self.resolvedProjectName = resolvedProjectName
        self.resolvedProjectPath = resolvedProjectPath
        self.workingDirectorySize = workingDirectorySize
        self.projectDirectorySize = projectDirectorySize
    }

    public var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let trimmedPreview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreview.isEmpty {
            return String(trimmedPreview.prefix(54))
        }
        return "未命名对话"
    }

    public var logPath: String? {
        logPaths.first
    }

    public var projectKey: String {
        if let projectID, !projectID.isEmpty {
            return "project:\(projectID)"
        }
        if let resolvedProjectPath, !resolvedProjectPath.isEmpty {
            return "project-path:\(resolvedProjectPath)"
        }
        return "cwd:\(cwd)"
    }

    public var projectName: String {
        if let resolvedProjectName {
            let trimmed = resolvedProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let path = resolvedProjectPath ?? cwd
        guard !path.isEmpty else { return "未知位置" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    public var wasWorkingDirectoryRelocated: Bool {
        guard !sourceCwd.isEmpty, !cwd.isEmpty else { return false }
        return URL(fileURLWithPath: sourceCwd).standardizedFileURL.path
            != URL(fileURLWithPath: cwd).standardizedFileURL.path
    }

    public var updatedDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }

    public var destructiveActionsLocked: Bool {
        if status == "active" { return true }
        return Date().timeIntervalSince(updatedDate) < 3_600
    }
}

public struct ProjectGroup: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let threads: [CodexThreadRecord]
    public let directorySize: Int64

    public init(id: String, name: String, path: String, threads: [CodexThreadRecord], directorySize: Int64) {
        self.id = id
        self.name = name
        self.path = path
        self.threads = threads
        self.directorySize = directorySize
    }

    public var totalLogSize: Int64 {
        threads.reduce(0) { $0 + $1.logSize }
    }
}

public struct CodexProjectRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let rootPaths: [String]

    public init(id: String, name: String, rootPaths: [String]) {
        self.id = id
        self.name = name
        self.rootPaths = rootPaths
    }
}

public enum CleanupConfidence: String, Codable, Hashable, Sendable {
    case safe
    case review

    public var displayName: String {
        switch self {
        case .safe: return "可安全重建"
        case .review: return "删除前检查"
        }
    }
}

public struct CleanupCandidate: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let kind: String
    public let confidence: CleanupConfidence
    public let size: Int64

    public init(path: String, kind: String, confidence: CleanupConfidence, size: Int64) {
        self.id = path
        self.path = path
        self.kind = kind
        self.confidence = confidence
        self.size = size
    }

    public var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

public struct StorageLocation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let path: String
    public let size: Int64
    public let detail: String

    public init(id: String, title: String, path: String, size: Int64, detail: String) {
        self.id = id
        self.title = title
        self.path = path
        self.size = size
        self.detail = detail
    }
}

public enum ByteFormatting {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    public static func string(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        return formatter.string(fromByteCount: bytes)
    }
}

public enum CodexFileManagerError: LocalizedError {
    case codexNotFound
    case appServerFailed(String)
    case malformedResponse(String)
    case unsafeCleanupPath(String)

    public var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "没有找到 Codex。请安装 ChatGPT/Codex，或通过 CODEX_BINARY 指定可执行文件。"
        case .appServerFailed(let message):
            return "Codex App Server 运行失败：\(message)"
        case .malformedResponse(let message):
            return "Codex 返回了无法识别的数据：\(message)"
        case .unsafeCleanupPath(let path):
            return "已阻止不安全的清理路径：\(path)"
        }
    }
}
