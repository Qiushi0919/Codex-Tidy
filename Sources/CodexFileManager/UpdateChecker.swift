import AppKit
import CodexFileCore
import Foundation

struct AppRelease: Identifiable {
    let tagName: String
    let title: String
    let pageURL: URL
    let notes: String

    var id: String { tagName }
}

enum UpdatePresentation: Identifiable {
    case available(AppRelease)
    case message(title: String, body: String)

    var id: String {
        switch self {
        case let .available(release): release.id
        case let .message(title, body): title + body
        }
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var availableRelease: AppRelease?
    @Published var presentation: UpdatePresentation?

    private let manifestURL = URL(string: "https://raw.githubusercontent.com/Qiushi0919/Codex-Tidy/refs/heads/main/update.json")!
    private let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    private let lastCheckKey = "CodexTidyLastUpdateCheck"

    func checkAutomaticallyIfNeeded() async {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) >= automaticCheckInterval else { return }
        await check(interactive: false)
    }

    func check(interactive: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Codex-Tidy-Update-Checker", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw UpdateCheckError.unavailable
            }

            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
            guard let latestVersion = ReleaseVersion(manifest.version) else {
                throw UpdateCheckError.noRelease
            }

            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            if ReleaseVersion(currentReleaseVersion).map({ $0 < latestVersion }) ?? true {
                let release = AppRelease(
                    tagName: manifest.version,
                    title: manifest.title,
                    pageURL: manifest.pageURL,
                    notes: manifest.notes
                )
                availableRelease = release
                presentation = .available(release)
            } else if interactive {
                presentation = .message(title: "已是最新版本", body: "当前版本 \(currentReleaseVersion)，暂无可用更新。")
            }
        } catch {
            if interactive {
                presentation = .message(title: "检查更新失败", body: error.localizedDescription)
            }
        }
    }

    func openRelease(_ release: AppRelease) {
        NSWorkspace.shared.open(release.pageURL)
    }

    private var currentReleaseVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CodexTidyReleaseVersion") as? String ?? "0.1.0-beta.2"
    }
}

private struct UpdateManifest: Decodable {
    let version: String
    let title: String
    let pageURL: URL
    let notes: String

    enum CodingKeys: String, CodingKey {
        case version
        case title
        case pageURL = "html_url"
        case notes
    }
}

private enum UpdateCheckError: LocalizedError {
    case unavailable
    case noRelease

    var errorDescription: String? {
        switch self {
        case .unavailable: "无法读取公开更新清单，请稍后再试。"
        case .noRelease: "公开更新清单中的版本号无效。"
        }
    }
}
