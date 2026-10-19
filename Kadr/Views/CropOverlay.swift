import SwiftUI

/// Dimmed frame with four corner handles. Drag a corner to resize, drag inside to move.
struct CropOverlay: View {
    @Binding var rect: CGRect          // fractions of the canvas, origin top-left
    let size: CGSize                   // canvas size on screen
    let lockedRatio: CGFloat?          // width / height in pixels, nil = free

    private enum DragMode {
        case none
        case move
        case corner(Int)               // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
    }

    @State private var start: CGRect?
    @State private var mode: DragMode = .none

    private var frame: CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height,
               width: rect.width * size.width, height: rect.height * size.height)
    }

    var body: some View {
        ZStack {
            Path { p in
                p.addRect(CGRect(origin: .zero, size: size))
                p.addRect(frame)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Rectangle()
                .strokeBorder(Theme.accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            // Rule-of-thirds guides.
            Path { p in
                for i in 1...2 {
                    let x = frame.minX + frame.width * CGFloat(i) / 3
                    let y = frame.minY + frame.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: frame.minY))
                    p.addLine(to: CGPoint(x: x, y: frame.maxY))
                    p.move(to: CGPoint(x: frame.minX, y: y))
                    p.addLine(to: CGPoint(x: frame.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

            ForEach(0..<4, id: \.self) { index in
                let point = corner(index, in: frame)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 22, height: 22)
                    .position(point)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if start == nil {
                        start = rect
                        mode = hitTest(value.startLocation)
                    }
                    if let s = start { update(from: s, translation: value.translation) }
                }
                .onEnded { _ in
                    start = nil
                    mode = .none
                }
        )
    }

    private func corner(_ index: Int, in r: CGRect) -> CGPoint {
        CGPoint(x: (index == 0 || index == 2) ? r.minX : r.maxX,
                y: (index == 0 || index == 1) ? r.minY : r.maxY)
    }

    private func hitTest(_ point: CGPoint) -> DragMode {
        let f = frame
        var best: (index: Int, distance: CGFloat)?
        for index in 0..<4 {
            let c = corner(index, in: f)
            let d = hypot(c.x - point.x, c.y - point.y)
            if d < 40, best == nil || d < best!.distance { best = (index, d) }
        }
        if let best { return .corner(best.index) }
        if f.contains(point) { return .move }
        return .none
    }

    private func update(from s: CGRect, translation t: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        switch mode {
        case .none:
            break
        case .move:
            var r = s
            r.origin.x = min(max(s.minX + t.width / size.width, 0), 1 - s.width)
            r.origin.y = min(max(s.minY + t.height / size.height, 0), 1 - s.height)
            rect = r
        case .corner(let index):
            let fixed = corner((3 - index), in: s)
            let moving = corner(index, in: s)
            let mx = min(max(moving.x + t.width / size.width, 0), 1)
            let my = min(max(moving.y + t.height / size.height, 0), 1)

            var w = abs(mx - fixed.x)
            var h = abs(my - fixed.y)
            let signX: CGFloat = mx >= fixed.x ? 1 : -1
            let signY: CGFloat = my >= fixed.y ? 1 : -1

            if let ratio = lockedRatio {
                let k = size.width / (ratio * size.height)   // height = width * k
                h = w * k
                let maxW = signX > 0 ? 1 - fixed.x : fixed.x
                let maxH = signY > 0 ? 1 - fixed.y : fixed.y
                if w > maxW { w = maxW; h = w * k }
                if h > maxH { h = maxH; w = h / k }
            }
            w = max(w, 0.08)
            h = max(h, 0.08)
            let x = min(max(signX > 0 ? fixed.x : fixed.x - w, 0), 1 - w)
            let y = min(max(signY > 0 ? fixed.y : fixed.y - h, 0), 1 - h)
            rect = CGRect(x: x, y: y, width: w, height: h)
        }
    }
}
