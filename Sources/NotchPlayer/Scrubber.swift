import SwiftUI

// 평소에는 얇은 바, 마우스를 올리거나 끄는 동안에는 조금 굵어지고 진해진다
struct Scrubber: View {
    let value: Double
    let total: Double
    let onSeek: (Double) -> Void

    @State private var isHovering = false

    // 끄는 동안에는 끌고 있는 위치를 보여주고, 놓을 때 한 번만 앱에 보낸다
    @State private var dragValue: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let shown = dragValue ?? value
            let fraction = total > 0 ? min(max(shown / total, 0), 1) : 0
            let isActive = isHovering || dragValue != nil

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))

                Capsule()
                    .fill(.white.opacity(isActive ? 1 : 0.6))
                    .frame(width: width * fraction)
            }
            .frame(height: isActive ? 5 : 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragValue = seconds(at: drag.location.x, width: width)
                    }
                    .onEnded { drag in
                        onSeek(seconds(at: drag.location.x, width: width))
                        dragValue = nil
                    }
            )
        }
        .frame(height: 16)
    }

    private func seconds(at x: CGFloat, width: CGFloat) -> Double {
        let fraction = min(max(x / width, 0), 1)

        return fraction * total
    }
}
