import AppKit
import ChlorophyllCore
import Combine
import Foundation
import SwiftUI

/// App-wide observable state: configuration persistence and hotkey registration.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var config: AppConfig

    let engine = CaptureEngine()
    private var hotkeyIDs: [String: UInt32] = [:]

    init(configURL: URL = AppConfig.defaultURL()) {
        self.configURL = configURL
        if let loaded = ConfigFileManager.load(from: configURL) {
            config = loaded
        } else {
            config = AppConfig()
            try? ConfigFileManager.save(config, to: configURL)
        }
    }

    private let configURL: URL
    private static let lastRegionKey = "chlorophyll.lastRegion"

    /// The last user-selected region (Cocoa-global coordinates), persisted in UserDefaults.
    var lastRegion: CGRect? {
        get {
            guard let s = UserDefaults.standard.string(forKey: Self.lastRegionKey) else { return nil }
            let parts = s.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 4 else { return nil }
            return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        }
        set {
            if let newValue {
                let s = "\(newValue.minX),\(newValue.minY),\(newValue.width),\(newValue.height)"
                UserDefaults.standard.set(s, forKey: Self.lastRegionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastRegionKey)
            }
        }
    }

    func update(_ mutate: (inout AppConfig) -> Void) {
        mutate(&config)
        try? ConfigFileManager.save(config, to: configURL)
    }

    // MARK: - Hotkeys

    func registerHotkeys(actions: @escaping (CaptureMode) -> Void) {
        unregisterHotkeys()
        let hotkeys = config.hotkeys
        struct Entry {
            let key: String
            let binding: HotkeyBinding
            let mode: CaptureMode
        }
        let entries = [
            Entry(key: "region", binding: hotkeys.region, mode: .region),
            Entry(key: "window", binding: hotkeys.window, mode: .window),
            Entry(key: "fullscreen", binding: hotkeys.fullscreen, mode: .fullscreen),
            Entry(key: "lastRegion", binding: hotkeys.lastRegion, mode: .lastRegion)
        ]
        for entry in entries {
            hotkeyIDs[entry.key] = HotkeyCenter.shared.register(entry.binding) { [weak self] in
                self?.hotkeyFired(mode: entry.mode, actions: actions)
            }
        }
    }

    private func hotkeyFired(mode: CaptureMode, actions: (CaptureMode) -> Void) {
        MainActor.assumeIsolated {
            actions(mode)
        }
    }

    func unregisterHotkeys() {
        for (_, id) in hotkeyIDs {
            HotkeyCenter.shared.unregister(id)
        }
        hotkeyIDs.removeAll()
    }

    func refreshHotkeys(actions: @escaping (CaptureMode) -> Void) {
        registerHotkeys(actions: actions)
    }

    /// Re-register hotkeys after a settings change; the coordinator is re-wired by AppDelegate.
    func refreshHotkeysAfterConfigChange() {
        HotkeyCenter.shared.unregisterAll()
        hotkeyIDs.removeAll()
        AppDelegate.shared?.reRegisterHotkeys()
    }

    // MARK: - SwiftUI bindings

    func binding<T>(_ keyPath: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding<T>(
            get: { self.config[keyPath: keyPath] },
            set: { newValue in
                self.update { config in
                    config[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func destinationBinding(_ name: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.config.output.destinations.contains(name) },
            set: { enabled in
                self.update { config in
                    var destinations = config.output.destinations.filter { $0 != name }
                    if enabled {
                        destinations.append(name)
                    }
                    config.output.destinations = destinations
                }
            }
        )
    }
}

/// Capture modes, mirroring Greenshot's CaptureMode.
enum CaptureMode {
    case region
    case window
    case fullscreen
    case lastRegion
}
