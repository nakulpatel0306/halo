import AppKit
import HaloKit
import SwiftUI

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--demo-ring"), index + 1 < args.count {
            let name = args[index + 1]
            let target: RingTarget = RingKind(rawValue: name).map { .kind($0) } ?? .profile(name)
            let folder = args.firstIndex(of: "--folder").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
            model.ring.demo(target, folder: folder)
        } else if let index = args.firstIndex(of: "--settings"), index + 1 < args.count {
            model.openSettings(SettingsPane(rawValue: args[index + 1]))
        } else if !Permissions.accessibility {
            model.openSettings(.guide)
        }
        if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
            snapshot(to: URL(fileURLWithPath: args[index + 1]))
        }
    }

    /// Saves Halo's front window as a PNG and quits, for checking layouts. Draws
    /// the window itself, so it needs no Screen Recording permission.
    private func snapshot(to url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let window = NSApp.windows.filter(\.isVisible).max { $0.frame.width < $1.frame.width }
            // Rendering the layer tree also captures scroll views, which cacheDisplay leaves blank.
            if let window, let view = window.contentView?.superview, let layer = view.layer {
                let scale = window.backingScaleFactor
                let size = view.bounds.size
                if let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                                       bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    ctx.scaleBy(x: scale, y: scale)
                    layer.render(in: ctx)
                    if let image = ctx.makeImage() {
                        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
                    }
                }
            }
            NSApp.terminate(nil)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Show Ring") { model.ring.showFromMenu() }
        Text("Hold \(model.settings.shortcut.display) anywhere")
        if model.keepingAwake {
            Button("Stop Keeping Awake") { model.keepingAwake = SystemActions.toggleKeepAwake() }
        }
        Divider()
        Button("How to Use Halo…") { model.openSettings(.guide) }
        Button("Edit Rings…") { model.openSettings(.rings) }
        if !Permissions.accessibility {
            Button("Allow Accessibility…") { model.openSettings(.permissions) }
        }
        Button("Settings…") { model.openSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Halo") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// The menu bar version of the logo: a template image, so macOS tints it to
/// match the menu bar. The lit slice is solid and the rest are faint.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let outer = 8.5, inner = 4.6, gap = 1.1
            for i in 0..<8 {
                // AppKit angles run counter-clockwise from 3 o'clock; slice 0 sits at 12.
                let mid = 90 - Double(i) * 45
                let path = NSBezierPath()
                path.appendArc(withCenter: c, radius: outer, startAngle: mid - 22.5 + gap / outer * 180 / .pi,
                               endAngle: mid + 22.5 - gap / outer * 180 / .pi)
                path.appendArc(withCenter: c, radius: inner, startAngle: mid + 22.5 - gap / inner * 180 / .pi,
                               endAngle: mid - 22.5 + gap / inner * 180 / .pi, clockwise: true)
                path.close()
                NSColor.black.withAlphaComponent(i == 0 ? 1 : 0.45).setFill()
                path.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
