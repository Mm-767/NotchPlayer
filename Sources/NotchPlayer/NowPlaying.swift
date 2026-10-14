import AppKit
import Observation
import os

// 지표 측정용. 읽기: /usr/bin/log show --predicate 'subsystem == "io.github.mm-767.NotchPlayer"' --last 10m
private let log = Logger(subsystem: "io.github.mm-767.NotchPlayer", category: "timing")

private struct PlayerApp {
    let name: String
    let bundleID: String
    let notification: String
}

private let playerApps = [
    PlayerApp(
        name: "Spotify",
        bundleID: "com.spotify.client",
        notification: "com.spotify.client.PlaybackStateChanged"
    ),
    PlayerApp(
        name: "Music",
        bundleID: "com.apple.Music",
        notification: "com.apple.Music.playerInfo"
    )
]

@MainActor
@Observable
final class NowPlaying {
    var title = ""
    var artist = ""
    var artwork: NSImage?
    var isPlaying = false
    var automationDenied = false

    // 진행바: 마지막으로 앱에 물어본 위치(초)와 그 시각에서 흐른 시간을 더해 그린다
    var duration: Double = 0
    var position: Double = 0
    var positionDate = Date()

    // 둘 다 재생 중이면 마지막으로 재생을 시작한 앱을 보여준다
    private var currentSource = ""

    func start() {
        for app in playerApps {
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(app.notification),
                object: nil,
                queue: .main
            ) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String ?? ""
                let title = info["Name"] as? String ?? ""
                let artist = info["Artist"] as? String ?? ""

                log.notice("notify \(app.name, privacy: .public) \(state, privacy: .public)")

                MainActor.assumeIsolated {
                    self?.update(
                        source: app.name,
                        state: state,
                        title: title,
                        artist: artist
                    )
                }
            }

