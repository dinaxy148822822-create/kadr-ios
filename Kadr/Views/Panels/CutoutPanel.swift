import SwiftUI

struct CutoutPanel: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 14) {
            if model.hasCutout {
                Text("Фон")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "Оригинал", selected: model.snapshot.background == .original) {
                            model.commit { $0.background = .original }
                        }
                        Chip(title: "Прозрачный", selected: model.snapshot.background == .transparent) {
                            model.commit { $0.background = .transparent }
                        }
                        Chip(title: "Размытый", selected: model.snapshot.background == .blur) {
                            model.commit { $0.background = .blur }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    ColorDots(selected: selectedColor) { hex in
                        model.commit { $0.background = .color(hex) }
                    }
                }
            } else {
                Text("Найдём главный объект на фото и уберём фон. Всё происходит на телефоне.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    model.removeBackground()
                } label: {
                    Label("Убрать фон", systemImage: "scissors")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(model.isBusy)
            }
        }
        .padding(.top, 14)
    }

    private var selectedColor: UInt32? {
        if case .color(let hex) = model.snapshot.background { return hex }
        return nil
    }
}
