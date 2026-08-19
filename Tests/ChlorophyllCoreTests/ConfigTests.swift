@testable import ChlorophyllCore
import Foundation
import Testing

struct ConfigTests {
    private func tempURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chlorophyll-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    @Test func roundTrip() throws {
        let url = try tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var config = AppConfig()
        config.capture.includeCursor = true
        config.output.filenamePattern = "shot_${n}"
        config.output.counter = 42
        config.hotkeys.region = HotkeyBinding(keyCode: 10, carbonModifiers: 0x0800)

        try ConfigFileManager.save(config, to: url)
        let loaded = ConfigFileManager.load(from: url)

        #expect(loaded != nil)
        #expect(loaded == config)
    }

    @Test func partialConfigMergesWithDefaults() throws {
        let url = try tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let json = """
        {
          "output": { "counter": 7, "imageFormat": "jpg" }
        }
        """
        try Data(json.utf8).write(to: url)

        let loaded = ConfigFileManager.load(from: url)
        #expect(loaded?.output.counter == 7)
        #expect(loaded?.output.imageFormat == "jpg")
        #expect(loaded?.capture == CaptureConfig())
        #expect(loaded?.hotkeys == HotkeyConfig())
    }

    @Test func unknownFieldsAreIgnored() throws {
        let url = try tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let json = """
        {
          "futureField": { "a": 1 },
          "capture": { "includeCursor": true, "brandNewOption": "x" }
        }
        """
        try Data(json.utf8).write(to: url)

        let loaded = ConfigFileManager.load(from: url)
        #expect(loaded?.capture.includeCursor == true)
    }

    @Test func missingFileReturnsNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID()).json")
        #expect(ConfigFileManager.load(from: url) == nil)
    }

    @Test func resolvedOutputFolderDefaultsToDesktop() {
        let config = OutputConfig()
        #expect(config.resolvedOutputFolder.hasSuffix("Desktop"))
    }

    @Test func defaultHotkeysUseOptionShift() {
        let defaults = HotkeyConfig.defaults
        #expect(defaults.region.displayString == "⌥⇧4")
        #expect(defaults.window.displayString == "⌥⇧5")
        #expect(defaults.fullscreen.displayString == "⌥⇧3")
        #expect(defaults.lastRegion.displayString == "⌥⇧6")
    }
}
