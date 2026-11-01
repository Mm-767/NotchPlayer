import CoreGraphics
import Testing
@testable import NotchPlayer

// 노치가 있는 맥북 화면: 화면 너비에서 노치 양옆 메뉴바 너비를 빼면 노치 너비
@Test func 노치가_있으면_노치_크기에_맞춰_화면_위쪽_가운데에_붙는다() {
    let placement = NotchPlacement(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTop: 32,
        notchLeftWidth: 662,
        notchRightWidth: 664,
        menuBarHeight: 32
    )

    #expect(placement.notchSize == CGSize(width: 186, height: 32))
    #expect(placement.panelFrame == CGRect(x: 536, y: 822, width: 440, height: 160))
}

// 노치가 없는 외부 모니터: 메뉴바 가운데에 메뉴바 높이의 캡슐로 붙는다.
// 맥북 왼쪽 위에 놓인 모니터라 좌표가 0에서 시작하지 않아도 그 화면 위쪽 가운데여야 한다
@Test func 노치가_없으면_그_화면_메뉴바_가운데에_붙는다() {
    let placement = NotchPlacement(
        screenFrame: CGRect(x: -1920, y: 982, width: 1920, height: 1080),
        safeAreaTop: 0,
        notchLeftWidth: nil,
        notchRightWidth: nil,
        menuBarHeight: 24
    )

    #expect(placement.notchSize == CGSize(width: fakeNotchWidth, height: 24))
    #expect(placement.panelFrame == CGRect(x: -1180, y: 1902, width: 440, height: 160))
}
