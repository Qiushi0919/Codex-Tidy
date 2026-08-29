import XCTest
@testable import CodexFileCore

final class CoreTests: XCTestCase {
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
