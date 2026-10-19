import SwiftUI
import PhotosUI

struct HomeView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var editor: EditorModel?
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                LogoMark()
                    .frame(width: 112, height: 112)

                Text("Кадр")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)

                Text("Фильтры, текст, стикеры и вырезание фона. Всё работает прямо на телефоне.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(loading ? "Открываю…" : "Выбрать фото")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 28)
                        .frame(height: 52)
                        .background(Theme.accent, in: Capsule())
                }
                .disabled(loading)
                .padding(.top, 12)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.danger)
                }

                Spacer()
                Spacer()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await open(item) }
        }
        .fullScreenCover(item: $editor) { model in
            EditorView(model: model, onClose: { editor = nil })
        }
    }

    @MainActor
    private func open(_ item: PhotosPickerItem) async {
        loading = true
        errorText = nil
        defer {
            loading = false
            pickerItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let model = EditorModel(data: data) else {
            errorText = "Не получилось открыть это фото. Попробуйте другое."
            return
        }
        editor = model
    }
}

/// Four corner brackets and a dot, drawn in code (the app's own mark).
struct LogoMark: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let inset = s * 0.12
            let arm = s * 0.26
            let line = StrokeStyle(lineWidth: s * 0.07, lineCap: .round, lineJoin: .round)

            func bracket(_ corner: CGPoint, _ dx: CGFloat, _ dy: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
                p.addLine(to: corner)
                p.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
                return p
            }

            let left = inset, right = s - inset, top = inset, bottom = s - inset
            context.stroke(bracket(CGPoint(x: left, y: top), 1, 1), with: .color(Theme.accent), style: line)
            context.stroke(bracket(CGPoint(x: right, y: top), -1, 1), with: .color(Theme.accent), style: line)
            context.stroke(bracket(CGPoint(x: left, y: bottom), 1, -1), with: .color(Theme.accent), style: line)
            context.stroke(bracket(CGPoint(x: right, y: bottom), -1, -1), with: .color(Theme.accent), style: line)

            let center = CGPoint(x: s / 2, y: s / 2)
            let ring = Path(ellipseIn: CGRect(x: center.x - s * 0.1, y: center.y - s * 0.1, width: s * 0.2, height: s * 0.2))
            context.stroke(ring, with: .color(Theme.accent2), lineWidth: s * 0.022)
            let dot = Path(ellipseIn: CGRect(x: center.x - s * 0.058, y: center.y - s * 0.058, width: s * 0.116, height: s * 0.116))
            context.fill(dot, with: .color(Theme.accent))
        }
        .accessibilityHidden(true)
    }
}
