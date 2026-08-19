import AppKit
import ChlorophyllCore
import Foundation

/// Orchestrates capture modes, post-capture destinations and user feedback.
@MainActor
final class CaptureCoordinator: NSObject {
    private let model: AppModel
    private var isCapturing = false

    init(model: AppModel) {
        self.model = model
    }

    func handle(_ mode: CaptureMode) {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        guard ScreenCapturePermission.isGranted else {
            PermissionPanel.show { [weak self] in
                self?.handle(mode)
            }
            return
        }

        switch mode {
        case .region:
            RegionPicker.present { [weak self] rect in
                guard let self, let rect else { return }
                model.lastRegion = rect
                capture(rect: rect)
            }
        case .window:
            let windows = WindowList.onScreenWindows()
            WindowListMenu.show(windows) { [weak self] window in
                guard let self else { return }
                switch model.config.capture.windowMode {
                case .native:
                    captureWindow(id: window.id)
                case .screen:
                    captureScreenWindow(window)
                }
            }
        case .fullscreen:
            captureFullscreen()
        case .lastRegion:
            if let rect = model.lastRegion {
                capture(rect: rect)
            } else {
                Toast.show(text: "No previous region — capture a region first.")
            }
        }
    }

    // MARK: - Capture paths

    private func capture(rect: CGRect) {
        runAfterDelay {
            let options = CaptureOptions(includeCursor: self.model.config.capture.includeCursor)
            Task { @MainActor in
                do {
                    let image = try await self.model.engine.captureRegion(rect, options: options)
                    self.deliver(image)
                } catch {
                    Toast.show(text: "Capture failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func captureWindow(id: CGWindowID) {
        let options = CaptureOptions(includeCursor: model.config.capture.includeCursor)
        Task { @MainActor in
            do {
                let image = try await self.model.engine.captureWindow(id: id, options: options)
                self.deliver(image)
            } catch {
                Toast.show(text: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func captureScreenWindow(_ window: WindowInfo) {
        let options = CaptureOptions(includeCursor: model.config.capture.includeCursor)
        Task { @MainActor in
            do {
                let image = try await self.model.engine.captureWindowByScreen(window, options: options)
                self.deliver(image)
            } catch {
                Toast.show(text: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func captureFullscreen() {
        let options = CaptureOptions(includeCursor: model.config.capture.includeCursor)
        Task { @MainActor in
            do {
                let image = try await self.model.engine.captureAllDisplays(options: options)
                self.deliver(image)
            } catch {
                Toast.show(text: "Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func runAfterDelay(_ block: @escaping () -> Void) {
        let delay = model.config.capture.captureDelayMilliseconds
        guard delay > 0 else {
            block()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: block)
    }

    // MARK: - Destinations

    private func deliver(_ image: CGImage) {
        if model.config.capture.playCameraSound {
            CameraSound.play()
        }

        var savedURL: URL?
        var copiedToClipboard = false
        let destinations = model.config.output.destinations

        if destinations.contains("clipboard") {
            copiedToClipboard = writeToClipboard(image)
        }
        if destinations.contains("file") {
            savedURL = writeToFile(image)
        }

        var parts: [String] = []
        if copiedToClipboard {
            parts.append("copied to clipboard")
        }
        if let url = savedURL {
            parts.append("saved as \((url.lastPathComponent as NSString).deletingPathExtension)")
        }
        let text = parts.isEmpty
            ? "Capture complete (no destination enabled)"
            : "Screenshot \(parts.joined(separator: " and "))."
        Toast.show(text: text, revealURL: savedURL)
    }

    private func writeToClipboard(_ image: CGImage) -> Bool {
        guard let data = image.representation(using: .png) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }

    private func writeToFile(_ image: CGImage) -> URL? {
        let output = model.config.output
        let folder = URL(fileURLWithPath: output.resolvedOutputFolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let ext = output.imageFormat == "jpg" ? "jpg" : "png"
        var counter = output.counter
        var name = FilenameTemplate.render(
            output.filenamePattern,
            counter: counter,
            size: CGSize(width: image.width, height: image.height)
        )
        if name.isEmpty {
            name = "Screenshot"
        }
        var url = folder.appendingPathComponent("\(name).\(ext)")
        while FileManager.default.fileExists(atPath: url.path) {
            counter += 1
            name = FilenameTemplate.render(
                output.filenamePattern,
                counter: counter,
                size: CGSize(width: image.width, height: image.height)
            )
            url = folder.appendingPathComponent("\(name).\(ext)")
        }

        let type: NSBitmapImageRep.FileType = ext == "jpg" ? .jpeg : .png
        guard let data = image.representation(using: type, quality: 0.9) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }

        var nextCounter = output.counter + 1
        if nextCounter > 9999 {
            nextCounter = 1
        }
        model.update { config in
            config.output.counter = nextCounter
        }
        return url
    }
}

extension CGImage {
    func representation(using type: NSBitmapImageRep.FileType, quality: CGFloat = 1.0) -> Data? {
        let rep = NSBitmapImageRep(cgImage: self)
        var props: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if type == .jpeg {
            props[.compressionFactor] = quality
        }
        return rep.representation(using: type, properties: props)
    }
}
