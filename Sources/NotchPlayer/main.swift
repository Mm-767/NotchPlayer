import AppKit
import SwiftUI

let expandedSize = CGSize(width: 400, height: 160)

struct NotchView: View {
    let notchSize: CGSize
    let nowPlaying: NowPlaying

    @State private var isExpanded = false

    var body: some View {
        let size = isExpanded ? expandedSize : notchSize
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
            controlButton("backward.fill", command: "previous track")

            controlButton(
                nowPlaying.isPlaying ? "pause.fill" : "play.fill",
                command: "playpause"
            )

            controlButton("forward.fill", command: "next track")
        }
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

    private var trackInfo: some View {
        HStack(spacing: 12) {
            if let artwork = nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                if nowPlaying.title.isEmpty {
                    Text("재생 중인 곡 없음")
                        .foregroundStyle(.gray)
                } else {
                    Text(nowPlaying.title)
                        .font(.headline)
                        .foregroundStyle(.white)

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
        .lineLimit(1)
        .padding(.top, notchSize.height)
        .padding(.horizontal, 24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .leading
        )
    }
}

let app = NSApplication.shared

// Dock 아이콘 없이 실행
app.setActivationPolicy(.accessory)

// 노치가 있는 화면 (외부 모니터가 main일 수 있어서 직접 찾는다)
let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main!

// 노치 높이 = 메뉴바 높이, 노치 너비 = 화면 너비 - 노치 양옆 메뉴바 너비
let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
let notchSize = CGSize(
    width: screen.frame.width - leftWidth - rightWidth,
    height: screen.safeAreaInsets.top
)

// 창은 펼친 크기로 고정하고, 검은 영역 밖의 투명한 부분은 클릭이 아래로 통과한다
let panelFrame = CGRect(
    x: screen.frame.midX - expandedSize.width / 2,
    y: screen.frame.maxY - expandedSize.height,
    width: expandedSize.width,
    height: expandedSize.height
)

let panel = NSPanel(
    contentRect: panelFrame,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)

// 메뉴바보다 위에 그린다
panel.level = .statusBar

// 모든 데스크톱(Space)과 전체화면 앱 위에서도 보이게
panel.collectionBehavior = [
    .canJoinAllSpaces,
    .stationary,
    .fullScreenAuxiliary
]

panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
let nowPlaying = NowPlaying()
nowPlaying.start()

panel.contentView = NSHostingView(
    rootView: NotchView(notchSize: notchSize, nowPlaying: nowPlaying)
)
panel.orderFrontRegardless()

print("notch: \(notchSize), panel: \(panelFrame)")

app.run()
