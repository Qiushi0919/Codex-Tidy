import Foundation

public struct ArtifactScanner: Sendable {
    public struct Rule: Sendable {
        public let kind: String
        public let confidence: CleanupConfidence

        public init(kind: String, confidence: CleanupConfidence) {
            self.kind = kind
            self.confidence = confidence
        }
    }

    public static let rules: [String: Rule] = [
        "node_modules": Rule(kind: "Node.js 依赖", confidence: .safe),
        "__pycache__": Rule(kind: "Python 字节码缓存", confidence: .safe),
        ".pytest_cache": Rule(kind: "Pytest 缓存", confidence: .safe),
        ".mypy_cache": Rule(kind: "Mypy 缓存", confidence: .safe),
        ".ruff_cache": Rule(kind: "Ruff 缓存", confidence: .safe),
        ".gradle": Rule(kind: "Gradle 项目缓存", confidence: .safe),
        ".dart_tool": Rule(kind: "Dart 工具缓存", confidence: .safe),
        ".next": Rule(kind: "Next.js 构建缓存", confidence: .safe),
        ".nuxt": Rule(kind: "Nuxt 构建缓存", confidence: .safe),
        ".turbo": Rule(kind: "Turborepo 缓存", confidence: .safe),
        ".build": Rule(kind: "SwiftPM 构建缓存", confidence: .safe),
        "DerivedData": Rule(kind: "Xcode Derived Data", confidence: .safe),
        "coverage": Rule(kind: "测试覆盖率输出", confidence: .safe),
        "build": Rule(kind: "构建输出", confidence: .review),
        "dist": Rule(kind: "发布输出", confidence: .review),
        "target": Rule(kind: "编译输出", confidence: .review),
        ".venv": Rule(kind: "Python 虚拟环境", confidence: .review),
        "venv": Rule(kind: "Python 虚拟环境", confidence: .review),
        "Pods": Rule(kind: "CocoaPods 依赖", confidence: .review)
    ]

    private let maxDepth: Int
    private let directoryVisitLimit: Int

    public init(maxDepth: Int = 5, directoryVisitLimit: Int = 30_000) {
        self.maxDepth = maxDepth
        self.directoryVisitLimit = directoryVisitLimit
    }

    public func scan(rootPath: String) throws -> [CleanupCandidate] {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .nameKey]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var candidates: [CleanupCandidate] = []
        var visitedDirectories = 0

        while let item = enumerator.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true else { continue }
            visitedDirectories += 1

            if visitedDirectories > directoryVisitLimit {
                enumerator.skipDescendants()
                break
            }

            let depth = Self.depth(of: item, relativeTo: rootURL)
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let name = item.lastPathComponent
            if name == ".git" || name == ".hg" || name == ".svn" {
                enumerator.skipDescendants()
                continue
            }

            if name.hasPrefix("."), Self.rules[name] == nil {
                enumerator.skipDescendants()
                continue
            }

            guard let rule = Self.rules[name] else { continue }
            guard values?.isSymbolicLink != true else {
                enumerator.skipDescendants()
                continue
            }

            let size = StorageInspector.sizeOfItem(atPath: item.path)
            candidates.append(
                CleanupCandidate(
                    path: item.path,
                    kind: rule.kind,
                    confidence: rule.confidence,
                    size: size
                )
            )
            enumerator.skipDescendants()
        }

        return candidates.sorted {
            if $0.confidence != $1.confidence { return $0.confidence == .safe }
            return $0.size > $1.size
        }
    }

    public static func rule(forDirectoryName name: String) -> Rule? {
        rules[name]
    }

    public func validateSafeCleanup(candidate: CleanupCandidate, rootPath: String) throws {
        let root = URL(fileURLWithPath: rootPath).standardizedFileURL.resolvingSymlinksInPath()
        let target = URL(fileURLWithPath: candidate.path).standardizedFileURL.resolvingSymlinksInPath()
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"

        guard target.path.hasPrefix(rootPrefix),
              target.path != root.path,
              candidate.confidence == .safe,
              let rule = Self.rules[target.lastPathComponent],
              rule.confidence == .safe else {
            throw CodexFileManagerError.unsafeCleanupPath(candidate.path)
        }
    }

    public func moveToTrash(candidates: [CleanupCandidate], rootPath: String) throws -> Int64 {
        var reclaimed: Int64 = 0
        for candidate in candidates {
            try validateSafeCleanup(candidate: candidate, rootPath: rootPath)
            let url = URL(fileURLWithPath: candidate.path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            reclaimed += candidate.size
        }
        return reclaimed
    }

    private static func depth(of item: URL, relativeTo root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents.count
        let itemComponents = item.standardizedFileURL.pathComponents.count
        return max(0, itemComponents - rootComponents)
    }
}
