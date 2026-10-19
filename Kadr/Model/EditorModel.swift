import SwiftUI
import CoreImage
import Combine

/// The state of one editing session: the photo, the edit, undo and redo.
final class EditorModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var snapshot = EditorSnapshot()
    @Published var selectedID: UUID?
    @Published private(set) var preview: CGImage?
    @Published private(set) var thumbnails: [FilterPreset: CGImage] = [:]
    @Published private(set) var isBusy = false
    @Published private(set) var hasCutout = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var notice: String?

    // Crop editing: while on, the preview shows the whole photo and the
    // overlay edits `cropDraft`.
    @Published private(set) var cropEditing = false
    @Published var cropDraft = EditorSnapshot.fullCrop
    @Published var cropRatio: CGFloat?

    private let fullSource: CIImage
    private let previewSource: CIImage
    private let thumbSource: CIImage
    private var fullMask: CIImage?

    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []
    private var liveActive = false
    private var renderToken = 0
    private let renderQueue = DispatchQueue(label: "app.kadr.render", qos: .userInitiated)

    init?(data: Data) {
        guard let full = ImageLoader.load(data: data, maxSide: 4096),
              let small = ImageLoader.load(data: data, maxSide: 1600),
              let thumb = ImageLoader.load(data: data, maxSide: 160) else { return nil }
        fullSource = CIImage(cgImage: full)
        previewSource = CIImage(cgImage: small)
        thumbSource = CIImage(cgImage: thumb)
        scheduleRender()
        scheduleThumbnails()
    }

    // MARK: - Undo and redo

    /// Starts a change that may take many steps (a slider drag, a gesture).
    /// Saves the current state once; the whole drag becomes one undo step.
    func beginLive() {
        guard !liveActive else { return }
        liveActive = true
        undoStack.append(snapshot)
        redoStack.removeAll()
        refreshUndoFlags()
    }

    func endLive() {
        guard liveActive else { return }
        liveActive = false
        if undoStack.last == snapshot { undoStack.removeLast() }
        refreshUndoFlags()
    }

    /// Applies a change without adding an undo step. Wrap it in beginLive/endLive.
    func live(_ change: (inout EditorSnapshot) -> Void) {
        var next = snapshot
        change(&next)
        guard next != snapshot else { return }
        let imageChanged = !next.sameImage(as: snapshot)
        snapshot = next
        if imageChanged { scheduleRender() }
    }

    /// A one-step change, e.g. choosing a filter.
    func commit(_ change: (inout EditorSnapshot) -> Void) {
        beginLive()
        live(change)
        endLive()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        restore(next)
    }

    private func restore(_ state: EditorSnapshot) {
        let imageChanged = !state.sameImage(as: snapshot)
        snapshot = state
        liveActive = false
        refreshUndoFlags()
        if imageChanged { scheduleRender() }
    }

    private func refreshUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - Layers

    var selectedLayer: Layer? {
        guard let id = selectedID else { return nil }
        return snapshot.layers.first { $0.id == id }
    }

    func addLayer(_ content: LayerContent) {
        let layer = Layer(content: content)
        commit { $0.layers.append(layer) }
        selectedID = layer.id
    }

    func mutateLayer(_ id: UUID, _ change: (inout Layer) -> Void) {
        live { snap in
            guard let index = snap.layers.firstIndex(where: { $0.id == id }) else { return }
            change(&snap.layers[index])
        }
    }

    func updateText(_ id: UUID, _ change: (inout TextContent) -> Void) {
        mutateLayer(id) { layer in
            if case .text(var text) = layer.content {
                change(&text)
                layer.content = .text(text)
            }
        }
    }

    func commitText(_ id: UUID, _ change: (inout TextContent) -> Void) {
        beginLive()
        updateText(id, change)
        endLive()
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        commit { $0.layers.removeAll { $0.id == id } }
        selectedID = nil
    }

    func duplicateSelected() {
        guard let layer = selectedLayer else { return }
        var copy = Layer(content: layer.content,
                         center: CGPoint(x: min(layer.center.x + 0.06, 0.95),
                                         y: min(layer.center.y + 0.06, 0.95)),
                         scale: layer.scale,
                         rotation: layer.rotation)
        copy.scale = layer.scale
        commit { $0.layers.append(copy) }
        selectedID = copy.id
    }

    func bringSelectedToFront() {
        guard let id = selectedID else { return }
        commit { snap in
            guard let index = snap.layers.firstIndex(where: { $0.id == id }) else { return }
            let layer = snap.layers.remove(at: index)
            snap.layers.append(layer)
        }
    }

    // MARK: - Crop, rotate, flip

    func beginCropEditing() {
        cropEditing = true
        cropDraft = snapshot.transform.crop
        cropRatio = nil
        scheduleRender()
    }

    func cancelCropEditing() {
        guard cropEditing else { return }
        cropEditing = false
        scheduleRender()
    }

    func applyCrop() {
        guard cropEditing else { return }
        cropEditing = false
        let draft = cropDraft
        commit { $0.transform.crop = draft }
        scheduleRender()
    }

    func setCropRatio(_ ratio: CGFloat?) {
        cropRatio = ratio
        guard let ratio, let image = preview, image.height > 0 else { return }
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        var w: CGFloat
        var h: CGFloat
        if ratio >= aspect {
            w = 1
            h = aspect / ratio
        } else {
            h = 1
            w = ratio / aspect
        }
        w *= 0.9
        h *= 0.9
        cropDraft = CGRect(x: (1 - w) / 2, y: (1 - h) / 2, width: w, height: h)
    }

    func rotateRight() {
        commit {
            $0.transform.quarterTurns = ($0.transform.quarterTurns + 1) % 4
            $0.transform.crop = EditorSnapshot.fullCrop
        }
        cropDraft = EditorSnapshot.fullCrop
        cropRatio = nil
    }

    func flipHorizontally() {
        commit {
            $0.transform.flipH.toggle()
            $0.transform.crop = EditorSnapshot.fullCrop
        }
        cropDraft = EditorSnapshot.fullCrop
        cropRatio = nil
    }

    // MARK: - Background removal

    func removeBackground() {
        if fullMask != nil {
            commit { $0.background = .transparent }
            return
        }
        isBusy = true
        let source = fullSource
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<CIImage, Error>
            do {
                result = .success(try Cutout.makeMask(for: source))
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success(let mask):
                    self.fullMask = mask
                    self.hasCutout = true
                    self.commit { $0.background = .transparent }
                case .failure:
                    self.notice = "Не нашлось объекта на фото. Попробуйте другое."
                }
            }
        }
    }

    // MARK: - Rendering

    private func makeRecipe() -> Recipe {
        var snap = snapshot
        if cropEditing { snap.transform.crop = EditorSnapshot.fullCrop }
        return Recipe(snapshot: snap, mask: fullMask)
    }

    /// Redraws the preview in the background. If a newer request arrives first,
    /// the older result is dropped.
    private func scheduleRender() {
        renderToken &+= 1
        let token = renderToken
        let source = previewSource
        let recipe = makeRecipe()
        renderQueue.async { [weak self] in
            let image = ImagePipeline.render(source: source, recipe: recipe)
            DispatchQueue.main.async {
                guard let self, self.renderToken == token, let image else { return }
                self.preview = image
            }
        }
    }

    private func scheduleThumbnails() {
        let source = thumbSource
        renderQueue.async { [weak self] in
            var result: [FilterPreset: CGImage] = [:]
            for preset in FilterPreset.allCases {
                var snap = EditorSnapshot()
                snap.filter = preset
                if let image = ImagePipeline.render(source: source, recipe: Recipe(snapshot: snap, mask: nil)) {
                    result[preset] = image
                }
            }
            DispatchQueue.main.async { self?.thumbnails = result }
        }
    }

    /// The edited photo at full size (up to 4096 px), without text and stickers.
    func renderFinalBase() async -> CGImage? {
        let source = fullSource
        let recipe = Recipe(snapshot: snapshot, mask: fullMask)
        return await withCheckedContinuation { (continuation: CheckedContinuation<CGImage?, Never>) in
            renderQueue.async {
                continuation.resume(returning: ImagePipeline.render(source: source, recipe: recipe))
            }
        }
    }
}
