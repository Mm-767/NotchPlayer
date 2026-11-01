import AppKit
import Observation

// 펼쳤을 때 크기. 창은 이 크기로 고정하고, 검은 영역만 노치 크기와 이 크기 사이를 오간다
let expandedSize = CGSize(width: 440, height: 160)

// 노치가 없는 화면(외부 모니터 등)에서 노치 대신 메뉴바 가운데에 그릴 캡슐 너비
let fakeNotchWidth: CGFloat = 180

// 화면 구성이 바뀌면 노치 크기도 바뀌므로 뷰가 지켜보게 한다
@MainActor
@Observable
final class NotchLayout {
    var notchSize = CGSize.zero
}

// 어느 화면에 어떤 크기로 붙을지. 화면 값만 받아서 계산하므로 테스트할 수 있다
struct NotchPlacement {
    let notchSize: CGSize
    let panelFrame: CGRect

    // notchLeftWidth, notchRightWidth: 노치 양옆 메뉴바 너비 (노치가 없는 화면이면 nil)
    init(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        notchLeftWidth: CGFloat?,
        notchRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) {
        if safeAreaTop > 0, let left = notchLeftWidth, let right = notchRightWidth {
            // 노치 높이 = 메뉴바 높이, 노치 너비 = 화면 너비 - 노치 양옆 메뉴바 너비
            notchSize = CGSize(
                width: screenFrame.width - left - right,
                height: safeAreaTop
            )
        } else {
            // 노치가 없으면 메뉴바 가운데에 메뉴바 높이의 캡슐을 그려 노치처럼 쓴다
            notchSize = CGSize(width: fakeNotchWidth, height: menuBarHeight)
        }

        // 고른 화면의 위쪽 가운데에 붙인다. 검은 영역 밖의 투명한 부분은 클릭이 아래로 통과한다
        panelFrame = CGRect(
            x: screenFrame.midX - expandedSize.width / 2,
            y: screenFrame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }
}

extension NotchPlacement {
    // 노치가 있는 화면을 먼저 쓴다 (외부 모니터가 주 화면일 수 있어서 직접 찾는다).
    // 없으면(뚜껑을 닫고 외부 모니터만 쓸 때 등) 메뉴바가 있는 주 화면에 붙는다
    @MainActor
    static func current() -> NotchPlacement? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.screens.first
        else {
            return nil
        }

        // 메뉴바 자동 가리기를 켜면 visibleFrame이 메뉴바 자리까지 덮어서 0이 나온다
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

        return NotchPlacement(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            notchLeftWidth: screen.auxiliaryTopLeftArea?.width,
            notchRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: menuBarHeight > 0 ? menuBarHeight : NSStatusBar.system.thickness
        )
    }
}
