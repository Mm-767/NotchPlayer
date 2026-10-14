import AppKit
import SwiftUI

let expandedSize = CGSize(width: 400, height: 160)

struct NotchView: View {
    let notchSize: CGSize

    @State private var isExpanded = false

    var body: some View {
        let size = isExpanded ? expandedSize : notchSize
        let radius: CGFloat = isExpanded ? 24 : 10

        UnevenRoundedRectangle(
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius
        )
        .fill(.black)
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
panel.contentView = NSHostingView(rootView: NotchView(notchSize: notchSize))
panel.orderFrontRegardless()

print("notch: \(notchSize), panel: \(panelFrame)")

app.run()
