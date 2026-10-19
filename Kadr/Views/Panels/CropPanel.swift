import SwiftUI

struct CropPanel: View {
    @ObservedObject var model: EditorModel
    var onApplied: () -> Void

    private let presets: [(title: String, ratio: CGFloat?)] = [
        ("Свободно", nil),
        ("1:1", 1),
        ("4:5", 4.0 / 5.0),
        ("3:4", 3.0 / 4.0),
        ("16:9", 16.0 / 9.0),
        ("9:16", 9.0 / 16.0)
    ]

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets.indices, id: \.self) { index in
                        let preset = presets[index]
                        Chip(title: preset.title, selected: model.cropRatio == preset.ratio) {
                            model.setCropRatio(preset.ratio)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Button { model.rotateRight() } label: {
                    Label("Повернуть", systemImage: "rotate.right")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button { model.flipHorizontally() } label: {
                    Label("Отразить", systemImage: "arrow.left.and.right")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button("Применить") {
                model.applyCrop()
                onApplied()
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .padding(.top, 14)
    }
}
