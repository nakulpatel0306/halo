import HaloKit
import SwiftUI

/// Conversion presets, the way Filee lets each format be tuned.
struct FilesPane: View {
    @ObservedObject var model: AppModel

    private var files: Binding<FileOptions> { $model.settings.files }

    var body: some View {
        PaneScroll(pane: .files) {
            Card(title: "Output") {
                ChoiceRow(symbol: "folder.fill", tint: .blue, title: "Save results",
                          selection: files.output, options: OutputLocation.allCases.map { ($0, $0.title) })
                Divided()
                ToggleRow(symbol: "magnifyingglass", tint: .indigo, title: "Show in Finder when done",
                          detail: "Selects the new files so they're easy to drag somewhere.", isOn: files.revealResult)
            }

            Card(title: "Images", footer: "Originals are never changed; every action writes a new file. Everything runs on macOS's built-in converters.") {
                SliderRow(symbol: "dial.medium.fill", tint: .pink, title: "Quality",
                          detail: "For JPG, HEIC and AVIF. Compress goes lower still.",
                          value: files.imageQuality, range: 0.4...1, step: 0.05) { "\(Int($0 * 100))%" }
                Divided()
                SliderRow(symbol: "arrow.up.left.and.down.right.magnifyingglass", tint: .orange, title: "Resize to",
                          detail: "Longest side for the Resize action.",
                          value: files.resizeLongestSide, range: 320...4096, step: 32) { "\(Int($0)) px" }
                Divided()
                ToggleRow(symbol: "location.slash.fill", tint: .red, title: "Strip location and camera info",
                          detail: "Converted images leave out GPS, camera and date details.", isOn: files.stripMetadata)
            }

            Card(title: "Video & GIF") {
                ChoiceRow(symbol: "film.fill", tint: .indigo, title: "Video size",
                          selection: files.videoQuality, options: VideoQuality.allCases.map { ($0, $0.title) })
                Divided()
                SliderRow(symbol: "speedometer", tint: .purple, title: "GIF frame rate",
                          value: files.gifFPS, range: 5...30, step: 1) { "\(Int($0)) fps" }
                Divided()
                SliderRow(symbol: "arrow.left.and.right", tint: .teal, title: "GIF width",
                          value: files.gifWidth, range: 240...1080, step: 20) { "\(Int($0)) px" }
                Divided()
                SliderRow(symbol: "timer", tint: .green, title: "Longest GIF",
                          detail: "Longer videos are cut here; GIFs get huge fast.",
                          value: files.gifMaxSeconds, range: 3...60, step: 1) { "\(Int($0)) s" }
            }
        }
    }
}
