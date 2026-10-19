import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case crop, filters, adjust, text, stickers, cutout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crop: return "Кадр"
        case .filters: return "Фильтры"
        case .adjust: return "Коррекция"
        case .text: return "Текст"
        case .stickers: return "Стикеры"
        case .cutout: return "Фон"
        }
    }

    var icon: String {
        switch self {
        case .crop: return "crop"
        case .filters: return "camera.filters"
        case .adjust: return "slider.horizontal.3"
        case .text: return "textformat"
        case .stickers: return "face.smiling"
        case .cutout: return "scissors"
        }
    }
}

func fitSize(_ size: CGSize, in box: CGSize) -> CGSize {
    guard size.width > 0, size.height > 0, box.width > 0, box.height > 0 else { return .zero }
    let scale = min(box.width / size.width, box.height / size.height)
    return CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    var onClose: () -> Void

    @State private var tool: Tool = .filters
    @State private var showExport = false
    @State private var confirmClose = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvasArea
            if model.selectedLayer != nil && (tool == .text || tool == .stickers) {
                LayerActions(model: model)
            }
            panel
                .frame(height: 176)
                .frame(maxWidth: .infinity)
                .background(Theme.surface)
            toolBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) { noticeBanner }
        .onChange(of: tool) { oldValue, newValue in
            if newValue == .crop { model.beginCropEditing() }
            if oldValue == .crop { model.cancelCropEditing() }
        }
        .onChange(of: model.notice) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                model.notice = nil
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(model: model)
        }
        .confirmationDialog("Закрыть без сохранения?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Закрыть", role: .destructive) { onClose() }
            Button("Продолжить редактирование", role: .cancel) {}
        }
    }

    // MARK: - Parts

    private var topBar: some View {
        HStack(spacing: 4) {
            IconButton(system: "xmark", label: "Закрыть") {
                if model.canUndo { confirmClose = true } else { onClose() }
            }
            Spacer()
            IconButton(system: "arrow.uturn.backward", label: "Отменить", enabled: model.canUndo) { model.undo() }
            IconButton(system: "arrow.uturn.forward", label: "Повторить", enabled: model.canRedo) { model.redo() }
            Spacer()
            Button("Готово") {
                model.selectedID = nil
                showExport = true
            }
            .buttonStyle(PrimaryButtonStyle(compact: true))
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
    }

    private var canvasArea: some View {
        GeometryReader { geo in
            ZStack {
                if let image = model.preview {
                    let fitted = fitSize(CGSize(width: image.width, height: image.height),
                                         in: CGSize(width: geo.size.width - 24, height: geo.size.height - 16))
                    CanvasView(model: model, image: image, size: fitted, showCrop: tool == .crop)
                        .frame(width: fitted.width, height: fitted.height)
                } else {
                    ProgressView()
                }
                if model.isBusy {
                    ZStack {
                        Color.black.opacity(0.45)
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Вырезаю объект…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private var panel: some View {
        switch tool {
        case .crop: CropPanel(model: model, onApplied: { tool = .filters })
        case .filters: FilterPanel(model: model)
        case .adjust: AdjustPanel(model: model)
        case .text: TextPanel(model: model)
        case .stickers: StickerPanel(model: model)
        case .cutout: CutoutPanel(model: model)
        }
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            ForEach(Tool.allCases) { item in
                Button { tool = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .regular))
                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(tool == item ? Theme.accent : Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(.horizontal, 4)
        .background(Theme.bg)
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let text = model.notice {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.surfaceRaised, in: Capsule())
                .padding(.top, 60)
                .transition(.opacity)
        }
    }
}

/// Duplicate, delete and bring to front for the selected text or sticker.
struct LayerActions: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            IconButton(system: "plus.square.on.square", label: "Дублировать") { model.duplicateSelected() }
            IconButton(system: "arrow.up.to.line", label: "На передний план") { model.bringSelectedToFront() }
            IconButton(system: "trash", label: "Удалить") { model.deleteSelected() }
            Spacer()
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }
}
