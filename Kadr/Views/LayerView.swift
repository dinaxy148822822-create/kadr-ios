import SwiftUI

// MARK: - Shapes (our own vector stickers)

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.06))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.03, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.maxY - rect.height * 0.08))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.03)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        for i in 0..<10 {
            let angle = -Double.pi / 2 + Double(i) * Double.pi / 5
            let radius = i % 2 == 0 ? outer : inner
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.92))
        p.addCurve(to: pt(0.04, 0.38), control1: pt(0.2, 0.80), control2: pt(0.04, 0.58))
        p.addCurve(to: pt(0.5, 0.22), control1: pt(0.04, 0.12), control2: pt(0.40, 0.04))
        p.addCurve(to: pt(0.96, 0.38), control1: pt(0.60, 0.04), control2: pt(0.96, 0.12))
        p.addCurve(to: pt(0.5, 0.92), control1: pt(0.96, 0.58), control2: pt(0.80, 0.80))
        p.closeSubpath()
        return p
    }
}

struct StickerShapeView: View {
    let kind: ShapeKind
    let color: Color

    var body: some View {
        switch kind {
        case .circle:
            Circle().fill(color)
        case .square:
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color)
        case .triangle:
            TriangleShape().fill(color)
        case .star:
            StarShape().fill(color)
        case .heart:
            HeartShape().fill(color)
        }
    }
}

// MARK: - A single text or sticker

/// Draws one layer. Sizes come from the canvas width, so the same view looks
/// the same on screen and in the full-size export.
struct LayerView: View {
    let layer: Layer
    let canvasWidth: CGFloat

    var body: some View {
        let unit = canvasWidth * layer.scale
        switch layer.content {
        case .text(let text):
            Text(text.string.isEmpty ? " " : text.string)
                .font(.system(size: unit * 0.09,
                              weight: text.bold ? .bold : .regular,
                              design: text.design.design))
                .foregroundStyle(Color(hex: text.color))
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.horizontal, text.pill ? unit * 0.04 : 0)
                .padding(.vertical, text.pill ? unit * 0.015 : 0)
                .background {
                    if text.pill {
                        Capsule().fill(Color(hex: text.color == 0x111111 ? 0xFFFFFF : 0x111111).opacity(0.75))
                    }
                }
        case .emoji(let symbol):
            Text(symbol)
                .font(.system(size: unit * 0.22))
                .fixedSize()
        case .shape(let kind, let hex):
            StickerShapeView(kind: kind, color: Color(hex: hex))
                .frame(width: unit * 0.24, height: unit * 0.24)
        }
    }
}

// MARK: - Canvas

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows {
                for column in 0..<columns {
                    let dark = (row + column) % 2 == 0
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(Color(white: dark ? 0.28 : 0.38)))
                }
            }
        }
    }
}

/// The photo with its text and stickers, drawn at a given size. Used for the
/// export (size in pixels) and for the on-screen canvas.
struct CanvasContent: View {
    let image: CGImage
    let layers: [Layer]
    let size: CGSize
    var showsChecker = false

    var body: some View {
        ZStack {
            if showsChecker { Checkerboard() }
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)
            ForEach(layers) { layer in
                LayerView(layer: layer, canvasWidth: size.width)
                    .rotationEffect(layer.rotation)
                    .position(x: layer.center.x * size.width, y: layer.center.y * size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}
