import AppKit
import ServiceManagement
import SwiftUI

struct NotchView: View {
    let layout: NotchLayout
    let nowPlaying: NowPlaying

    @State private var isExpanded = false

    var body: some View {
        let size = isExpanded ? expandedSize : layout.notchSize
        let radius: CGFloat = isExpanded ? 24 : 10

        UnevenRoundedRectangle(
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius
        )
        .fill(.black)
        .overlay {
            if isExpanded {
                trackInfo
            }
        }
        .frame(width: size.width, height: size.height)
        .onHover { hovering in
            if hovering {
                nowPlaying.refreshPlayerState()
            }

            withAnimation(.spring(duration: 0.3)) {
                isExpanded = hovering
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
    }

    private var controls: some View {
        HStack(spacing: 16) {
            toggleButton(
                "shuffle",
                isOn: nowPlaying.shuffle,
                action: nowPlaying.toggleShuffle
            )

            controlButton("backward.fill", command: "previous track")

            controlButton(
                nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                command: "playpause"
            )

            controlButton("forward.fill", command: "next track")

            toggleButton(
                nowPlaying.repeatMode == "one" ? "repeat.1" : "repeat",
                isOn: nowPlaying.repeatMode != "off",
                action: nowPlaying.cycleRepeat
            )
        }
    }

    // 켜져 있으면 흰색, 꺼져 있으면 회색
    private func toggleButton(_ symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(isOn ? .white : .gray)
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ symbol: String, command: String) -> some View {
        Button {
            nowPlaying.send(command)
        } label: {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Scrubber(
                value: nowPlaying.elapsed(at: context.date),
                total: nowPlaying.duration,
                onSeek: nowPlaying.seek(to:)
            )
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 12) {
            trackRow

            if nowPlaying.duration > 0 {
                progress
            }
        }
        .lineLimit(1)
        .padding(.top, layout.notchSize.height)
        .padding(.horizontal, 24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .leading
        )
    }

    private var trackRow: some View {
        HStack(spacing: 12) {
            if let artwork = nowPlaying.artwork {
                Button {
                    nowPlaying.openCurrentApp()
                } label: {
                    Image(nsImage: artwork)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                if nowPlaying.title.isEmpty {
                    Text("재생 중인 곡 없음")
                        .foregroundStyle(.gray)
                } else {
                    HStack(spacing: 6) {
                        Text(nowPlaying.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let isFavorited = nowPlaying.isFavorited {
                            toggleButton(
                                isFavorited ? "heart.fill" : "heart",
                                isOn: isFavorited,
                                action: nowPlaying.toggleFavorite
                            )
                        }
                    }

                    Text(nowPlaying.artist)
                        .foregroundStyle(.gray)
                }

                // 권한을 한 번 거부하면 macOS가 다시 묻지 않아서 설정으로 보낸다
                if nowPlaying.automationDenied {
                    Button("시스템 설정에서 자동화 허용하기") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            if !nowPlaying.title.isEmpty {
                Spacer()

                controls
            }
        }
    }
}

let app = NSApplication.shared

// Dock 아이콘 없이 실행
app.setActivationPolicy(.accessory)

// 처음 한 번만 로그인 항목에 등록한다. 사용자가 시스템 설정에서 끄면 다시 켜지 않는다
// (한 번도 등록 안 한 앱의 status는 notRegistered가 아니라 notFound라서 status로는 판단하지 않는다)
if !UserDefaults.standard.bool(forKey: "didRegisterLoginItem"),
   (try? SMAppService.mainApp.register()) != nil {
    UserDefaults.standard.set(true, forKey: "didRegisterLoginItem")
}

let nowPlaying = NowPlaying()
nowPlaying.start()

// 맥북 화면과 외부 모니터마다 하나씩 띄운다
let notchWindows = NotchWindows(nowPlaying: nowPlaying)
notchWindows.update()

// 모니터를 꽂거나 빼고, 맥북 뚜껑을 닫거나 열면 macOS가 창을 남은 화면 아무 데나 옮겨서
// 노치 크기의 검은 막대가 화면 중간에 떠 있게 된다. 화면 구성이 바뀔 때마다 다시 붙인다
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil,
    queue: .main
) { _ in
    MainActor.assumeIsolated {
        notchWindows.update()
    }
}

app.run()
