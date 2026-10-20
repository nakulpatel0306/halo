import HaloKit
import SwiftUI

extension ActionCategory {
    var color: Color {
        switch self {
        case .ai: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .text: .blue
        case .convert: .teal
        case .image: .pink
        case .document: .red
        case .media: .indigo
        case .files: .brown
        case .capture: .green
        case .system: .gray
        case .app: .cyan
        case .custom: .mint
        }
    }

    var symbol: String {
        switch self {
        case .ai: "sparkles"
        case .text: "textformat"
        case .convert: "arrow.triangle.2.circlepath"
        case .image: "photo.fill"
        case .document: "doc.fill"
        case .media: "film.fill"
        case .files: "folder.fill"
        case .capture: "camera.viewfinder"
        case .system: "gearshape.fill"
        case .app: "app.badge.fill"
        case .custom: "wand.and.stars"
        }
    }
}

/// One entry in an open ring.
struct RingItem: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let category: ActionCategory
    let isFolder: Bool

    init(_ info: ActionInfo) {
        id = info.id
        title = info.title
        symbol = info.symbol
        category = info.category
        isFolder = info.isFolder
    }
}

/// Icon and name for one slice, sized to the room the slice actually has so
/// names wrap or shrink instead of being cut off.
struct SliceLabel: View {
    let item: RingItem
    let highlighted: Bool
    let appearance: Appearance
    let width: Double

    var body: some View {
        let scale = appearance.labelScale
        VStack(spacing: 3 * scale) {
            Image(systemName: item.symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 18 * scale, weight: .semibold))
                .frame(height: 21 * scale)
                .foregroundStyle(iconStyle)
                .overlay(alignment: .topTrailing) {
                    if item.isFolder {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 8 * scale, weight: .bold))
                            .foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                            .offset(x: 9 * scale, y: -3 * scale)
                    }
                }
            if appearance.showLabels {
                Text(item.title)
                    .font(.system(size: 10.5 * scale, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(highlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.85)))
            }
        }
        .frame(width: max(width, 40))
        .scaleEffect(highlighted ? 1.07 : 1)
    }

    private var iconStyle: AnyShapeStyle {
        if highlighted { return AnyShapeStyle(.white) }
        return appearance.colorfulIcons ? AnyShapeStyle(item.category.color) : AnyShapeStyle(.primary.opacity(0.85))
    }
}

/// A slice of the ring. Angles run clockwise from 12 o'clock; `gap` trims a
/// fixed distance off each straight edge so slices read as separate pills.
struct Sector: Shape {
    let inner: Double
    let outer: Double
    let start: Double
    let end: Double
    let gap: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        // SwiftUI angles start at 3 o'clock, so shift by a quarter turn.
        let toSwiftUI = { (a: Double) in Angle.radians(a - .pi / 2) }
        let full = end - start >= 2 * .pi - 0.001
        let outerTrim = full ? 0 : gap / 2 / outer
        let innerTrim = full ? 0 : gap / 2 / inner
        var path = Path()
        path.addArc(center: c, radius: outer, startAngle: toSwiftUI(start + outerTrim), endAngle: toSwiftUI(end - outerTrim), clockwise: false)
        path.addArc(center: c, radius: inner, startAngle: toSwiftUI(end - innerTrim), endAngle: toSwiftUI(start + innerTrim), clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// A ring-shaped band, for the backdrop behind the slices.
struct Donut: Shape {
    let thickness: Double

    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect)
        path.addPath(Path(ellipseIn: rect.insetBy(dx: thickness, dy: thickness)))
        return path
    }
}

extension Appearance {
    var backdrop: AnyShapeStyle {
        style == .glass ? AnyShapeStyle(.regularMaterial.opacity(opacity)) : AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(opacity))
    }

    /// The ring's spring, or none when animations are turned all the way down.
    var spring: Animation? {
        motion < 0.05 ? nil : .spring(response: 0.12 + motion * 0.25, dampingFraction: 0.78)
    }
}
