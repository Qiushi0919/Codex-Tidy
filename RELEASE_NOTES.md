# Codex Tidy 0.1.0 Beta 2

本次测试版加入应用内更新检查，同时保留由用户确认下载与安装的安全边界。

## 主要功能

- 定位 Codex 对话日志与对应工作目录。
- 查看对话、worktree、缓存和应用数据的磁盘占用。
- 扫描常见构建缓存，只把高置信度可重建内容移入废纸篓。
- 通过 Codex App Server 归档或永久删除对话，并保护正在运行或最近更新的对话。
- 同时支持 Apple Silicon 和 Intel Mac。
- 启动后每天检查一次 GitHub Releases，并在侧栏顶部提供手动“检查更新”按钮。
- 发现新版时只提示并打开官方 Release 下载页，不静默替换应用。

## 安装提示

本版本使用 ad-hoc 签名，尚未通过 Apple 公证。首次打开请右键应用并选择“打开”；若仍被拦截，请到“系统设置 → 隐私与安全性”选择“仍要打开”。

需要 macOS 14 或更高版本，并已安装、登录 ChatGPT/Codex。请在删除任何内容前备份或提交重要成果。

ZIP SHA-256：`980b55fa2a061e972b56170b7d53989989d781b7e7eca0f291931117e6063369`

---

This beta adds a daily GitHub Releases check and a manual update button in the sidebar. Updates are never installed silently: the app only offers to open the official Release download page. It continues to locate Codex thread logs and workspaces, report disk usage, scan rebuildable caches, and move only high-confidence cleanup candidates to Trash.

This build is ad-hoc signed and not yet Apple-notarized. Control-click the app and choose **Open** on first launch. macOS 14 or later and a local signed-in ChatGPT/Codex installation are required.
