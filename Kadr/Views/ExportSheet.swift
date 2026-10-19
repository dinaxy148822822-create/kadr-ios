import SwiftUI
import Photos

struct ExportSheet: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    private enum Status: Equatable {
        case rendering
        case ready
        case saved
        case failed(String)
    }

    @State private var rendered: UIImage?
    @State private var fileURL: URL?
    @State private var asPNG = false
    @State private var status: Status = .rendering

    private var isTransparent: Bool { model.snapshot.background == .transparent }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Готовое фото")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button("Закрыть") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }

            ZStack {
                if isTransparent { Checkerboard() } else { Theme.surface }
                if let rendered {
                    Image(uiImage: rendered)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

            Picker("Формат", selection: $asPNG) {
                Text("JPEG").tag(false)
                Text("PNG").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(isTransparent || rendered == nil)
            .onChange(of: asPNG) { _, _ in writeFile() }

            if isTransparent {
                Text("У фото прозрачный фон, поэтому оно сохранится как PNG.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await save() }
                } label: {
                    Label(status == .saved ? "Сохранено" : "Сохранить в Фото",
                          systemImage: status == .saved ? "checkmark" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(fileURL == nil || status == .saved)

                if let fileURL {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 52, height: 52)
                            .background(Theme.surfaceRaised, in: Circle())
                    }
                    .accessibilityLabel("Поделиться")
                }
            }

            statusLine

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.bg.ignoresSafeArea())
        .task { await render() }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .rendering:
            Text("Собираю фото в полном размере…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
        case .ready:
            EmptyView()
        case .saved:
            Text("Фото сохранено в вашу галерею.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.success)
        case .failed(let message):
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Work

    @MainActor
    private func render() async {
        status = .rendering
        guard let base = await model.renderFinalBase() else {
            status = .failed("Не получилось собрать фото. Попробуйте ещё раз.")
            return
        }
        let size = CGSize(width: base.width, height: base.height)
        let renderer = ImageRenderer(content: CanvasContent(image: base, layers: model.snapshot.layers, size: size))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.uiImage else {
            status = .failed("Не получилось добавить текст и стикеры к фото.")
            return
        }
        rendered = image
        if isTransparent { asPNG = true }
        writeFile()
        if status == .rendering { status = .ready }
    }

    /// Writes the current image to a temporary file in the chosen format.
    private func writeFile() {
        guard let rendered else { return }
        let png = asPNG || isTransparent
        let data = png ? rendered.pngData() : rendered.jpegData(compressionQuality: 0.92)
        guard let data else {
            status = .failed("Не получилось записать файл.")
            return
        }
        let name = "Kadr-\(Int(Date().timeIntervalSince1970)).\(png ? "png" : "jpg")"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            fileURL = url
            if status == .saved { status = .ready }
        } catch {
            status = .failed("Не получилось записать файл.")
        }
    }

    @MainActor
    private func save() async {
        guard let url = fileURL else { return }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            status = .failed("Нет доступа к галерее. Разрешите добавление фото в Настройках.")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
            }
            status = .saved
        } catch {
            status = .failed("Не получилось сохранить фото.")
        }
    }
}
