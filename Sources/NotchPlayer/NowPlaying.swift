import Foundation
import Observation

@MainActor
@Observable
final class NowPlaying {
    var title = ""
    var artist = ""

    // 둘 다 재생 중이면 마지막으로 재생을 시작한 앱을 보여준다
    private var currentSource = ""

    init() {
        let sources = [
            "com.spotify.client.PlaybackStateChanged",
            "com.apple.Music.playerInfo"
        ]

        for source in sources {
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(source),
                object: nil,
                queue: .main
            ) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String ?? ""
                let title = info["Name"] as? String ?? ""
                let artist = info["Artist"] as? String ?? ""

                MainActor.assumeIsolated {
                    self?.update(
                        source: source,
                        state: state,
                        title: title,
                        artist: artist
                    )
                }
            }
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
            return
        }

        currentSource = source
        self.title = title
        self.artist = artist
    }
}