            loadCurrentTrack(app)
        }

        #if BENCH
        // 지표 측정 전용 빌드: 다른 프로세스가 분산 알림으로 버튼과 같은 명령을 보낼 수 있다
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("io.github.mm-767.NotchPlayer.bench"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let command = note.object as? String ?? ""

            MainActor.assumeIsolated {
                self?.send(command)
            }
        }
        #endif
    }

    func update(source: String, state: String, title: String, artist: String) {
        if state == "Playing" {
            currentSource = source
        }

        // 표시 중이 아닌 앱의 일시정지·종료는 무시한다
        guard currentSource.isEmpty || source == currentSource else {
            return
        }

        if state == "Stopped" {
            currentSource = ""
            self.title = ""
            self.artist = ""
            artwork = nil
            isPlaying = false
            duration = 0
            return
        }

        let trackChanged = title != self.title

        currentSource = source
        self.title = title
        self.artist = artist
        isPlaying = state == "Playing"

        if trackChanged {
            artwork = nil
            loadArtwork(source)
        }

        loadPosition(source)
    }

    func elapsed(at date: Date) -> Double {
        guard isPlaying else {
            return position
        }

        return min(duration, position + date.timeIntervalSince(positionDate))
    }

    private func loadPosition(_ source: String) {
        guard
            let app = playerApps.first(where: { $0.name == source }),
            isRunning(app)
        else {
            return
        }

        let script = "tell application \"\(app.name)\" to {player position, duration of current track}"

        guard let result = runAppleScript(script), result.numberOfItems == 2 else {
            return
        }

        let rawDuration = result.atIndex(2)?.doubleValue ?? 0

        position = result.atIndex(1)?.doubleValue ?? 0
        positionDate = Date()

        // 곡 길이 단위: Spotify는 밀리초, Music은 초
        duration = app.name == "Spotify" ? rawDuration / 1000 : rawDuration
    }

    // command: playpause, next track, previous track (Spotify와 Music이 같은 이름을 쓴다)
    func send(_ command: String) {
        guard
            let app = playerApps.first(where: { $0.name == currentSource }),
            isRunning(app)
        else {
            return
        }

        log.notice("send \(command, privacy: .public)")

        _ = runAppleScript("tell application \"\(app.name)\" to \(command)")
    }

    // 지금 표시 중인 곡을 재생하는 앱을 앞으로 띄운다
    func openCurrentApp() {
        guard
            let app = playerApps.first(where: { $0.name == currentSource }),
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
        else {
            return
        }

        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // 앱 안에서 재생 위치를 옮기면 알림이 오지 않아서, 노치를 펼칠 때 다시 묻는다
    func refreshPosition() {
        let predicted = elapsed(at: Date())

        loadPosition(currentSource)

        // 진행바가 앱의 실제 위치와 얼마나 어긋나 있었는지 (양수면 진행바가 앞서 있었음)
        log.notice("drift \(predicted - self.position, format: .fixed(precision: 2))s")
    }

    func seek(to seconds: Double) {
        guard
            let app = playerApps.first(where: { $0.name == currentSource }),
            isRunning(app)
        else {
            return
        }

        _ = runAppleScript("tell application \"\(app.name)\" to set player position to \(seconds)")

        // 위치를 옮겨도 알림이 오지 않으므로 직접 반영한다
        position = seconds
        positionDate = Date()
    }

    // 켤 때는 곡이 바뀌기 전이라 알림이 없으니 앱에 직접 묻는다
    private func loadCurrentTrack(_ app: PlayerApp) {
        guard isRunning(app) else {
            return
        }

        let script = """
            tell application "\(app.name)"
                if player state is stopped then return {"stopped", "", ""}
                return {player state as string, name of current track, artist of current track}
            end tell
            """

        guard let result = runAppleScript(script), result.numberOfItems == 3 else {
            return
        }

        update(
            source: app.name,
            state: (result.atIndex(1)?.stringValue ?? "").capitalized,
            title: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? ""
        )
    }

    private func loadArtwork(_ source: String) {
        guard
            let app = playerApps.first(where: { $0.name == source }),
            isRunning(app)
        else {
            return
        }

        let requestedTitle = title

        Task {
            let image = await artworkImage(app)

            // 받아오는 사이에 곡이 바뀌었으면 버린다
            if title == requestedTitle {
                artwork = image
                log.notice("artwork \(app.name, privacy: .public) \(image == nil ? "nil" : "ok", privacy: .public)")
            }
        }
    }

    private func artworkImage(_ app: PlayerApp) async -> NSImage? {
        // Spotify는 이미지 URL을, Music은 이미지 데이터를 준다
        if app.name == "Spotify" {
            let script = #"tell application "Spotify" to artwork url of current track"#

            guard
                let urlString = runAppleScript(script)?.stringValue,
                let url = URL(string: urlString),
                let (data, _) = try? await URLSession.shared.data(from: url)
            else {
                return nil
            }

            return NSImage(data: data)
        }

        let script = #"tell application "Music" to raw data of artwork 1 of current track"#

        guard let data = runAppleScript(script)?.data else {
            return nil
        }

        return NSImage(data: data)
    }

    // 꺼져 있는 앱에 AppleScript를 보내면 그 앱이 켜지므로 먼저 확인한다
    private func isRunning(_ app: PlayerApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
    }

    // ponytail: 메인 스레드에서 동기로 실행해서 앱 응답이 늦으면 UI가 잠깐 멈춘다. 끊기면 osascript 프로세스로 옮긴다
    private func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        let start = Date()
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

        // -1743: 사용자가 자동화 권한을 거부함
        let errorCode = error?[NSAppleScript.errorNumber] as? Int
        automationDenied = errorCode == -1743

        let milliseconds = Int(Date().timeIntervalSince(start) * 1000)
        let summary = source.replacingOccurrences(of: "\n", with: " ").prefix(60)
        log.notice("applescript \(milliseconds)ms error=\(errorCode ?? 0) \(summary, privacy: .public)")

        return result
    }
}
