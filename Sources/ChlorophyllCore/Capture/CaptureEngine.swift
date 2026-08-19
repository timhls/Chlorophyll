import AppKit
import AudioToolbox
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Errors thrown by `CaptureEngine`.
public enum CaptureError: Error, LocalizedError {
    case noMatchingDisplay
    case windowNotFound
    case compositeFailed
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .noMatchingDisplay: "No display matches the requested capture area."
        case .windowNotFound: "The window to capture could not be found."
        case .compositeFailed: "Failed to compose the multi-display capture."
        case .notAuthorized: "Screen recording permission is not granted."
        }
    }
}

/// Options for a capture.
public struct CaptureOptions {
    public var includeCursor: Bool

    public init(includeCursor: Bool = false) {
        self.includeCursor = includeCursor
    }
}

/// Screen capture via ScreenCaptureKit (macOS 14+ `SCScreenshotManager`).
public final class CaptureEngine {
    public init() {}

    /// Fetches current shareable content (displays + windows).
    public func shareableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// Captures a region given in Cocoa-global coordinates.
    /// The display with the largest intersection is captured and cropped.
    public func captureRegion(_ globalRect: CGRect, options: CaptureOptions = CaptureOptions()) async throws -> CGImage {
        let content = try await shareableContent()
        guard let display = ScreenGeometry.display(containingCocoaRect: globalRect, in: content) else {
            throw CaptureError.noMatchingDisplay
        }
        let localRect = ScreenGeometry.localSCKRect(ofCocoaRect: globalRect, in: display)
            .intersection(CGRect(origin: .zero, size: display.frame.size))
        return try await captureDisplay(display, localRect: localRect, options: options)
    }

    /// Captures a full display, or a display-local portion of it.
    public func captureDisplay(
        _ display: SCDisplay,
        localRect: CGRect? = nil,
        options: CaptureOptions = CaptureOptions()
    ) async throws -> CGImage {
        let content = try await shareableContent()
        let filter = SCContentFilter(display: display, excludingWindows: [])
        return try await capture(filter: filter, display: display, localRect: localRect, options: options, content: content)
    }

    /// Captures a specific window using SCK's window content filter (native mode).
    public func captureWindow(id: CGWindowID, options: CaptureOptions = CaptureOptions()) async throws -> CGImage {
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == id }) else {
            throw CaptureError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.showsCursor = options.includeCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        let scale = ScreenGeometry.scale(atCocoaPoint: CGPoint(
            x: window.frame.midX,
            y: window.frame.midY
        ))
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            // Fallback: crop the window bounds from its display.
            let cocoa = CGRect(
                x: window.frame.minX,
                y: window.frame.minY,
                width: window.frame.width,
                height: window.frame.height
            )
            return try await captureRegion(cocoa, options: options)
        }
    }

    /// Captures the window bounds as a screen region (Windows Greenshot "Screen" mode parity).
    public func captureWindowByScreen(_ window: WindowInfo, options: CaptureOptions = CaptureOptions()) async throws -> CGImage {
        let cocoa = WindowList.cocoaFrame(fromCGWindowFrame: window.frame)
        return try await captureRegion(cocoa, options: options)
    }

    /// Captures all displays and composites them into a single image laid out by global position.
    public func captureAllDisplays(options: CaptureOptions = CaptureOptions()) async throws -> CGImage {
        let content = try await shareableContent()
        guard !content.displays.isEmpty else { throw CaptureError.noMatchingDisplay }

        var images: [(cocoaFrame: CGRect, image: CGImage)] = []
        for display in content.displays {
            let image = try await captureDisplay(display, options: options)
            guard let screen = ScreenGeometry.screen(for: display) else { continue }
            images.append((screen.frame, image))
        }
        guard !images.isEmpty else { throw CaptureError.compositeFailed }

        guard let first = images.first else { throw CaptureError.compositeFailed }
        var union = first.cocoaFrame
        for item in images.dropFirst() {
            union = union.union(item.cocoaFrame)
        }

        let maxScale = images.map { ScreenGeometry.scale(atCocoaPoint: CGPoint(x: $0.cocoaFrame.midX, y: $0.cocoaFrame.midY)) }.max() ?? 2
        let pixelW = Int(ceil(union.width * maxScale))
        let pixelH = Int(ceil(union.height * maxScale))

        guard let ctx = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw CaptureError.compositeFailed
        }

        ctx.scaleBy(x: maxScale, y: maxScale)
        ctx.translateBy(x: -union.minX, y: -union.minY)
        for item in images {
            let scale = ScreenGeometry.scale(atCocoaPoint: CGPoint(x: item.cocoaFrame.midX, y: item.cocoaFrame.midY))
            let w = CGFloat(item.image.width) / scale
            let h = CGFloat(item.image.height) / scale
            ctx.draw(item.image, in: CGRect(x: item.cocoaFrame.minX, y: item.cocoaFrame.minY, width: w, height: h))
        }
        guard let composed = ctx.makeImage() else { throw CaptureError.compositeFailed }
        return composed
    }

    // MARK: - Internals

    private func capture(
        filter: SCContentFilter,
        display: SCDisplay,
        localRect: CGRect?,
        options: CaptureOptions,
        content _: SCShareableContent
    ) async throws -> CGImage {
        let config = SCStreamConfiguration()
        let rect = localRect ?? CGRect(origin: .zero, size: display.frame.size)
        let scale = ScreenGeometry.scale(of: display)
        config.sourceRect = rect
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.showsCursor = options.includeCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

/// The classic camera shutter sound (same system sound macOS uses for screenshots).
public enum CameraSound {
    public static func play() {
        AudioServicesPlaySystemSound(1107)
    }
}
