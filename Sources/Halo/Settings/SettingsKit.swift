import SwiftUI

/// The building blocks every settings pane is made from, so they all share one look.

/// Big title at the top of a pane with a glowing glyph tile.
struct PaneHeader: View {
    let pane: SettingsPane

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: pane.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: pane.tint.opacity(0.45), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(pane.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(pane.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

/// A rounded group of related rows.
struct Card<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Icon chip, title and optional detail, with any control on the right.
struct Row<Accessory: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 7)
    }
}

struct ToggleRow: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Row(symbol: symbol, tint: tint, title: title, detail: detail) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

/// A slider with its current value in a pill, so changes read at a glance.
struct SliderRow: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 2) {
            Row(symbol: symbol, tint: tint, title: title, detail: detail) {
                Text(format(value))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(tint)
            }
            // Snapping in the binding instead of passing `step` avoids a tick
            // mark for every step, which turns into a dotted smear.
            Slider(value: Binding(get: { value }, set: { new in value = step.map { (new / $0).rounded() * $0 } ?? new }), in: range)
            .controlSize(.small)
            .tint(tint)
            .padding(.leading, 40)
            .padding(.bottom, 6)
        }
    }
}

/// A row of pill buttons for picking one of a few options.
struct ChoiceRow<Value: Hashable>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    var detail: String?
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        Row(symbol: symbol, tint: tint, title: title, detail: detail) {
            Chips(selection: $selection, options: options, tint: tint)
        }
    }
}

struct Chips<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, label in
                let on = selection == value
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(on ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.75)))
                    .background(on ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.primary.opacity(0.06)), in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy(duration: 0.18)) { selection = value } }
            }
        }
    }
}

struct Divided: View {
    var body: some View {
        Divider().padding(.leading, 40)
    }
}

/// Scrolling page layout shared by every pane.
struct PaneScroll<Content: View>: View {
    let pane: SettingsPane
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PaneHeader(pane: pane)
                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
