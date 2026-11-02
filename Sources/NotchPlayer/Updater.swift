import AppKit
import CryptoKit
import os

// 읽기: /usr/bin/log show --predicate 'subsystem == "io.github.mm-767.NotchPlayer" && category == "update"' --last 1d
private let log = Logger(subsystem: "io.github.mm-767.NotchPlayer", category: "update")

// GitHub Releases API 응답에서 쓰는 부분만
struct Release: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL

        // "sha256:<16진수>". 받은 파일이 릴리스에 올라간 그 파일인지 확인하는 데 쓴다
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case digest
        }
    }

    let tagName: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

// "0.1.10"이 "0.1.9"보다 새 버전이 되도록 숫자끼리 비교한다. 앞의 "v"는 무시하고,
// 숫자가 아닌 게 섞인 버전(베타 등)은 새 버전으로 보지 않는다
func isNewer(_ candidate: String, than current: String) -> Bool {
    guard let new = versionNumbers(candidate), let old = versionNumbers(current) else {
        return false
    }

    for index in 0..<max(new.count, old.count) {
        let a = index < new.count ? new[index] : 0
        let b = index < old.count ? old[index] : 0

        if a != b {
            return a > b
        }
    }

    return false
}

private func versionNumbers(_ version: String) -> [Int]? {
    let trimmed = version.hasPrefix("v") ? version.dropFirst() : Substring(version)
    let numbers = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }

    guard !numbers.isEmpty, !numbers.contains(nil) else {
        return nil
    }

    return numbers.compactMap { $0 }
}

enum UpdateError: Error {
    case badResponse
    case digestMismatch
    case versionMismatch
    case commandFailed(String)
}

// GitHub Releases에 새 버전이 올라오면 받아서 앱을 바꿔 끼우고 다시 실행한다
@MainActor
final class Updater {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/Mm-767/NotchPlayer/releases/latest"
    )!

    // 비로그인 GitHub API는 IP당 시간당 60번까지라 한 시간에 한 번이면 넉넉하다
    private static let checkInterval: Duration = .seconds(60 * 60)

    private let appURL = Bundle.main.bundleURL
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    func start() {
        // swift run처럼 .app으로 묶지 않고 실행하면 버전이 없어서 건너뛴다
        guard appURL.pathExtension == "app", let currentVersion else {
            return
        }

        log.notice("current \(currentVersion, privacy: .public) at \(self.appURL.path, privacy: .public)")

        Task {
            // 로그인 직후에는 네트워크가 아직 안 붙어 있을 수 있어서 잠깐 기다린다
            try? await Task.sleep(for: .seconds(30))

            while true {
                await checkForUpdate()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    private func checkForUpdate() async {
        guard let currentVersion else {
            return
        }

        // 다운로드 폴더에서 바로 연 앱(App Translocation)이나 권한이 없는 위치면 바꿀 수 없다
        let folder = appURL.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: folder),
              FileManager.default.isWritableFile(atPath: appURL.path) else {
            log.notice("skip: \(self.appURL.path, privacy: .public) is not writable")
            return
        }

        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.badResponse
            }

            let release = try JSONDecoder().decode(Release.self, from: data)
            let version = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            guard isNewer(version, than: currentVersion) else {
                return
            }

            guard let asset = release.assets.first(where: { $0.name == "NotchPlayer-v\(version).zip" }),
                  let digest = asset.digest else {
                log.error("v\(version, privacy: .public) has no zip with digest")
                return
            }

            log.notice("updating \(currentVersion, privacy: .public) -> \(version, privacy: .public)")

            try await install(asset, version: version, digest: digest)
            relaunch()
        } catch {
            log.error("update failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func install(_ asset: Release.Asset, version: String, digest: String) async throws {
        let fileManager = FileManager.default

        // 앱과 같은 볼륨의 임시 폴더라야 마지막에 한 번에 바꿔 끼울 수 있다
        let workDir = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: appURL,
            create: true
        )
        defer {
            try? fileManager.removeItem(at: workDir)
        }

        let (downloaded, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
        let zipURL = workDir.appendingPathComponent("update.zip")
        try fileManager.moveItem(at: downloaded, to: zipURL)

        // 1. 받은 zip이 릴리스에 올라간 그 파일인지
        let hash = SHA256.hash(data: try Data(contentsOf: zipURL))
            .map { String(format: "%02x", $0) }
            .joined()

        guard "sha256:\(hash)" == digest else {
            throw UpdateError.digestMismatch
        }

        // 2. 풀기
        try await Self.run("/usr/bin/ditto", ["-x", "-k", zipURL.path, workDir.path])
        let newAppURL = workDir.appendingPathComponent("NotchPlayer.app")

        // 3. 서명이 깨지지 않았는지
        try await Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newAppURL.path])

        // 4. 안에 든 앱 버전이 릴리스 버전과 같은지 (다르면 다시 실행할 때마다 또 받게 된다)
        guard Bundle(url: newAppURL)?.infoDictionary?["CFBundleShortVersionString"] as? String == version else {
            throw UpdateError.versionMismatch
        }

        // 5. 바꿔 끼운다. 실행 중인 앱은 이전 파일을 계속 쓰므로 다시 실행하기 전까지 영향이 없다
        _ = try fileManager.replaceItemAt(appURL, withItemAt: newAppURL)
    }

    // 이 앱이 끝나기를 기다렸다가 새 앱을 연다
    private func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
            appURL.path
        ]

        do {
            try process.run()
        } catch {
            log.error("relaunch failed: \(String(describing: error), privacy: .public)")
            return
        }

        NSApp.terminate(nil)
    }

    // 명령이 끝날 때까지 메인 스레드를 막지 않고 기다린다
    nonisolated private static func run(_ path: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError.commandFailed(path))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
