import HaloKit
import SwiftUI

/// The donut: a translucent band of actions with the hovered one lit in the
/// accent colour, and a disc in the middle that names what's under the pointer.
struct RingView: View {
    @ObservedObject var state: RingState
    let appearance: Appearance

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let outer = size / 2 - RingGeometry.margin
            let inner = outer * RingGeometry.innerRatio
            let count = state.items.count
            let slice = 2 * Double.pi / Double(max(count, 1))
            let labelWidth = RingGeometry.labelWidth(count: count, diameter: size)

            ZStack {
                Donut(thickness: outer - inner + 4)
                    .fill(appearance.backdrop, style: FillStyle(eoFill: true))
                    .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
                    .frame(width: outer * 2, height: outer * 2)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

                ForEach(0..<count, id: \.self) { index in
                    let sector = Sector(inner: inner + 6, outer: outer - 6, start: Double(index) * slice - slice / 2,
                                        end: Double(index) * slice + slice / 2, gap: 6)
                    if state.hovered == index {
                        // Stroking in the fill colour with round joins rounds the corners.
                        sector
                            .fill(appearance.accent.color.gradient)
                            .overlay(sector.stroke(appearance.accent.color.gradient, style: StrokeStyle(lineWidth: 6, lineJoin: .round)))
                            .shadow(color: appearance.accent.color.opacity(0.5), radius: 8)
                    } else {
                        sector.fill(.primary.opacity(0.035))
                    }
                }

                ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                    let angle = Double(index) * slice
                    let radius = (inner + outer) / 2
                    SliceLabel(item: item, highlighted: state.hovered == index, appearance: appearance, width: labelWidth)
                        .position(x: size / 2 + radius * sin(angle), y: size / 2 - radius * cos(angle))
                }

                Circle()
                    .fill(appearance.backdrop)
                    .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
                    .frame(width: (inner - 6) * 2, height: (inner - 6) * 2)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    .overlay(centerContent.frame(width: (inner - 6) * 1.6))
            }
            .frame(width: size, height: size)
        }
        .scaleEffect(state.visible ? 1 : 0.86)
        .opacity(state.visible ? 1 : 0)
    }

    /// The hovered action's name; otherwise what the ring acts on, or a way back
    /// out of a sub-ring.
    @ViewBuilder private var centerContent: some View {
        let scale = appearance.labelScale
        if let hovered = state.hovered, hovered < state.items.count {
            Text(state.items[hovered].title)
                .font(.system(size: 12.5 * scale, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        } else if state.inFolder {
            VStack(spacing: 2) {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 16 * scale))
                    .foregroundStyle(.secondary)
                Text(state.caption)
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } else if appearance.showCaption {
            Text(state.caption)
                .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .truncationMode(.middle)
        }
    }
}
