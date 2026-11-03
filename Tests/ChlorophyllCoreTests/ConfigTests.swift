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

    @Test func defaultHotkeysMatchGreenshotForMac() {
        let defaults = HotkeyConfig.defaults
        #expect(defaults.region.displayString == "⌥⌘1")
        #expect(defaults.window.displayString == "⌥⌘2")
        #expect(defaults.fullscreen.displayString == "⌥⌘0")
        #expect(defaults.lastRegion.displayString == "⌥⇧6")
    }

    @Test func greenshotImportMapsDestinationsAndFilename() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chlorophyll-greenshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let plist = dir.appendingPathComponent("Greenshot.plist")
        let values: [String: Any] = [
            "alwaysCopyToClipboard": false,
            "alwaysSaveToFolder": false,
            "filenamePrefix": "Greenshot"
        ]
        (values as NSDictionary).write(to: plist, atomically: true)

        var imported = try GreenshotSettingsImporter.importSettings(
            from: plist,
            outputFolder: "~/Pictures/Greenshot"
        )

        #expect(imported.output.destinations == ["picker"])
        #expect(imported.output.filenamePattern == "Greenshot ${YYYY}-${MM}-${DD} ${hh}-${mm}-${ss}")
        #expect(imported.output.outputFolder == "~/Pictures/Greenshot")
        #expect(imported.hotkeys == HotkeyConfig())

        imported = try GreenshotSettingsImporter.importSettings(
            from: plist,
            copyToClipboard: true,
            saveToFolder: false
        )
        #expect(imported.output.destinations == ["clipboard"])

        imported = try GreenshotSettingsImporter.importSettings(
            from: plist,
            copyToClipboard: false,
            saveToFolder: true
        )
        #expect(imported.output.destinations == ["file"])

        imported = try GreenshotSettingsImporter.importSettings(
            from: plist,
            copyToClipboard: true,
            saveToFolder: true
        )
        #expect(imported.output.destinations == ["clipboard", "file"])
    }

    @Test func greenshotImportUsesSettingsOverridesAndOmitsEmptyPrefix() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chlorophyll-greenshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let plist = dir.appendingPathComponent("Greenshot.plist")
        let emptyPrefix: [String: Any] = ["filenamePrefix": ""]
        (emptyPrefix as NSDictionary).write(to: plist, atomically: true)

        let imported = try GreenshotSettingsImporter.importSettings(
            from: plist,
            copyToClipboard: true,
            saveToFolder: true
        )

        #expect(imported.output.filenamePattern == "${YYYY}-${MM}-${DD} ${hh}-${mm}-${ss}")
        #expect(imported.output.destinations == ["clipboard", "file"])
    }

    @Test func greenshotBackupUsesTimestampedSibling() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chlorophyll-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let configURL = dir.appendingPathComponent("config.json")
        let original = AppConfig()
        try ConfigFileManager.save(original, to: configURL)
        let existing = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("config.") }

        let backupURL = try GreenshotSettingsImporter.backupExistingConfig(
            at: configURL,
            existingFiles: existing
        )

        #expect(backupURL.lastPathComponent != "config.json")
        #expect(backupURL.lastPathComponent.contains("backup"))
        #expect(ConfigFileManager.load(from: backupURL) == original)
    }
}
