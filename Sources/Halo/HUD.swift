import AppKit
import SwiftUI

/// A small pill near where the ring was, reporting progress and results.
@MainActor
final class HUD {
    enum Status: Equatable {
        case working(String)
        case success(String)
        case failure(String)
        /// Claude's answer, shown long enough to read.
        case answer(String)
    }

    @MainActor
    final class State: ObservableObject {
        @Published var status: Status = .working("")
    }

    /// Seconds a success message stays up; errors get longer.
    var successDuration = 1.6
    private let state = State()
    private var panel: RingPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ status: Status, at point: NSPoint) {
        state.status = status
        hideWork?.cancel()

        if panel == nil {
            let panel = RingPanel(size: 0)
            panel.ignoresMouseEvents = true
            panel.contentView = NSHostingView(rootView: HUDView(state: state))
            self.panel = panel
        }
        guard let panel, let view = panel.contentView else { return }
        let size = view.fittingSize
        panel.setContentSize(size)
        // Centred on the ring, but kept on the screen when the ring was near an edge
        var origin = NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        if let visible = (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        guard case .working = status else {
            // Errors stay up longer so there's time to read them.
            let delay: Double = switch status {
            case .failure: max(4, successDuration)
            // About 15 characters a second, the pace of a careful read.
            case let .answer(text): min(30, max(5, Double(text.count) / 15))
            default: successDuration
            }
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return
        }
    }

    func update(_ status: Status) {
        guard let panel else { return }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        show(status, at: center)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct HUDView: View {
    @ObservedObject var state: HUD.State

    private var isAnswer: Bool {
        if case .answer = state.status { true } else { false }
    }

    var body: some View {
        HStack(spacing: 8) {
            switch state.status {
            case let .working(text):
                ProgressView().controlSize(.small)
                Text(text)
            case let .success(text):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(text)
            case let .failure(text):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(text)
            case let .answer(text):
                Image(systemName: "sparkle").foregroundStyle(.purple)
                Text(text)
            }
        }
        .font(.system(size: 12.5, weight: .medium))
        .lineLimit(isAnswer ? 16 : 3)
        .frame(maxWidth: 360)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .padding(20)
    }
}
