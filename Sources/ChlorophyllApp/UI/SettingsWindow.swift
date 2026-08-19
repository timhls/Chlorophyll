import AppKit
import ChlorophyllCore
import SwiftUI

/// The app settings window (SwiftUI content in an AppKit window).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func toggle(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSWindowController()
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                         styleMask: [.titled, .closable],
                         backing: .buffered,
                         defer: false)
        w.title = "Chlorophyll Settings"
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.contentView = NSHostingView(rootView: SettingsView().environmentObject(model))
        controller.window = w
        w.center()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        window = w
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            CaptureSettingsTab()
                .tabItem { Label("Capture", systemImage: "camera.viewfinder") }
            OutputSettingsTab()
                .tabItem { Label("Output", systemImage: "square.and.arrow.down") }
            HotkeySettingsTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 440)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            LabeledContent("Version") {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
            }
            LabeledContent("Project") {
                Link("github.com/timhls/Chlorophyll", destination: URL(string: "https://github.com/timhls/Chlorophyll")!)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Capture

private struct CaptureSettingsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Toggle("Include mouse cursor", isOn: model.binding(\.capture.includeCursor))
            Stepper(
                "Delay: \(model.config.capture.captureDelayMilliseconds) ms",
                value: model.binding(\.capture.captureDelayMilliseconds),
                in: 0 ... 10000,
                step: 100
            )
            Toggle("Play camera sound", isOn: model.binding(\.capture.playCameraSound))
            Picker("Window capture mode", selection: model.binding(\.capture.windowMode)) {
                ForEach(CaptureConfig.WindowMode.allCases, id: \.self) { mode in
                    Text(mode == .native ? "Native (exact window)" : "Screen region (window bounds)").tag(mode)
                }
            }
            Text("Native mode captures exactly the window content. Screen mode captures the window's bounds from the display, which includes overlapping windows but is more compatible with some apps.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Output

private struct OutputSettingsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Destinations") {
                Toggle("Copy to clipboard", isOn: model.destinationBinding("clipboard"))
                Toggle("Save to file", isOn: model.destinationBinding("file"))
            }
            Section("File") {
                Picker("Format", selection: model.binding(\.output.imageFormat)) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpg")
                }
                .pickerStyle(.segmented)
                LabeledContent("Folder") {
                    HStack {
                        Text(abbreviatedFolder)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Change…") { chooseFolder() }
                    }
                }
                LabeledContent("Filename pattern") {
                    TextField("", text: model.binding(\.output.filenamePattern))
                        .textFieldStyle(.roundedBorder)
                }
                Text("Example: \(preview)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var abbreviatedFolder: String {
        let path = model.config.output.resolvedOutputFolder
        return (path as NSString).abbreviatingWithTildeInPath
    }

    private var preview: String {
        let pattern = model.config.output.filenamePattern
        let name = FilenameTemplate.render(pattern, counter: model.config.output.counter)
        let ext = model.config.output.imageFormat == "jpg" ? "jpg" : "png"
        return "\(name.isEmpty ? "Screenshot" : name).\(ext)"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: model.config.output.resolvedOutputFolder)
        if panel.runModal() == .OK, let url = panel.url {
            model.update { $0.output.outputFolder = url.path }
        }
    }
}

// MARK: - Hotkeys

private struct HotkeySettingsTab: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            HotkeyRow(label: "Capture region", binding: model.binding(\.hotkeys.region))
            HotkeyRow(label: "Pick window", binding: model.binding(\.hotkeys.window))
            HotkeyRow(label: "Capture fullscreen", binding: model.binding(\.hotkeys.fullscreen))
            HotkeyRow(label: "Capture last region", binding: model.binding(\.hotkeys.lastRegion))
            HStack {
                Spacer()
                Button("Reset to defaults") {
                    model.update { $0.hotkeys = HotkeyConfig() }
                    model.refreshHotkeysAfterConfigChange()
                }
            }
            Text("Click a shortcut, then press the desired key combination. Press ESC to cancel, ⌫ to clear. Combinations with ⌥⇧ avoid conflicts with the system screenshot shortcuts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onDisappear {
            model.refreshHotkeysAfterConfigChange()
        }
    }
}

private struct HotkeyRow: View {
    let label: String
    @Binding var binding: HotkeyBinding

    var body: some View {
        LabeledContent(label) {
            HotkeyRecorder(binding: $binding)
        }
    }
}
