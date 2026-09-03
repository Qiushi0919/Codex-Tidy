import Foundation

public struct CodexAppServerClient: Sendable {
    public let executableURL: URL

    public init(executableURL: URL? = nil) throws {
        if let executableURL {
            self.executableURL = executableURL
            return
        }
        guard let detected = Self.locateCodexExecutable() else {
            throw CodexFileManagerError.codexNotFound
        }
        self.executableURL = detected
    }

    public static func locateCodexExecutable() -> URL? {
        let fileManager = FileManager.default
        var candidates: [String] = []

        if let configured = ProcessInfo.processInfo.environment["CODEX_BINARY"], !configured.isEmpty {
            candidates.append(configured)
        }

        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                candidates.append(String(directory) + "/codex")
            }
        }

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    public func listThreads() throws -> [CodexThreadRecord] {
        let active = try listThreadSegment(archived: false)
        let archived = try listThreadSegment(archived: true)
        return Self.mergeThreadSegments(active + archived)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func listProjects() throws -> [CodexProjectRecord] {
        var projects: [CodexProjectRecord] = []
        var cursor: String?
        var seenCursors: Set<String> = []

        repeat {
            var params: [String: Any] = ["limit": 100]
            if let cursor { params["cursor"] = cursor }
            let response = try perform(method: "project/list", params: params)
            let page = try Self.parseProjectListPage(response)
            projects.append(contentsOf: page.projects)

            guard let nextCursor = page.nextCursor, !nextCursor.isEmpty else { break }
            guard seenCursors.insert(nextCursor).inserted else {
                throw CodexFileManagerError.malformedResponse("project/list 返回了重复的分页游标")
            }
            cursor = nextCursor
        } while true

        return Dictionary(grouping: projects, by: \.id)
            .compactMap { $0.value.first }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func archiveThread(id: String) throws {
        let response = try perform(
            method: "thread/archive",
            params: ["threadId": id]
        )
        try Self.throwIfError(response)
    }

    public func deleteThread(id: String) throws {
        let response = try perform(
            method: "thread/delete",
            params: ["threadId": id]
        )
        try Self.throwIfError(response)
    }

    private var initializeRequest: [String: Any] {
        [
            "method": "initialize",
            "id": 0,
            "params": [
                "clientInfo": [
                    "name": "codex_file_manager",
                    "title": "Codex Tidy",
                    "version": "0.1.0"
                ],
                "capabilities": ["experimentalApi": true]
            ]
        ]
    }

    private func listThreadSegment(archived: Bool) throws -> [CodexThreadRecord] {
        var threads: [CodexThreadRecord] = []
        var cursor: String?
        var seenCursors: Set<String> = []

        repeat {
            var params: [String: Any] = [
                "limit": 200,
                "sortKey": "updated_at",
                "sortDirection": "desc",
                "archived": archived
            ]
            if let cursor { params["cursor"] = cursor }

            let response = try perform(method: "thread/list", params: params)
            let page = try Self.parseThreadListPage(response, archived: archived)
            threads.append(contentsOf: page.threads)

            guard let nextCursor = page.nextCursor, !nextCursor.isEmpty else { break }
            guard seenCursors.insert(nextCursor).inserted else {
                throw CodexFileManagerError.malformedResponse("thread/list 返回了重复的分页游标")
            }
            cursor = nextCursor
        } while true

        return threads
    }

    private func perform(method: String, params: [String: Any]) throws -> [String: Any] {
        let requests: [[String: Any]] = [
            initializeRequest,
            ["method": "initialized", "params": [:]],
            ["method": method, "id": 1, "params": params]
        ]
        let responses = try run(requests: requests)
        guard let response = responses[1] else {
            throw CodexFileManagerError.malformedResponse("没有收到 \(method) 的响应")
        }
        return response
    }

    private func run(requests: [[String: Any]]) throws -> [Int: [String: Any]] {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()
        let expectedIDs = Set(requests.compactMap { Self.integerID($0["id"]) })
        let completion = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var responseBuffer = Data()
        var responses: [Int: [String: Any]] = [:]
        var didSignal = false

        process.executableURL = executableURL
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            responseBuffer.append(data)

            while let newline = responseBuffer.firstIndex(of: 0x0A) {
                let line = responseBuffer.prefix(upTo: newline)
                responseBuffer.removeSubrange(...newline)
                guard !line.isEmpty,
                      let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      let id = Self.integerID(object["id"]) else {
                    continue
                }
                responses[id] = object
            }

            if !didSignal && expectedIDs.isSubset(of: Set(responses.keys)) {
                didSignal = true
                completion.signal()
            }
            lock.unlock()
        }

        try process.run()

        let payload = try requests.map { request -> Data in
            var data = try JSONSerialization.data(withJSONObject: request)
            data.append(0x0A)
            return data
        }.reduce(into: Data()) { $0.append($1) }

        stdin.fileHandleForWriting.write(payload)
        let waitResult = completion.wait(timeout: .now() + 15)

        stdout.fileHandleForReading.readabilityHandler = nil
        try? stdin.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        lock.lock()
        let capturedResponses = responses
        lock.unlock()

        guard waitResult == .success else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (stderrText?.isEmpty == false ? stderrText : nil) ?? "等待 App Server 响应超时"
            throw CodexFileManagerError.appServerFailed(message)
        }

        return capturedResponses
    }

    static func parseThreadListPage(
        _ response: [String: Any],
        archived: Bool
    ) throws -> (threads: [CodexThreadRecord], nextCursor: String?) {
        try throwIfError(response)

        guard let result = response["result"] as? [String: Any],
              let data = result["data"] as? [[String: Any]] else {
            throw CodexFileManagerError.malformedResponse("thread/list 缺少 data")
        }

        return (
            data.compactMap { Self.parseThread($0, archived: archived) },
            result["nextCursor"] as? String
        )
    }

    static func parseProjectListPage(
        _ response: [String: Any]
    ) throws -> (projects: [CodexProjectRecord], nextCursor: String?) {
        try throwIfError(response)
        guard let result = response["result"] as? [String: Any],
              let data = result["data"] as? [[String: Any]] else {
            throw CodexFileManagerError.malformedResponse("project/list 缺少 data")
        }

        let projects = data.compactMap { object -> CodexProjectRecord? in
            guard let id = object["id"] as? String,
                  let name = object["name"] as? String else { return nil }
            let roots = (object["roots"] as? [[String: Any]] ?? [])
                .compactMap { $0["path"] as? String }
            return CodexProjectRecord(id: id, name: name, rootPaths: roots)
        }
        return (projects, result["nextCursor"] as? String)
    }

    private static func throwIfError(_ response: [String: Any]) throws {
        guard let error = response["error"] as? [String: Any] else { return }
        let message = error["message"] as? String ?? String(describing: error)
        throw CodexFileManagerError.appServerFailed(message)
    }

    public static func parseThread(_ object: [String: Any], archived: Bool) -> CodexThreadRecord? {
        guard let id = object["id"] as? String else { return nil }

        let name = object["name"] as? String ?? ""
        let preview = object["preview"] as? String ?? ""
        let cwd = object["cwd"] as? String ?? ""
        let path = object["path"] as? String
        let projectID = object["projectId"] as? String
        let source = Self.sourceName(object["source"])
        let statusObject = object["status"] as? [String: Any]
        let status = statusObject?["type"] as? String ?? "notLoaded"
        let createdAt = Self.timeInterval(object["createdAt"])
        let updatedAt = Self.timeInterval(object["updatedAt"])
        let size = path.flatMap(Self.fileSize) ?? 0

        return CodexThreadRecord(
            id: id,
            title: name,
            preview: preview,
            cwd: cwd,
            logPaths: path.map { [$0] } ?? [],
            projectID: projectID,
            source: source,
            status: status,
            isArchived: archived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            logSize: size
        )
    }

    private static func sourceName(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let object = value as? [String: Any], let type = object["type"] as? String { return type }
        return "unknown"
    }

    private static func mergeThreadSegments(_ records: [CodexThreadRecord]) -> [CodexThreadRecord] {
        Dictionary(grouping: records, by: \.id).compactMap { _, segments in
            guard let primary = segments.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }

            let primaryPath = primary.logPath
            let allPaths = Array(Set(segments.flatMap(\.logPaths)))
            let orderedPaths = allPaths.sorted { lhs, rhs in
                if lhs == primaryPath { return true }
                if rhs == primaryPath { return false }
                return lhs < rhs
            }
            let totalSize = orderedPaths.reduce(Int64(0)) { partial, path in
                partial + (fileSize(path) ?? 0)
            }

            return CodexThreadRecord(
                id: primary.id,
                title: primary.title,
                preview: primary.preview,
                cwd: primary.cwd,
                logPaths: orderedPaths,
                projectID: primary.projectID,
                source: primary.source,
                status: primary.status,
                isArchived: segments.allSatisfy(\.isArchived),
                createdAt: segments.map(\.createdAt).min() ?? primary.createdAt,
                updatedAt: segments.map(\.updatedAt).max() ?? primary.updatedAt,
                logSize: totalSize
            )
        }
    }

    private static func timeInterval(_ value: Any?) -> TimeInterval {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let number = Double(string) { return number }
        return 0
    }

    private static func integerID(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func fileSize(_ path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }
}
