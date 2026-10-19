import SwiftUI

/// The on-screen canvas: the preview, the layers, and the gestures that move,
/// scale and rotate the selected layer. In crop mode it shows the crop frame instead.
struct CanvasView: View {
    @ObservedObject var model: EditorModel
    let image: CGImage
    let size: CGSize
    let showCrop: Bool

    @State private var dragBase: CGPoint?
    @State private var scaleBase: CGFloat?
    @State private var rotationBase: Angle?

    var body: some View {
        ZStack {
            if model.snapshot.background == .transparent {
                Checkerboard()
            }
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)

            if !showCrop {
                ForEach(model.snapshot.layers) { layer in
                    LayerView(layer: layer, canvasWidth: size.width)
                        .overlay {
                            if layer.id == model.selectedID {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .padding(-6)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectedID = layer.id }
                        .rotationEffect(layer.rotation)
                        .position(x: layer.center.x * size.width, y: layer.center.y * size.height)
                }
            }

            if showCrop {
                CropOverlay(rect: $model.cropDraft, size: size, lockedRatio: model.cropRatio)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if !showCrop { model.selectedID = nil }
        }
        .gesture(dragGesture.simultaneously(with: magnifyGesture).simultaneously(with: rotateGesture))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !showCrop, let id = model.selectedID else { return }
                if dragBase == nil {
                    model.beginLive()
                    dragBase = model.selectedLayer?.center
                }
                guard let base = dragBase, size.width > 0, size.height > 0 else { return }
                let x = min(max(base.x + value.translation.width / size.width, 0), 1)
                let y = min(max(base.y + value.translation.height / size.height, 0), 1)
                model.mutateLayer(id) { $0.center = CGPoint(x: x, y: y) }
            }
            .onEnded { _ in
                dragBase = nil
                model.endLive()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard !showCrop, let id = model.selectedID else { return }
                if scaleBase == nil {
                    model.beginLive()
                    scaleBase = model.selectedLayer?.scale
                }
                guard let base = scaleBase else { return }
                let scale = min(max(base * value.magnification, 0.15), 6)
                model.mutateLayer(id) { $0.scale = scale }
            }
            .onEnded { _ in
                scaleBase = nil
                model.endLive()
            }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard !showCrop, let id = model.selectedID else { return }
                if rotationBase == nil {
                    model.beginLive()
                    rotationBase = model.selectedLayer?.rotation
                }
                guard let base = rotationBase else { return }
                let angle = base + value.rotation
                model.mutateLayer(id) { $0.rotation = angle }
            }
            .onEnded { _ in
                rotationBase = nil
                model.endLive()
            }
    }
}
