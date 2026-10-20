import AppKit
import HaloKit
import SwiftUI
import UniformTypeIdentifiers

/// Per-app rings, like Logitech's Actions Ring: built-in presets plus any app
/// the user adds.
struct AppsPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: PaneSelection

    var body: some View {
        PaneScroll(pane: .apps) {
            Card(footer: "App shortcuts are pressed for you, so Halo needs Accessibility. Presets only cover apps on this Mac; add any other app below.") {
                ToggleRow(symbol: "square.grid.2x2.fill", tint: .cyan, title: "Use app rings",
                          detail: "With nothing selected, the front app's ring replaces the Everywhere ring.",
                          isOn: $model.settings.behavior.appRings)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach($model.settings.profiles) { $profile in
                    ProfileCard(profile: $profile, model: model) {
                        model.openSettings(editing: .profile(profile.id))
                    }
                }
            }
            .opacity(model.settings.behavior.appRings ? 1 : 0.5)

            HStack {
                Button {
                    addApp()
                } label: {
                    Label("Add an App…", systemImage: "plus.app.fill")
                }
                .buttonStyle(.borderedProminent)
                Button("Restore Presets") { model.restorePresets() }
                    .disabled(ProfilePresets.all.allSatisfy { preset in model.settings.profiles.contains { $0.id == preset.id } })
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url, let profile = model.addProfile(forApp: url) else { return }
        model.openSettings(editing: .profile(profile.id))
    }
}

private struct ProfileCard: View {
    @Binding var profile: RingProfile
    @ObservedObject var model: AppModel
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppIcons(bundleIDs: profile.apps, fallback: profile.symbol)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: $profile.enabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            HStack(spacing: 4) {
                ForEach(profile.ring.prefix(8).compactMap(model.settings.info)) { info in
                    Image(systemName: info.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(info.category.color)
                        .frame(width: 24, height: 24)
                        .background(info.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .help(info.title)
                }
                Spacer()
                Button("Edit Ring", action: onEdit)
                    .controlSize(.small)
                Menu {
                    Button("Delete", role: .destructive) {
                        model.settings.profiles.removeAll { $0.id == profile.id }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(14)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .opacity(profile.enabled ? 1 : 0.55)
    }

    private var subtitle: String {
        let apps = profile.apps.compactMap(AppIcons.name).joined(separator: ", ")
        return apps.isEmpty ? "Not installed" : apps
    }
}

/// The first installed app's icon, or the profile's symbol if none is installed.
private struct AppIcons: View {
    let bundleIDs: [String]
    let fallback: String

    static func url(_ id: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
    }

    static func name(_ id: String) -> String? {
        url(id).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    var body: some View {
        if let url = bundleIDs.lazy.compactMap(Self.url).first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 34, height: 34)
        } else {
            Image(systemName: fallback)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}
