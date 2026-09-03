import XCTest
@testable import CodexFileCore

final class CoreTests: XCTestCase {
    func testReleaseVersionComparison() throws {
        XCTAssertEqual(ReleaseVersion("v0.1.0-beta.1"), ReleaseVersion("0.1.0-beta.1"))
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.1.0-beta.1")), try XCTUnwrap(ReleaseVersion("0.1.0")))
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.1.0-beta.2")), try XCTUnwrap(ReleaseVersion("0.1.0-beta.10")))
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.1.9")), try XCTUnwrap(ReleaseVersion("0.2.0")))
    }

    func testParsesThreadListItem() throws {
        let object: [String: Any] = [
            "id": "thread-1",
            "name": "示例对话",
            "preview": "预览",
            "cwd": "/tmp/project",
            "path": "/tmp/missing.jsonl",
            "projectId": "project-1",
            "source": "vscode",
            "status": ["type": "idle"],
            "createdAt": 100.0,
            "updatedAt": 200.0
        ]

        let thread = try XCTUnwrap(CodexAppServerClient.parseThread(object, archived: false))
        XCTAssertEqual(thread.id, "thread-1")
        XCTAssertEqual(thread.displayTitle, "示例对话")
        XCTAssertEqual(thread.cwd, "/tmp/project")
        XCTAssertEqual(thread.logPaths, ["/tmp/missing.jsonl"])
        XCTAssertEqual(thread.status, "idle")
        XCTAssertEqual(thread.projectID, "project-1")
        XCTAssertFalse(thread.isArchived)
    }

    func testParsesThreadAndProjectPaginationMetadata() throws {
        let threadResponse: [String: Any] = [
            "result": [
                "data": [[
                    "id": "thread-2",
                    "name": "分页对话",
                    "cwd": "/tmp/project"
                ]],
                "nextCursor": "next-thread-page"
            ]
        ]
        let threadPage = try CodexAppServerClient.parseThreadListPage(threadResponse, archived: false)
        XCTAssertEqual(threadPage.threads.map(\.id), ["thread-2"])
        XCTAssertEqual(threadPage.nextCursor, "next-thread-page")

        let projectResponse: [String: Any] = [
            "result": [
                "data": [[
                    "id": "project-2",
                    "name": "应用与网站",
                    "roots": [["path": "/tmp/apps"]]
                ]],
                "nextCursor": "next-project-page"
            ]
        ]
        let projectPage = try CodexAppServerClient.parseProjectListPage(projectResponse)
        XCTAssertEqual(projectPage.projects.first?.name, "应用与网站")
        XCTAssertEqual(projectPage.projects.first?.rootPaths, ["/tmp/apps"])
        XCTAssertEqual(projectPage.nextCursor, "next-project-page")
    }

    func testWorkspaceResolverRelocatesMappedThreadAndMeasuresDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let threadFolder = root.appendingPathComponent("Codex Tidy", isDirectory: true)
        try FileManager.default.createDirectory(at: threadFolder, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 32).write(to: threadFolder.appendingPathComponent("source.txt"))

        let mapping = """
        {
          "threads": {
            "mapped-thread": {
              "folder": "Codex Tidy",
              "mode": "conversation"
            }
          }
        }
        """
        try Data(mapping.utf8).write(to: root.appendingPathComponent("对话目录映射.json"))

        let rawThread = CodexThreadRecord(
            id: "mapped-thread",
            title: "Codex Tidy",
            preview: "",
            cwd: "/tmp/old-location",
            logPaths: [],
            projectID: nil,
            source: "vscode",
            status: "idle",
            isArchived: false,
            createdAt: 1,
            updatedAt: 2,
            logSize: 0
        )
        let project = CodexProjectRecord(id: "apps", name: "应用与网站", rootPaths: [root.path])
        let resolved = try XCTUnwrap(WorkspaceResolver.resolve(threads: [rawThread], projects: [project]).first)

        XCTAssertEqual(resolved.cwd, threadFolder.path)
        XCTAssertEqual(resolved.sourceCwd, "/tmp/old-location")
        XCTAssertEqual(resolved.projectID, "apps")
        XCTAssertEqual(resolved.projectName, "应用与网站")
        XCTAssertEqual(resolved.resolvedProjectPath, root.path)
        XCTAssertTrue(resolved.wasWorkingDirectoryRelocated)
        XCTAssertGreaterThan(resolved.workingDirectorySize, 0)
        XCTAssertGreaterThanOrEqual(resolved.projectDirectorySize, resolved.workingDirectorySize)
    }

    func testWorkspaceResolverUsesUniqueProjectNameForMissingLegacyPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let rawThread = CodexThreadRecord(
            id: "legacy-thread",
            title: "历史对话",
            preview: "",
            cwd: "/missing/location/炒股",
            logPaths: [],
            projectID: nil,
            source: "vscode",
            status: "idle",
            isArchived: false,
            createdAt: 1,
            updatedAt: 2,
            logSize: 0
        )
        let project = CodexProjectRecord(id: "stocks", name: "炒股", rootPaths: [root.path])
        let resolved = try XCTUnwrap(WorkspaceResolver.resolve(threads: [rawThread], projects: [project]).first)

        XCTAssertEqual(resolved.cwd, root.path)
        XCTAssertEqual(resolved.projectID, "stocks")
        XCTAssertTrue(resolved.wasWorkingDirectoryRelocated)
    }

    func testRulesSeparateSafeCachesFromReviewArtifacts() throws {
        XCTAssertEqual(ArtifactScanner.rule(forDirectoryName: "node_modules")?.confidence, .safe)
        XCTAssertEqual(ArtifactScanner.rule(forDirectoryName: ".next")?.confidence, .safe)
        XCTAssertEqual(ArtifactScanner.rule(forDirectoryName: ".build")?.confidence, .safe)
        XCTAssertEqual(ArtifactScanner.rule(forDirectoryName: "dist")?.confidence, .review)
        XCTAssertNil(ArtifactScanner.rule(forDirectoryName: "Sources"))
    }

    func testScannerFindsHiddenAndVisibleCandidates() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root.appendingPathComponent(".next"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("dist"), withIntermediateDirectories: true)
        try Data(repeating: 7, count: 32).write(to: root.appendingPathComponent(".next/cache.bin"))

        let candidates = try ArtifactScanner(maxDepth: 2).scan(rootPath: root.path)
        XCTAssertEqual(Set(candidates.map(\.name)), Set([".next", "node_modules", "dist"]))
        XCTAssertEqual(candidates.filter { $0.confidence == .safe }.count, 2)
        XCTAssertEqual(candidates.filter { $0.confidence == .review }.count, 1)
    }

    func testCleanupValidationRejectsReviewArtifacts() throws {
        let scanner = ArtifactScanner()
        let safe = CleanupCandidate(path: "/tmp/project/node_modules", kind: "Node.js 依赖", confidence: .safe, size: 1)
        let review = CleanupCandidate(path: "/tmp/project/dist", kind: "发布输出", confidence: .review, size: 1)

        XCTAssertNoThrow(try scanner.validateSafeCleanup(candidate: safe, rootPath: "/tmp/project"))
        XCTAssertThrowsError(try scanner.validateSafeCleanup(candidate: review, rootPath: "/tmp/project"))
    }
}
