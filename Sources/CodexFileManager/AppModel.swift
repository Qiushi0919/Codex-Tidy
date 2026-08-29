import CodexFileCore
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var threads: [CodexThreadRecord] = []
    @Published var storageLocations: [StorageLocation] = []
    @Published var selectedThreadID: String?
    @Published var candidates: [CleanupCandidate] = []
    @Published var selectedCandidateIDs: Set<String> = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private let scanner = ArtifactScanner()

    var selectedThread: CodexThreadRecord? {
        guard let selectedThreadID else { return nil }
        return threads.first { $0.id == selectedThreadID }
    }

    var projectGroups: [ProjectGroup] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let visibleThreads = threads.filter { thread in
            guard !normalizedSearch.isEmpty else { return true }
            return thread.displayTitle.lowercased().contains(normalizedSearch)
                || thread.cwd.lowercased().contains(normalizedSearch)
                || thread.id.lowercased().contains(normalizedSearch)
        }

        return Dictionary(grouping: visibleThreads, by: \CodexThreadRecord.projectKey)
            .map { key, groupedThreads in
                let sorted = groupedThreads.sorted { $0.updatedAt > $1.updatedAt }
                let representative = sorted[0]
                return ProjectGroup(
                    id: key,
                    name: representative.projectName,
                    path: representative.cwd,
                    threads: sorted
                )
            }
            .sorted {
                let lhs = $0.threads.first?.updatedAt ?? 0
                let rhs = $1.threads.first?.updatedAt ?? 0
                return lhs > rhs
            }
    }

    var selectedSafeCandidates: [CleanupCandidate] {
        candidates.filter {
            $0.confidence == .safe && selectedCandidateIDs.contains($0.id)
        }
    }

    var selectedSafeSize: Int64 {
        selectedSafeCandidates.reduce(0) { $0 + $1.size }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let client = try CodexAppServerClient()
            async let loadedThreads = Task.detached(priority: .userInitiated) {
                try client.listThreads()
            }.value
            async let loadedStorage = Task.detached(priority: .utility) {
                StorageInspector.inspectDefaultLocations()
            }.value

            let (newThreads, newStorage) = try await (loadedThreads, loadedStorage)
            threads = newThreads
            storageLocations = newStorage

            if let selectedThreadID, threads.contains(where: { $0.id == selectedThreadID }) {
                self.selectedThreadID = selectedThreadID
            } else {
                selectedThreadID = threads.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func scanSelectedThread() async {
        guard let thread = selectedThread, !thread.cwd.isEmpty else {
            candidates = []
            selectedCandidateIDs = []
            return
        }

        let requestedThreadID = thread.id
        isScanning = true
        candidates = []
        selectedCandidateIDs = []

        do {
            let rootPath = thread.cwd
            let found = try await Task.detached(priority: .utility) { [scanner] in
                try scanner.scan(rootPath: rootPath)
            }.value

            guard selectedThreadID == requestedThreadID else { return }
            candidates = found
            selectedCandidateIDs = Set(found.filter { $0.confidence == .safe }.map(\.id))
        } catch {
            guard selectedThreadID == requestedThreadID else { return }
            errorMessage = error.localizedDescription
        }

        if selectedThreadID == requestedThreadID {
            isScanning = false
        }
    }

    func cleanSelectedSafeCandidates() async {
        guard let thread = selectedThread else { return }
        let targets = selectedSafeCandidates
        guard !targets.isEmpty else { return }

        isPerformingAction = true
        do {
            let rootPath = thread.cwd
            let reclaimed = try await Task.detached(priority: .userInitiated) { [scanner] in
                try scanner.moveToTrash(candidates: targets, rootPath: rootPath)
            }.value
            noticeMessage = "已将 \(targets.count) 项移到废纸篓，预计释放 \(ByteFormatting.string(reclaimed))。"
            await scanSelectedThread()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
    }

    func archiveSelectedThread() async {
        guard let thread = selectedThread, !thread.isArchived, !thread.destructiveActionsLocked else { return }
        isPerformingAction = true
        do {
            let client = try CodexAppServerClient()
            try await Task.detached(priority: .userInitiated) {
                try client.archiveThread(id: thread.id)
            }.value
            noticeMessage = "已归档“\(thread.displayTitle)”。"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
    }

    func deleteSelectedThread() async {
        guard let thread = selectedThread, !thread.destructiveActionsLocked else { return }
        isPerformingAction = true
        do {
            let client = try CodexAppServerClient()
            try await Task.detached(priority: .userInitiated) {
                try client.deleteThread(id: thread.id)
            }.value
            noticeMessage = "已永久删除“\(thread.displayTitle)”的 Codex 对话记录。"
            selectedThreadID = nil
            candidates = []
            selectedCandidateIDs = []
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
    }

    func toggleCandidate(_ candidate: CleanupCandidate) {
        guard candidate.confidence == .safe else { return }
        if selectedCandidateIDs.contains(candidate.id) {
            selectedCandidateIDs.remove(candidate.id)
        } else {
            selectedCandidateIDs.insert(candidate.id)
        }
    }
}
