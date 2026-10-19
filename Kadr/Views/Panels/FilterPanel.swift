import SwiftUI

struct FilterPanel: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilterPreset.allCases) { preset in
                        FilterTile(
                            preset: preset,
                            thumbnail: model.thumbnails[preset],
                            selected: model.snapshot.filter == preset
                        ) {
                            model.commit { $0.filter = preset }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if model.snapshot.filter != .none {
                SliderRow(
                    title: "Сила",
                    value: Binding(
                        get: { model.snapshot.filterIntensity },
                        set: { value in model.live { $0.filterIntensity = value } }
                    ),
                    range: 0...1,
                    onEditingChanged: { editing in
                        if editing { model.beginLive() } else { model.endLive() }
                    }
                )
            } else {
                Text("Выберите фильтр, чтобы изменить настроение фото.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .frame(height: 28)
            }
        }
        .padding(.top, 14)
    }
}

struct FilterTile: View {
    let preset: FilterPreset
    let thumbnail: CGImage?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Theme.surfaceRaised
                    if let thumbnail {
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : Theme.border, lineWidth: selected ? 2 : 1)
                )

                Text(preset.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.title)
    }
}
