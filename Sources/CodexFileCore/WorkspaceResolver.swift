import Foundation

public enum WorkspaceResolver {
    private struct MappingFile: Decodable {
        let threads: [String: MappingEntry]
    }

    private struct MappingEntry: Decodable {
        let folder: String?
        let mode: String?
    }

    private struct ProjectRoot: Hashable {
        let project: CodexProjectRecord
        let path: String
    }

    private struct Resolution {
        let workingPath: String
        let project: CodexProjectRecord?
        let projectRoot: String?
    }

    public static func resolve(
        threads: [CodexThreadRecord],
        projects: [CodexProjectRecord]
    ) -> [CodexThreadRecord] {
        let roots = projectRoots(projects: projects, threads: threads)
        let mappedThreads = loadMappings(from: roots)

        let resolutions = threads.map { thread -> Resolution in
            if let mapped = mappedThreads[thread.id] {
                return mapped
            }

            if let projectID = thread.projectID,
               let root = roots.first(where: { $0.project.id == projectID }) {
                let matchingRoot = roots
                    .filter { $0.project.id == projectID && contains(thread.cwd, in: $0.path) }
                    .max(by: { $0.path.count < $1.path.count }) ?? root
                return Resolution(workingPath: thread.cwd, project: matchingRoot.project, projectRoot: matchingRoot.path)
            }

            if !FileManager.default.fileExists(atPath: thread.cwd),
               let root = uniqueProjectNameMatch(for: thread.cwd, roots: roots) {
                return Resolution(workingPath: root.path, project: root.project, projectRoot: root.path)
            }

            if let root = roots
                .filter({ contains(thread.cwd, in: $0.path) })
                .max(by: { $0.path.count < $1.path.count }) {
                return Resolution(workingPath: thread.cwd, project: root.project, projectRoot: root.path)
            }

            return Resolution(workingPath: thread.cwd, project: nil, projectRoot: nil)
        }

        var pathsToMeasure: Set<String> = []
        for resolution in resolutions {
            if !resolution.workingPath.isEmpty {
                pathsToMeasure.insert(standardized(resolution.workingPath))
            }
            if let projectRoot = resolution.projectRoot, !projectRoot.isEmpty {
                pathsToMeasure.insert(standardized(projectRoot))
            }
        }
        let sizes: [String: Int64] = Dictionary(uniqueKeysWithValues: pathsToMeasure.map { path in
            (path, StorageInspector.sizeOfItem(atPath: path))
        })

        return zip(threads, resolutions).map { thread, resolution in
            let workingPath = standardized(resolution.workingPath)
            let projectPath = resolution.projectRoot.map(standardized)
            return CodexThreadRecord(
                id: thread.id,
                title: thread.title,
                preview: thread.preview,
                cwd: workingPath,
                logPaths: thread.logPaths,
                projectID: resolution.project?.id ?? thread.projectID,
                source: thread.source,
                status: thread.status,
                isArchived: thread.isArchived,
                createdAt: thread.createdAt,
                updatedAt: thread.updatedAt,
                logSize: thread.logSize,
                sourceCwd: thread.sourceCwd,
                resolvedProjectName: resolution.project?.name,
                resolvedProjectPath: projectPath,
                workingDirectorySize: sizes[workingPath] ?? 0,
                projectDirectorySize: projectPath.flatMap { sizes[$0] } ?? (sizes[workingPath] ?? 0)
            )
        }
    }

    private static func projectRoots(
        projects: [CodexProjectRecord],
        threads: [CodexThreadRecord]
    ) -> [ProjectRoot] {
        var roots: [ProjectRoot] = projects.flatMap { project in
            project.rootPaths.map { ProjectRoot(project: project, path: standardized($0)) }
        }
        var knownPaths = Set(roots.map(\.path))

        for thread in threads where !thread.cwd.isEmpty {
            var candidate = URL(fileURLWithPath: thread.cwd).standardizedFileURL
            while candidate.pathComponents.count > 1 {
                let mappingPath = candidate.appendingPathComponent("对话目录映射.json").path
                if FileManager.default.fileExists(atPath: mappingPath), knownPaths.insert(candidate.path).inserted {
                    let project = CodexProjectRecord(
                        id: "path:\(candidate.path)",
                        name: candidate.lastPathComponent,
                        rootPaths: [candidate.path]
                    )
                    roots.append(ProjectRoot(project: project, path: candidate.path))
                }
                let parent = candidate.deletingLastPathComponent()
                guard parent.path != candidate.path else { break }
                candidate = parent
            }
        }

        return roots.sorted { lhs, rhs in
            if lhs.path.count != rhs.path.count { return lhs.path.count > rhs.path.count }
            return lhs.project.name.localizedStandardCompare(rhs.project.name) == .orderedAscending
        }
    }

    private static func loadMappings(from roots: [ProjectRoot]) -> [String: Resolution] {
        var result: [String: Resolution] = [:]
        let decoder = JSONDecoder()

        for root in roots {
            let mappingURL = URL(fileURLWithPath: root.path)
                .appendingPathComponent("对话目录映射.json")
            guard let data = try? Data(contentsOf: mappingURL),
                  let mapping = try? decoder.decode(MappingFile.self, from: data) else {
                continue
            }

            for (threadID, entry) in mapping.threads where result[threadID] == nil {
                let workingPath: String
                if let folder = entry.folder,
                   let safePath = safeChildPath(folder: folder, rootPath: root.path) {
                    workingPath = safePath
                } else if entry.mode == "workspace-manager" || entry.folder == nil {
                    workingPath = root.path
                } else {
                    continue
                }

                result[threadID] = Resolution(
                    workingPath: workingPath,
                    project: root.project,
                    projectRoot: root.path
                )
            }
        }
        return result
    }

    private static func safeChildPath(folder: String, rootPath: String) -> String? {
        guard !folder.isEmpty, !folder.hasPrefix("/") else { return nil }
        let root = standardized(rootPath)
        let child = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard child.hasPrefix(prefix), child != root else { return nil }
        return child
    }

    private static func contains(_ childPath: String, in rootPath: String) -> Bool {
        guard !childPath.isEmpty, !rootPath.isEmpty else { return false }
        let child = standardized(childPath)
        let root = standardized(rootPath)
        return child == root || child.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private static func uniqueProjectNameMatch(for stalePath: String, roots: [ProjectRoot]) -> ProjectRoot? {
        let oldFolderName = URL(fileURLWithPath: stalePath).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldFolderName.isEmpty else { return nil }

        let matches = roots.filter {
            $0.project.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(oldFolderName) == .orderedSame
        }
        let projectIDs = Set(matches.map(\.project.id))
        guard projectIDs.count == 1 else { return nil }
        return matches.first(where: { FileManager.default.fileExists(atPath: $0.path) }) ?? matches.first
    }

    private static func standardized(_ path: String) -> String {
        guard !path.isEmpty else { return path }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
