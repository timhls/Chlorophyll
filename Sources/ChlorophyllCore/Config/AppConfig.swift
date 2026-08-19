import Foundation

/// Capture behavior configuration.
public struct CaptureConfig: Codable, Equatable {
    /// Include the mouse cursor in captures.
    public var includeCursor: Bool
    /// Delay before capturing, in milliseconds.
    public var captureDelayMilliseconds: Int
    /// Play the camera sound after a successful capture.
    public var playCameraSound: Bool
    /// Capture mode used for the "window" hotkey: native (SCK window filter) or screen region.
    public var windowMode: WindowMode

    public enum WindowMode: String, Codable, Equatable, CaseIterable {
        case native
        case screen
    }

    public init(
        includeCursor: Bool = false,
        captureDelayMilliseconds: Int = 0,
        playCameraSound: Bool = true,
        windowMode: WindowMode = .native
    ) {
        self.includeCursor = includeCursor
        self.captureDelayMilliseconds = captureDelayMilliseconds
        self.playCameraSound = playCameraSound
        self.windowMode = windowMode
    }

    private enum CodingKeys: String, CodingKey {
        case includeCursor
        case captureDelayMilliseconds
        case playCameraSound
        case windowMode
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = try CaptureConfig(
            includeCursor: c.decodeIfPresent(Bool.self, forKey: .includeCursor) ?? CaptureConfig().includeCursor,
            captureDelayMilliseconds: c.decodeIfPresent(Int.self, forKey: .captureDelayMilliseconds) ?? CaptureConfig().captureDelayMilliseconds,
            playCameraSound: c.decodeIfPresent(Bool.self, forKey: .playCameraSound) ?? CaptureConfig().playCameraSound,
            windowMode: c.decodeIfPresent(WindowMode.self, forKey: .windowMode) ?? CaptureConfig().windowMode
        )
    }
}

/// Output/destination configuration.
public struct OutputConfig: Codable, Equatable {
    /// Active destinations, in order. Known: "clipboard", "file", "picker" (later).
    public var destinations: [String]
    /// Image format for file output: "png" or "jpg".
    public var imageFormat: String
    /// Folder screenshots are saved to.
    public var outputFolder: String
    /// Filename template pattern.
    public var filenamePattern: String
    /// Counter used for ${n} tokens; incremented on every file write.
    public var counter: Int

    public init(
        destinations: [String] = ["clipboard", "file"],
        imageFormat: String = "png",
        outputFolder: String = "",
        filenamePattern: String = "${YYYY}-${MM}-${DD} ${hh}-${mm}-${ss}",
        counter: Int = 1
    ) {
        self.destinations = destinations
        self.imageFormat = imageFormat
        self.outputFolder = outputFolder
        self.filenamePattern = filenamePattern
        self.counter = counter
    }

    private enum CodingKeys: String, CodingKey {
        case destinations
        case imageFormat
        case outputFolder
        case filenamePattern
        case counter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = try OutputConfig(
            destinations: c.decodeIfPresent([String].self, forKey: .destinations) ?? OutputConfig().destinations,
            imageFormat: c.decodeIfPresent(String.self, forKey: .imageFormat) ?? OutputConfig().imageFormat,
            outputFolder: c.decodeIfPresent(String.self, forKey: .outputFolder) ?? OutputConfig().outputFolder,
            filenamePattern: c.decodeIfPresent(String.self, forKey: .filenamePattern) ?? OutputConfig().filenamePattern,
            counter: c.decodeIfPresent(Int.self, forKey: .counter) ?? OutputConfig().counter
        )
    }

    /// The effective output folder: configured folder, or the user's Desktop by default.
    public var resolvedOutputFolder: String {
        if outputFolder.isEmpty {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop").path
        }
        return (outputFolder as NSString).expandingTildeInPath
    }
}

/// Global hotkey configuration.
public struct HotkeyConfig: Codable, Equatable {
    public var region: HotkeyBinding
    public var window: HotkeyBinding
    public var fullscreen: HotkeyBinding
    public var lastRegion: HotkeyBinding

    public init(
        region: HotkeyBinding = HotkeyConfig.defaults.region,
        window: HotkeyBinding = HotkeyConfig.defaults.window,
        fullscreen: HotkeyBinding = HotkeyConfig.defaults.fullscreen,
        lastRegion: HotkeyBinding = HotkeyConfig.defaults.lastRegion
    ) {
        self.region = region
        self.window = window
        self.fullscreen = fullscreen
        self.lastRegion = lastRegion
    }

    /// Default bindings avoid ⌘⇧3/4/5 which macOS reserves for its own screenshots.
    public static let defaults = HotkeyConfig(
        region: HotkeyBinding(keyCode: 0x15, carbonModifiers: 0x0A00), // ⌥⇧4
        window: HotkeyBinding(keyCode: 0x17, carbonModifiers: 0x0A00), // ⌥⇧5
        fullscreen: HotkeyBinding(keyCode: 0x14, carbonModifiers: 0x0A00), // ⌥⇧3
        lastRegion: HotkeyBinding(keyCode: 0x16, carbonModifiers: 0x0A00) // ⌥⇧6
    )

    private enum CodingKeys: String, CodingKey {
        case region, window, fullscreen, lastRegion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = try HotkeyConfig(
            region: c.decodeIfPresent(HotkeyBinding.self, forKey: .region) ?? HotkeyConfig.defaults.region,
            window: c.decodeIfPresent(HotkeyBinding.self, forKey: .window) ?? HotkeyConfig.defaults.window,
            fullscreen: c.decodeIfPresent(HotkeyBinding.self, forKey: .fullscreen) ?? HotkeyConfig.defaults.fullscreen,
            lastRegion: c.decodeIfPresent(HotkeyBinding.self, forKey: .lastRegion) ?? HotkeyConfig.defaults.lastRegion
        )
    }
}

/// Root configuration object, persisted as JSON.
public struct AppConfig: Codable, Equatable {
    public var capture: CaptureConfig
    public var output: OutputConfig
    public var hotkeys: HotkeyConfig

    public init(
        capture: CaptureConfig = CaptureConfig(),
        output: OutputConfig = OutputConfig(),
        hotkeys: HotkeyConfig = HotkeyConfig()
    ) {
        self.capture = capture
        self.output = output
        self.hotkeys = hotkeys
    }

    private enum CodingKeys: String, CodingKey {
        case capture, output, hotkeys
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = try AppConfig(
            capture: c.decodeIfPresent(CaptureConfig.self, forKey: .capture) ?? CaptureConfig(),
            output: c.decodeIfPresent(OutputConfig.self, forKey: .output) ?? OutputConfig(),
            hotkeys: c.decodeIfPresent(HotkeyConfig.self, forKey: .hotkeys) ?? HotkeyConfig()
        )
    }

    /// Default URL: ~/Library/Application Support/Chlorophyll/config.json
    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Chlorophyll/config.json")
    }
}

/// Loads and saves `AppConfig` as pretty-printed JSON, merging unknown/partial
/// files field-by-field with defaults (forward/backward compatible).
public enum ConfigFileManager {
    public static func load(from url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    public static func save(_ config: AppConfig, to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }
}
