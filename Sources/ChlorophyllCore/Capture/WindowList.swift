import AppKit
import CoreGraphics
import Foundation

/// Information about an on-screen window, used for the window-picker capture mode.
public struct WindowInfo: Identifiable, Equatable {
    public let id: CGWindowID
    public let ownerName: String
    public let title: String
    /// Window bounds in global (Cocoa) coordinates.
    public let frame: CGRect
    public let isOnscreen: Bool

    public var displayName: String {
        if !title.isEmpty, !ownerName.isEmpty {
            return "\(title) — \(ownerName)"
        }
        return title.isEmpty ? ownerName : title
    }
}

/// Enumerates on-screen windows via the CGWindowList API.
public enum WindowList {
    public static func onScreenWindows() -> [WindowInfo] {
        let option: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var result: [WindowInfo] = []
        for dict in raw {
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID else { continue }
            let owner = dict[kCGWindowOwnerName as String] as? String ?? ""
            let title = dict[kCGWindowName as String] as? String ?? ""
            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let w = boundsDict["Width"] as? CGFloat,
                  let h = boundsDict["Height"] as? CGFloat else { continue }
            let frame = CGRect(x: x, y: y, width: w, height: h)
            guard w > 50, h > 50 else { continue }
            guard owner != "Window Server", owner != "SystemUIServer" else { continue }

            result.append(WindowInfo(
                id: id,
                ownerName: owner,
                title: title,
                frame: frame,
                isOnscreen: true
            ))
        }
        return result
    }

    /// Bounds in CGWindow coordinates use a top-left origin; convert to Cocoa
    /// bottom-left global coordinates used by AppKit and ScreenCaptureKit.
    public static func cocoaFrame(fromCGWindowFrame frame: CGRect) -> CGRect {
        let screenFrame = NSScreen.screens.first?.frame ?? .zero
        let flippedY = screenFrame.maxY - frame.maxY
        return CGRect(x: frame.minX, y: flippedY, width: frame.width, height: frame.height)
    }
}
