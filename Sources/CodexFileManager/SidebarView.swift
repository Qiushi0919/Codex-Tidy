import CodexFileCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updateChecker: UpdateChecker

    var body: some View {
        VStack(spacing: 0) {
            storageHeader
            Divider()
            List(selection: $model.selectedThreadID) {
                ForEach(model.projectGroups) { project in
                    Section {
                        ForEach(project.threads) { thread in
                            ThreadRow(thread: thread)
                                .tag(thread.id)
                        }
                    } header: {
                        HStack {
                            Label(project.name, systemImage: "folder")
                            Spacer()
                            Text(ByteFormatting.string(project.totalLogSize))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $model.searchText, prompt: "搜索对话或路径")
        }
        .navigationTitle("Codex 文件")
    }

    private var storageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("本机 Codex 空间")
                        .font(.headline)
                    Text("\(model.threads.count) 个对话记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await updateChecker.check(interactive: true) }
                } label: {
                    if updateChecker.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(
                            updateChecker.availableRelease == nil ? "检查更新" : "发现新版",
                            systemImage: updateChecker.availableRelease == nil ? "arrow.down.circle" : "sparkles"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(updateChecker.isChecking)
                .help("检查 Codex Tidy 更新")
            }

            HStack {
                storageMetric(title: "对话", id: "sessions")
                storageMetric(title: "缓存", id: "cache")
                storageMetric(title: "Worktree", id: "worktrees")
            }
        }
        .padding(14)
    }

    private func storageMetric(title: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(ByteFormatting.string(model.storageLocations.first(where: { $0.id == id })?.size ?? 0))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ThreadRow: View {
    let thread: CodexThreadRecord

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: thread.isArchived ? "archivebox" : "text.bubble")
                .foregroundStyle(thread.isArchived ? Color.secondary : Color.blue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(thread.displayTitle)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if thread.status == "active" {
                        Label("运行中", systemImage: "circle.fill")
                            .foregroundStyle(.green)
                    } else if thread.isArchived {
                        Text("已归档")
                    }
                    Text(ByteFormatting.string(thread.logSize))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .help(thread.cwd)
    }
}
