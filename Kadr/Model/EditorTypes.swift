import SwiftUI
import CoreGraphics

// MARK: - Text

enum TextDesign: String, CaseIterable, Identifiable, Equatable {
    case standard, rounded, serif, mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Обычный"
        case .rounded: return "Круглый"
        case .serif: return "С засечками"
        case .mono: return "Моно"
        }
    }

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
}

struct TextContent: Equatable {
    var string: String = "Текст"
    var design: TextDesign = .rounded
    var color: UInt32 = 0xFFFFFF
    var bold: Bool = true
    var pill: Bool = false
}

// MARK: - Stickers and layers

enum ShapeKind: String, CaseIterable, Identifiable, Equatable {
    case circle, square, triangle, star, heart

    var id: String { rawValue }
}

enum LayerContent: Equatable {
    case text(TextContent)
    case emoji(String)
    case shape(ShapeKind, UInt32)
}

/// A text or sticker on the canvas. Position is a fraction of the canvas,
/// size is a fraction of the canvas width, so screen and export match.
struct Layer: Identifiable, Equatable {
    let id: UUID
    var content: LayerContent
    var center: CGPoint
    var scale: CGFloat
    var rotation: Angle

    init(content: LayerContent,
         center: CGPoint = CGPoint(x: 0.5, y: 0.5),
         scale: CGFloat = 1,
         rotation: Angle = .zero) {
        self.id = UUID()
        self.content = content
        self.center = center
        self.scale = scale
        self.rotation = rotation
    }
}

// MARK: - Photo edits

struct TransformState: Equatable {
    /// Clockwise quarter turns, 0...3. Applied before the flip.
    var quarterTurns: Int = 0
    var flipH: Bool = false
    /// Crop in the rotated, flipped image. Fractions, origin top-left.
    var crop: CGRect = EditorSnapshot.fullCrop
}

struct Adjustments: Equatable {
    var brightness: Double = 0   // -1...1
    var contrast: Double = 0     // -1...1
    var saturation: Double = 0   // -1...1
    var warmth: Double = 0       // -1...1
    var highlights: Double = 0   // 0...1, how much to tame bright areas
    var shadows: Double = 0      // -1...1
    var sharpness: Double = 0    // 0...1
    var vignette: Double = 0     // 0...1
    var blur: Double = 0         // 0...1
}

enum AdjustKey: String, CaseIterable, Identifiable {
    case brightness, contrast, saturation, warmth, highlights, shadows, sharpness, vignette, blur

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brightness: return "Яркость"
        case .contrast: return "Контраст"
        case .saturation: return "Насыщенность"
        case .warmth: return "Теплота"
        case .highlights: return "Света"
        case .shadows: return "Тени"
        case .sharpness: return "Резкость"
        case .vignette: return "Виньетка"
        case .blur: return "Размытие"
        }
    }

    var keyPath: WritableKeyPath<Adjustments, Double> {
        switch self {
        case .brightness: return \.brightness
        case .contrast: return \.contrast
        case .saturation: return \.saturation
        case .warmth: return \.warmth
        case .highlights: return \.highlights
        case .shadows: return \.shadows
        case .sharpness: return \.sharpness
        case .vignette: return \.vignette
        case .blur: return \.blur
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .brightness, .contrast, .saturation, .warmth, .shadows: return -1...1
        case .highlights, .sharpness, .vignette, .blur: return 0...1
        }
    }
}

enum FilterPreset: String, CaseIterable, Identifiable, Hashable {
    case none, vivid, chrome, fade, instant, process, transfer, mono, noir, tonal, sepia, cool, warm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Оригинал"
        case .vivid: return "Яркий"
        case .chrome: return "Хром"
        case .fade: return "Выцвет"
        case .instant: return "Мгновенный"
        case .process: return "Процесс"
        case .transfer: return "Плёнка"
        case .mono: return "Моно"
        case .noir: return "Нуар"
        case .tonal: return "Тональный"
        case .sepia: return "Сепия"
        case .cool: return "Холод"
        case .warm: return "Тепло"
        }
    }
}

enum BackgroundMode: Equatable {
    case original
    case transparent
    case color(UInt32)
    case blur
}

/// Everything needed to redraw the edit. Undo and redo are stacks of these.
struct EditorSnapshot: Equatable {
    static let fullCrop = CGRect(x: 0, y: 0, width: 1, height: 1)

    var transform = TransformState()
    var adjustments = Adjustments()
    var filter: FilterPreset = .none
    var filterIntensity: Double = 1
    var background: BackgroundMode = .original
    var layers: [Layer] = []

    /// True when the photo itself (not the layers on top) looks the same.
    func sameImage(as other: EditorSnapshot) -> Bool {
        transform == other.transform
            && adjustments == other.adjustments
            && filter == other.filter
            && filterIntensity == other.filterIntensity
            && background == other.background
    }
}
