import SwiftUI

struct AdjustPanel: View {
    @ObservedObject var model: EditorModel
    @State private var key: AdjustKey = .brightness

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AdjustKey.allCases) { item in
                        Chip(title: item.title, selected: key == item) { key = item }
                    }
                }
                .padding(.horizontal, 16)
            }

            SliderRow(
                title: key.title,
                value: Binding(
                    get: { model.snapshot.adjustments[keyPath: key.keyPath] },
                    set: { value in
                        let path = key.keyPath
                        model.live { $0.adjustments[keyPath: path] = value }
                    }
                ),
                range: key.range,
                onEditingChanged: { editing in
                    if editing { model.beginLive() } else { model.endLive() }
                }
            )

            Button("Сбросить всё") {
                model.commit { $0.adjustments = Adjustments() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.snapshot.adjustments == Adjustments())
        }
        .padding(.top, 14)
    }
}
