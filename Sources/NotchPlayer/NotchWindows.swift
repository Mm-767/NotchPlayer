import AppKit
import SwiftUI

// 화면마다 노치 창을 하나씩 띄운다.
// 맥북 화면은 노치에, 노치가 없는 외부 모니터는 메뉴바 가운데에 붙는다
@MainActor
final class NotchWindows {
    private let nowPlaying: NowPlaying

    // 화면 번호 → 그 화면의 창
    private var windows: [CGDirectDisplayID: NotchWindow] = [:]

    init(nowPlaying: NowPlaying) {
        self.nowPlaying = nowPlaying
    }

    // 처음 한 번, 그리고 모니터를 꽂고 빼거나 뚜껑을 여닫는 등 화면 구성이 바뀔 때마다 부른다.
    // 이미 있던 화면의 창은 그대로 두고 위치만 다시 잡아서, 펼쳐 둔 창이 깜빡이지 않게 한다
    func update() {
        var removed = windows
        windows = [:]

        for screen in NSScreen.screens {
            guard let id = screen.displayID else {
                continue
            }

            let window = removed.removeValue(forKey: id) ?? NotchWindow(nowPlaying: nowPlaying)
            let placement = NotchPlacement(screen: screen)
            window.place(placement)
            windows[id] = window

            print("screen \(id): notch \(placement.notchSize), panel \(placement.panelFrame)")
        }

        // 빠진 화면(뚜껑을 닫은 맥북, 뽑은 모니터)의 창은 치운다
        for window in removed.values {
            window.remove()
        }
    }
}

// 화면 하나에 붙는 창
@MainActor
private final class NotchWindow {
    private let layout = NotchLayout()

    private let panel = NSPanel(
        contentRect: CGRect(origin: .zero, size: expandedSize),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )

    init(nowPlaying: NowPlaying) {
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

        panel.contentView = NSHostingView(
            rootView: NotchView(layout: layout, nowPlaying: nowPlaying)
        )
    }

    func place(_ placement: NotchPlacement) {
        layout.notchSize = placement.notchSize
        panel.setFrame(placement.panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    func remove() {
        panel.orderOut(nil)
    }
}

extension NSScreen {
    // 화면마다 붙는 번호. 같은 모니터를 다시 꽂거나 뚜껑을 다시 열면 같은 번호가 나온다
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
