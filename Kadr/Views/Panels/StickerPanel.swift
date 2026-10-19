import SwiftUI

struct StickerPanel: View {
    @ObservedObject var model: EditorModel
    @State private var shapeColor: UInt32 = 0xFFB020

    private let emoji: [String] = [
        "😀", "😎", "🥳", "😍", "🤩", "😂", "😇", "😴",
        "🔥", "✨", "⭐", "💫", "❤️", "💛", "💚", "💙",
        "🌈", "☀️", "🌙", "⚡", "🎉", "🎈", "🎁", "🌸",
        "🍀", "🦋", "🐶", "🐱", "🦊", "🐼", "🍕", "🍩",
        "☕", "🎵", "👑", "💎", "🚀", "🌍", "📸", "🏆",
        "💯", "👍", "👏", "🙌"
    ]

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 6) {
                    ForEach(emoji, id: \.self) { symbol in
                        Button {
                            model.addLayer(.emoji(symbol))
                        } label: {
                            Text(symbol)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Стикер \(symbol)")
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 94)

            HStack(spacing: 10) {
                ForEach(ShapeKind.allCases) { kind in
                    Button {
                        model.addLayer(.shape(kind, shapeColor))
                    } label: {
                        StickerShapeView(kind: kind, color: Color(hex: shapeColor))
                            .frame(width: 26, height: 26)
                            .frame(width: 42, height: 38)
                            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Фигура")
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                ColorDots(selected: shapeColor) { hex in
                    shapeColor = hex
                    recolorSelectedShape(hex)
                }
            }
        }
        .padding(.top, 10)
    }

    /// If a shape is selected, the colour dots change that shape too.
    private func recolorSelectedShape(_ hex: UInt32) {
        guard let layer = model.selectedLayer, case .shape(let kind, _) = layer.content else { return }
        model.beginLive()
        model.mutateLayer(layer.id) { $0.content = .shape(kind, hex) }
        model.endLive()
    }
}
