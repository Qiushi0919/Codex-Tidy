import AppKit
import CodexFileCore
import SwiftUI

struct ThreadDetailView: View {
    enum PendingAction: String, Identifiable {
        case clean
        case archive
        case delete

        var id: String { rawValue }
    }

    @EnvironmentObject private var model: AppModel
    let thread: CodexThreadRecord
    @State private var pendingAction: PendingAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summaryCards
                locationsSection
                artifactsSection
                conversationSection
            }
            .padding(24)
            .frame(maxWidth: 1_050, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(thread.displayTitle)
        .task(id: thread.id) {
            await model.scanSelectedThread()
        }
        .alert(item: $pendingAction) { action in
            alert(for: action)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: thread.isArchived ? "archivebox.fill" : "folder.badge.gearshape")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(thread.isArchived ? Color.secondary : Color.blue)
                .frame(width: 54, height: 54)
                .background(.blue.opacity(thread.isArchived ? 0.05 : 0.12), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 7) {
                Text(thread.displayTitle)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    StatusBadge(text: thread.isArchived ? "已归档" : statusText, color: statusColor)
                    StatusBadge(text: thread.source, color: .secondary)
                    if thread.wasWorkingDirectoryRelocated {
                        StatusBadge(text: "已重新定位", color: .green)
                    }
                    Text(thread.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            MetricCard(
                title: "工作目录",
                value: ByteFormatting.string(thread.workingDirectorySize),
                symbol: "folder",
                tint: .indigo
            )
            MetricCard(
                title: "对话日志",
                value: ByteFormatting.string(thread.logSize),
                symbol: "doc.text",
                tint: .blue
            )
            MetricCard(
                title: "可安全清理",
                value: ByteFormatting.string(model.candidates.filter { $0.confidence == .safe }.reduce(0) { $0 + $1.size }),
                symbol: "arrow.triangle.2.circlepath",
                tint: .green
            )
            MetricCard(
                title: "需检查的产物",
                value: ByteFormatting.string(model.candidates.filter { $0.confidence == .review }.reduce(0) { $0 + $1.size }),
                symbol: "exclamationmark.triangle",
                tint: .orange
            )
        }
    }

    private var locationsSection: some View {
        SectionCard(title: "文件位置", subtitle: "刷新时重读 Codex 项目；历史路径可通过项目内的对话目录映射重新定位。") {
            VStack(spacing: 0) {
                PathRow(
                    title: thread.wasWorkingDirectoryRelocated ? "工作目录（已重新定位）" : "工作目录",
                    path: thread.cwd,
                    icon: "folder",
                    revealPath: thread.cwd
                )

                if thread.wasWorkingDirectoryRelocated {
                    Divider().padding(.leading, 34)
                    PathRow(
                        title: "Codex 原始记录（历史路径）",
                        path: thread.sourceCwd,
                        icon: "clock.arrow.circlepath",
                        revealPath: nil
                    )
                }

                Divider().padding(.leading, 34)

                PathRow(
                    title: "对话日志",
                    path: logPathDescription,
                    icon: "doc.text",
                    revealPath: thread.logPath
                )
            }
        }
    }

    private var artifactsSection: some View {
        SectionCard(
            title: "构建缓存与产物",
            subtitle: "绿色项目可从源码重新生成；黄色项目不会进入一键清理。"
        ) {
            VStack(spacing: 0) {
                HStack {
                    if model.isScanning {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在扫描工作目录…")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(model.candidates.isEmpty ? "没有发现常见构建缓存" : "发现 \(model.candidates.count) 个目录")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.scanSelectedThread() }
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isScanning || model.isPerformingAction)
                }
                .padding(.bottom, 10)

                if !model.candidates.isEmpty {
                    Divider()
                    ForEach(Array(model.candidates.enumerated()), id: \.element.id) { index, candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: model.selectedCandidateIDs.contains(candidate.id),
                            toggle: { model.toggleCandidate(candidate) }
                        )
                        if index < model.candidates.count - 1 {
                            Divider().padding(.leading, 38)
                        }
                    }

                    Divider()
                    HStack {
                        Text("已选择 \(model.selectedSafeCandidates.count) 项，共 \(ByteFormatting.string(model.selectedSafeSize))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("安全清理…", role: .destructive) {
                            pendingAction = .clean
                        }
                        .disabled(model.selectedSafeCandidates.isEmpty || model.isPerformingAction)
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    private var conversationSection: some View {
        SectionCard(
            title: "对话记录管理",
            subtitle: "归档可恢复；永久删除通过 Codex App Server 执行并会同步其内部记录。"
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.destructiveActionsLocked ? "正在运行或一小时内更新过的对话已锁定。" : "永久删除无法从废纸篓恢复。")
                        .font(.callout)
                    Text("建议先归档，确认不再需要后再永久删除。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !thread.isArchived {
                    Button("归档对话…") {
                        pendingAction = .archive
                    }
                    .disabled(thread.destructiveActionsLocked || model.isPerformingAction)
                }
                Button("永久删除…", role: .destructive) {
                    pendingAction = .delete
                }
                .disabled(thread.destructiveActionsLocked || model.isPerformingAction)
            }
        }
    }

    private var statusText: String {
        switch thread.status {
        case "active": return "运行中"
        case "idle": return "空闲"
        case "systemError": return "异常"
        default: return "未载入"
        }
    }

    private var logPathDescription: String {
        guard let path = thread.logPath else { return "Codex 未返回本地日志路径" }
        guard thread.logPaths.count > 1 else { return path }
        return "\(path)\n另有 \(thread.logPaths.count - 1) 个分段日志，大小已合并统计"
    }

    private var statusColor: Color {
        switch thread.status {
        case "active": return .green
        case "systemError": return .red
        default: return .secondary
        }
    }

    private func alert(for action: PendingAction) -> Alert {
        switch action {
        case .clean:
            return Alert(
                title: Text("将构建缓存移到废纸篓？"),
                message: Text("将移动 \(model.selectedSafeCandidates.count) 项，预计释放 \(ByteFormatting.string(model.selectedSafeSize))。这些内容通常可由源码重新生成。"),
                primaryButton: .destructive(Text("移到废纸篓")) {
                    Task { await model.cleanSelectedSafeCandidates() }
                },
                secondaryButton: .cancel()
            )
        case .archive:
            return Alert(
                title: Text("归档这个对话？"),
                message: Text("对话会从活动列表移到归档列表；关联的 Codex 托管 worktree 可能由 Codex 自动清理。"),
                primaryButton: .default(Text("归档")) {
                    Task { await model.archiveSelectedThread() }
                },
                secondaryButton: .cancel()
            )
        case .delete:
            return Alert(
                title: Text("永久删除这个 Codex 对话？"),
                message: Text("将永久删除“\(thread.displayTitle)”及其持久化记录，当前日志大小为 \(ByteFormatting.string(thread.logSize))。此操作无法从废纸篓恢复。"),
                primaryButton: .destructive(Text("永久删除")) {
                    Task { await model.deleteSelectedThread() }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct PathRow: View {
    let title: String
    let path: String
    let icon: String
    let revealPath: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(path)
                    .font(.callout.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 10)
            if let revealPath {
                if FileManager.default.fileExists(atPath: revealPath) {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: revealPath)])
                    }
                } else {
                    Label("路径不存在", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize()
                        .layoutPriority(1)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct CandidateRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if candidate.confidence == .safe {
                Button(action: toggle) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "取消选择" : "选择")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(candidate.kind)
                    Text(candidate.confidence.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(candidate.confidence == .safe ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (candidate.confidence == .safe ? Color.green : Color.orange).opacity(0.1),
                            in: Capsule()
                        )
                }
                Text(candidate.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(candidate.path)
            }
            Spacer()
            Text(ByteFormatting.string(candidate.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 9)
        .onTapGesture {
            if candidate.confidence == .safe { toggle() }
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }
}
