import HaloKit
import SwiftUI

struct AppearancePane: View {
    @ObservedObject var model: AppModel

    private var appearance: Binding<Appearance> { $model.settings.appearance }

    var body: some View {
        PaneScroll(pane: .appearance) {
            HStack {
                Spacer()
                RingPreview(items: model.items(for: .text(""), target: .kind(.text)), appearance: model.settings.appearance, caption: "12 words")
                    .animation(.snappy, value: model.settings.appearance)
                Spacer()
            }
            .frame(minHeight: 300)
            .padding(.vertical, 8)
            .background(
                RadialGradient(colors: [model.settings.appearance.accent.color.opacity(0.18), .clear], center: .center, startRadius: 20, endRadius: 260)
            )

            Card(title: "Color") {
                Row(symbol: "paintpalette.fill", tint: model.settings.appearance.accent.color, title: "Accent") {
                    HStack(spacing: 7) {
                        ForEach(Accent.allCases) { accent in
                            Circle()
                                .fill(accent.color.gradient)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    if appearance.wrappedValue.accent == accent {
                                        Circle().strokeBorder(.white, lineWidth: 2.5).padding(1)
                                    }
                                }
                                .shadow(color: accent.color.opacity(0.4), radius: 3)
                                .contentShape(Circle())
                                .onTapGesture { appearance.wrappedValue.accent = accent }
                                .help(accent.rawValue.capitalized)
                        }
                    }
                }
                Divided()
                ToggleRow(symbol: "swatchpalette.fill", tint: .orange, title: "Colorful icons",
                          detail: "Tint icons by kind: Claude, image, convert and so on.", isOn: appearance.colorfulIcons)
                Divided()
                ChoiceRow(symbol: "circle.lefthalf.filled", tint: .gray, title: "Theme",
                          selection: appearance.theme, options: RingTheme.allCases.map { ($0, $0.title) })
                Divided()
                ChoiceRow(symbol: "square.stack.3d.down.forward.fill", tint: .blue, title: "Material",
                          selection: appearance.style, options: RingStyle.allCases.map { ($0, $0.title) })
                Divided()
                SliderRow(symbol: "drop.fill", tint: .cyan, title: "Opacity",
                          value: appearance.opacity, range: 0.5...1, step: 0.05) { "\(Int($0 * 100))%" }
            }

            Card(title: "Size", footer: "The ring grows on its own when it holds more actions, so names always fit.") {
                SliderRow(symbol: "circle.circle", tint: .purple, title: "Ring size",
                          value: appearance.diameter, range: 240...420, step: 10) { "\(Int($0)) pt" }
                Divided()
                SliderRow(symbol: "textformat.size", tint: .pink, title: "Icon and text size",
                          value: appearance.labelScale, range: 0.85...1.35, step: 0.05) { "\(Int($0 * 100))%" }
                Divided()
                ToggleRow(symbol: "character.textbox", tint: .green, title: "Action names", isOn: appearance.showLabels)
                Divided()
                ToggleRow(symbol: "text.below.photo.fill", tint: .teal, title: "Caption in the middle",
                          detail: "The file name or word count of what you selected.", isOn: appearance.showCaption)
            }

            Card(title: "Motion") {
                SliderRow(symbol: "wind", tint: .indigo, title: "Animation",
                          detail: "All the way left turns animations off.",
                          value: appearance.motion, range: 0...1, step: 0.05) {
                    $0 < 0.05 ? "Off" : $0 < 0.4 ? "Snappy" : $0 < 0.75 ? "Smooth" : "Relaxed"
                }
            }
        }
    }
}
