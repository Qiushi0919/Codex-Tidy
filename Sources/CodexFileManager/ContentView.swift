import CodexFileCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 270, ideal: 320, max: 390)
        } detail: {
            if let thread = model.selectedThread {
                ThreadDetailView(thread: thread)
                    .id(thread.id)
            } else if model.isLoading {
                ProgressView("正在读取 Codex 对话…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "选择一个对话",
                    systemImage: "sidebar.left",
                    description: Text("在左侧选择项目和对话，查看文件位置与空间占用。")
                )
            }
        }
        .task {
            if model.threads.isEmpty {
                await model.refresh()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading || model.isPerformingAction)
            }
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "未知错误")
        }
        .alert("完成", isPresented: noticeBinding) {
            Button("好", role: .cancel) { model.noticeMessage = nil }
        } message: {
            Text(model.noticeMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var noticeBinding: Binding<Bool> {
        Binding(
            get: { model.noticeMessage != nil },
            set: { if !$0 { model.noticeMessage = nil } }
        )
    }
}
