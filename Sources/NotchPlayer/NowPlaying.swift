import AppKit
import Observation

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
    }

    // command: playpause, next track, previous track (Spotify와 Music이 같은 이름을 쓴다)
    func send(_ command: String) {
        guard
            let app = playerApps.first(where: { $0.name == currentSource }),
            isRunning(app)
        else {
            return
        }

        _ = runAppleScript("tell application \"\(app.name)\" to \(command)")
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
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)

        // -1743: 사용자가 자동화 권한을 거부함
        let errorCode = error?[NSAppleScript.errorNumber] as? Int
        automationDenied = errorCode == -1743

        return result
    }
}
