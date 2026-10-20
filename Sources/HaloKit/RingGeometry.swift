import Foundation

/// Maps a pointer offset from the ring's centre to a slice. Slice 0 is centred at
/// 12 o'clock and the rest go clockwise, like a watch face.
public struct RingGeometry: Sendable {
    public let count: Int
    /// Inside this radius nothing is selected, so releasing there cancels.
    public let deadZone: Double

    public init(count: Int, deadZone: Double) {
        self.count = count
        self.deadZone = deadZone
    }

    public var sliceAngle: Double { 2 * .pi / Double(max(count, 1)) }

    /// `dx`/`dy` use screen coordinates where y grows upward (AppKit).
    public func slice(dx: Double, dy: Double) -> Int? {
        guard count > 0, hypot(dx, dy) > deadZone else { return nil }
        // Clockwise angle from straight up, in 0..<2π.
        var angle = atan2(dx, dy)
        if angle < 0 { angle += 2 * .pi }
        let shifted = (angle + sliceAngle / 2).truncatingRemainder(dividingBy: 2 * .pi)
        return Int(shifted / sliceAngle) % count
    }

    /// The ring's proportions, shared by the live ring and the settings editor.
    public static let innerRatio = 0.42
    public static let margin = 8.0

    /// Width a slice label gets: the chord across the slice at mid-band.
    public static func labelWidth(count: Int, diameter: Double) -> Double {
        let outer = diameter / 2 - margin
        let mid = outer * (1 + innerRatio) / 2
        guard count > 2 else { return outer * (1 - innerRatio) * 1.6 }
        return 2 * mid * sin(.pi / Double(count)) - 8
    }

    /// The preferred diameter, grown just enough that every label gets room for
    /// two short lines and the band is thick enough for icon plus text.
    public static func fittingDiameter(count: Int, preferred: Double, labelScale: Double = 1) -> Double {
        let minLabel = 66 * labelScale
        let minBand = 54 * labelScale
        var outer = max(preferred / 2 - margin, minBand / (1 - innerRatio))
        if count > 2 {
            let mid = (minLabel + 8) / (2 * sin(.pi / Double(count)))
            outer = max(outer, mid * 2 / (1 + innerRatio))
        }
        return ((outer + margin) * 2).rounded(.up)
    }

    /// Centre angle of a slice, clockwise from 12 o'clock, in radians.
    public func centerAngle(of index: Int) -> Double {
        Double(index) * sliceAngle
    }
}
