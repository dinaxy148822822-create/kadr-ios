import SwiftUI

/// Colour roles from replica/design/tokens.json. Components use these, never raw hex.
enum Theme {
    static let bg = Color(hex: 0x0F1115)
    static let surface = Color(hex: 0x1A1D24)
    static let surfaceRaised = Color(hex: 0x242833)
    static let border = Color(hex: 0x2E3340)
    static let text = Color(hex: 0xF4F5F7)
    static let textMuted = Color(hex: 0xA8AEBB)
    static let accent = Color(hex: 0xFFB020)
    static let onAccent = Color(hex: 0x1A1205)
    static let accent2 = Color(hex: 0x2DD4BF)
    static let danger = Color(hex: 0xFF6B6B)
    static let success = Color(hex: 0x34D399)

    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 18

    /// Colours offered for text, shapes and backgrounds.
    static let palette: [UInt32] = [
        0xFFFFFF, 0x111111, 0xFFB020, 0xFF5A5F, 0xFF7AB8,
        0x2DD4BF, 0x4C8DFF, 0x34D399, 0xA78BFA
    ]
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 15 : 17, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, compact ? 16 : 28)
            .frame(height: compact ? 36 : 52)
            .background(Theme.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Theme.surfaceRaised, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? Theme.onAccent : Theme.text)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selected ? Theme.accent : Theme.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ColorDots: View {
    let selected: UInt32?
    let action: (UInt32) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Theme.palette, id: \.self) { hex in
                Button { action(hex) } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.accent, lineWidth: 2.5)
                                .padding(-4)
                                .opacity(selected == hex ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct IconButton: View {
    let system: String
    let label: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Theme.text : Theme.textMuted.opacity(0.4))
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 96, alignment: .leading)
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            Text("\(Int((value * 100).rounded()))")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.text)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }
}
