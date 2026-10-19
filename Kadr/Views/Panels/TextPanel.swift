import SwiftUI

struct TextPanel: View {
    @ObservedObject var model: EditorModel
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    model.addLayer(.text(TextContent()))
                } label: {
                    Label("Добавить текст", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 16)

                if let layer = model.selectedLayer, case .text(let text) = layer.content {
                    editor(for: layer.id, text: text)
                } else {
                    Text("Нажмите на текст на фото, чтобы изменить его.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { model.endLive() }
        }
    }

    @ViewBuilder
    private func editor(for id: UUID, text: TextContent) -> some View {
        TextField("Введите текст", text: Binding(
            get: { text.string },
            set: { value in
                model.beginLive()
                model.updateText(id) { $0.string = value }
            }
        ))
        .focused($focused)
        .font(.system(size: 16))
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextDesign.allCases) { design in
                    Chip(title: design.title, selected: text.design == design) {
                        model.commitText(id) { $0.design = design }
                    }
                }
                Chip(title: "Жирный", selected: text.bold) {
                    model.commitText(id) { $0.bold.toggle() }
                }
                Chip(title: "Плашка", selected: text.pill) {
                    model.commitText(id) { $0.pill.toggle() }
                }
            }
            .padding(.horizontal, 16)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            ColorDots(selected: text.color) { hex in
                model.commitText(id) { $0.color = hex }
            }
        }
    }
}
