import AppKit

// 앱 아이콘 원본(1024px PNG)을 그린다. .icns는 scripts/make-icon.sh가 만든다
// 올블랙 캐릭터: 45도 옆모습, 고개를 숙인 채 표정 없이, 오른쪽 위에서 오는 림 라이트로만 형태를 드러낸다
// 사용법: swift scripts/icon.swift <출력 png>

let size: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let ink = color(0x050506)
let inkSoft = color(0x0E0E11)
let rimColor = color(0xD9DCE3)

func fill(_ path: NSBezierPath, _ c: NSColor) {
    c.setFill()
    path.fill()
}

// 도형 안쪽 가장자리를 따라, from 쪽은 밝고 to 쪽으로 사라지는 테두리 빛
func rim(_ path: NSBezierPath, width: CGFloat, from: CGPoint, to: CGPoint, alpha: CGFloat = 0.9) {
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.addPath(path.cgPath)
    context.clip()
    context.addPath(path.cgPath.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    context.clip()
    let gradient = CGGradient(
        colorsSpace: nil,
        colors: [rimColor.withAlphaComponent(alpha).cgColor, rimColor.withAlphaComponent(0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: from, end: to, options: [])
    context.restoreGState()
}

func path(_ build: (NSBezierPath) -> Void) -> NSBezierPath {
    let p = NSBezierPath()
    build(p)
    p.close()
    return p
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).addClip()

// 배경: 숯빛 그라데이션과 머리 뒤 은은한 빛
NSGradient(starting: color(0x2B2C33), ending: color(0x07070A))!.draw(in: body, angle: -90)
NSGradient(starting: color(0x5C606C, 0.85), ending: color(0x5C606C, 0))!
    .draw(fromCenter: CGPoint(x: 560, y: 600), radius: 0, toCenter: CGPoint(x: 560, y: 600), radius: 420, options: [])

let light = (from: CGPoint(x: 760, y: 860), to: CGPoint(x: 470, y: 520))

// 얼굴 쪽으로 확대: 머리 중심(500, 600)을 아이콘의 (520, 540)에 오게 1.35배
let zoom = NSAffineTransform()
zoom.translateX(by: 520, yBy: 540)
zoom.scale(by: 1.35)
zoom.translateX(by: -500, yBy: -600)
zoom.concat()

// 어깨 (몸도 45도 돌아서 가까운 오른쪽 어깨가 크다)
let shoulders = path { p in
    p.move(to: CGPoint(x: 100, y: 100))
    p.curve(to: CGPoint(x: 410, y: 310), controlPoint1: CGPoint(x: 150, y: 230), controlPoint2: CGPoint(x: 290, y: 300))
    p.line(to: CGPoint(x: 640, y: 320))
    p.curve(to: CGPoint(x: 940, y: 140), controlPoint1: CGPoint(x: 800, y: 330), controlPoint2: CGPoint(x: 910, y: 270))
    p.line(to: CGPoint(x: 940, y: 100))
}
fill(shoulders, ink)
rim(shoulders, width: 14, from: CGPoint(x: 900, y: 380), to: CGPoint(x: 600, y: 150), alpha: 0.6)

// 후드 깃
let hood = path { p in
    p.move(to: CGPoint(x: 430, y: 318))
    p.curve(to: CGPoint(x: 660, y: 326), controlPoint1: CGPoint(x: 500, y: 280), controlPoint2: CGPoint(x: 600, y: 280))
    p.curve(to: CGPoint(x: 430, y: 318), controlPoint1: CGPoint(x: 600, y: 360), controlPoint2: CGPoint(x: 500, y: 356))
}
fill(hood, inkSoft)

// 목 (고개를 숙여 앞으로 기운다)
let neck = path { p in
    p.move(to: CGPoint(x: 420, y: 500))
    p.curve(to: CGPoint(x: 600, y: 540), controlPoint1: CGPoint(x: 480, y: 530), controlPoint2: CGPoint(x: 550, y: 545))
    p.curve(to: CGPoint(x: 650, y: 330), controlPoint1: CGPoint(x: 625, y: 470), controlPoint2: CGPoint(x: 640, y: 400))
    p.line(to: CGPoint(x: 445, y: 330))
    p.curve(to: CGPoint(x: 420, y: 500), controlPoint1: CGPoint(x: 445, y: 400), controlPoint2: CGPoint(x: 430, y: 450))
}
fill(neck, ink)
rim(neck, width: 10, from: CGPoint(x: 660, y: 520), to: CGPoint(x: 580, y: 380), alpha: 0.5)

// 머리 전체를 목 위쪽 기준으로 숙인다 (반시계 방향 회전 = 얼굴이 아래로)
NSGraphicsContext.saveGraphicsState()
let tilt = NSAffineTransform()
tilt.translateX(by: 560, yBy: 480)
tilt.rotate(byDegrees: 20)
tilt.translateX(by: -560, yBy: -480)
tilt.concat()

// 뒷머리 곱슬 (모자 아래로 삐져나옴)
for (x, y, r) in [(640, 560, 46), (660, 620, 44), (612, 505, 40), (585, 470, 30)] as [(CGFloat, CGFloat, CGFloat)] {
    fill(NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), inkSoft)
}

// 머리 (왼쪽을 보는 옆모습, 날카로운 턱)
let head = path { p in
    p.move(to: CGPoint(x: 500, y: 772))
    p.curve(to: CGPoint(x: 668, y: 640), controlPoint1: CGPoint(x: 600, y: 782), controlPoint2: CGPoint(x: 668, y: 720))
    p.curve(to: CGPoint(x: 608, y: 478), controlPoint1: CGPoint(x: 668, y: 565), controlPoint2: CGPoint(x: 645, y: 505))
    p.curve(to: CGPoint(x: 492, y: 452), controlPoint1: CGPoint(x: 570, y: 455), controlPoint2: CGPoint(x: 530, y: 450))
    p.line(to: CGPoint(x: 378, y: 474))
    p.curve(to: CGPoint(x: 362, y: 500), controlPoint1: CGPoint(x: 366, y: 478), controlPoint2: CGPoint(x: 360, y: 488))
    p.curve(to: CGPoint(x: 356, y: 520), controlPoint1: CGPoint(x: 362, y: 508), controlPoint2: CGPoint(x: 354, y: 512))
    p.curve(to: CGPoint(x: 366, y: 548), controlPoint1: CGPoint(x: 360, y: 530), controlPoint2: CGPoint(x: 356, y: 540))
    p.curve(to: CGPoint(x: 338, y: 572), controlPoint1: CGPoint(x: 354, y: 552), controlPoint2: CGPoint(x: 338, y: 560))
    p.curve(to: CGPoint(x: 364, y: 614), controlPoint1: CGPoint(x: 340, y: 588), controlPoint2: CGPoint(x: 358, y: 600))
    p.curve(to: CGPoint(x: 395, y: 700), controlPoint1: CGPoint(x: 366, y: 645), controlPoint2: CGPoint(x: 372, y: 680))
    p.curve(to: CGPoint(x: 500, y: 772), controlPoint1: CGPoint(x: 420, y: 745), controlPoint2: CGPoint(x: 455, y: 768))
}
fill(head, ink)
rim(head, width: 12, from: light.from, to: light.to)

// 턱선과 콧날에 아주 약한 아래쪽 반사광
rim(head, width: 6, from: CGPoint(x: 360, y: 470), to: CGPoint(x: 470, y: 560), alpha: 0.35)

// 헤드셋 밴드: 모자보다 먼저 그려서 모자 밖으로 삐져나오지 않게 한다
let band = NSBezierPath()
band.move(to: CGPoint(x: 598, y: 640))
band.curve(to: CGPoint(x: 470, y: 790), controlPoint1: CGPoint(x: 610, y: 760), controlPoint2: CGPoint(x: 540, y: 800))
band.lineWidth = 30
band.lineCapStyle = .round
inkSoft.setStroke()
band.stroke()

// 모자 (돔): 각진 선으로 날카롭게
let cap = path { p in
    p.move(to: CGPoint(x: 356, y: 690))
    p.line(to: CGPoint(x: 408, y: 790))
    p.curve(to: CGPoint(x: 560, y: 816), controlPoint1: CGPoint(x: 460, y: 812), controlPoint2: CGPoint(x: 515, y: 818))
    p.line(to: CGPoint(x: 694, y: 712))
    p.line(to: CGPoint(x: 700, y: 650))
    p.line(to: CGPoint(x: 356, y: 690))
}
fill(cap, ink)
rim(cap, width: 14, from: CGPoint(x: 700, y: 820), to: CGPoint(x: 480, y: 700))

// 모자 챙: 끝이 뾰족하게 왼쪽 앞으로 뻗음
let bill = path { p in
    p.move(to: CGPoint(x: 440, y: 718))
    p.curve(to: CGPoint(x: 252, y: 646), controlPoint1: CGPoint(x: 360, y: 720), controlPoint2: CGPoint(x: 290, y: 690))
    p.line(to: CGPoint(x: 430, y: 662))
}
fill(bill, ink)
rim(bill, width: 8, from: CGPoint(x: 400, y: 720), to: CGPoint(x: 250, y: 640), alpha: 0.7)

// 이어컵
let cup = NSBezierPath(ovalIn: CGRect(x: 530, y: 470, width: 120, height: 170))
fill(cup, inkSoft)
rim(cup, width: 12, from: CGPoint(x: 660, y: 650), to: CGPoint(x: 560, y: 520))
let cupInner = NSBezierPath(ovalIn: CGRect(x: 556, y: 500, width: 68, height: 110))
fill(cupInner, ink)

// 이어컵의 작은 불빛
NSGraphicsContext.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = color(0xFFFFFF, 0.9)
glow.shadowBlurRadius = 18
glow.set()
fill(NSBezierPath(ovalIn: CGRect(x: 583, y: 548, width: 14, height: 14)), color(0xF2F4F8))
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("ok")
