import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Centralizes coordinate conversions between the three coordinate spaces involved:
/// - Cocoa/AppKit global space (origin at bottom-left of the primary screen; used by NSWindow/NSScreen)
/// - CG global space (origin at top-left of the primary display; used by CGWindowList/CGDisplay)
/// - ScreenCaptureKit display-local space (origin at a display's top-left; used for sourceRect)
public enum ScreenGeometry {
    /// Height of the primary display in points (the anchor for CG ↔ Cocoa flips).
    public static var primaryDisplayHeight: CGFloat {
        CGDisplayBounds(CGMainDisplayID()).height
    }

    /// Converts a Cocoa-global rect to CG-global coordinates.
    public static func cgGlobal(fromCocoa rect: CGRect) -> CGRect {
        let h = primaryDisplayHeight
        return CGRect(
            x: rect.minX,
            y: h - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a Cocoa-global rect to display-local SCK coordinates for `display`.
    public static func localSCKRect(ofCocoaRect rect: CGRect, in display: SCDisplay) -> CGRect {
        let globalCG = cgGlobal(fromCocoa: rect)
        let d = display.frame
        return CGRect(
            x: globalCG.minX - d.minX,
            y: globalCG.minY - d.minY,
            width: globalCG.width,
            height: globalCG.height
        )
    }

    /// The NSScreen corresponding to an SCDisplay (matched by frame, with tolerance).
    public static func screen(for display: SCDisplay) -> NSScreen? {
        let h = primaryDisplayHeight
        let d = display.frame
        let cocoaFrame = CGRect(
            x: d.minX,
            y: h - d.maxY,
            width: d.width,
            height: d.height
        )
        return NSScreen.screens.first {
            abs($0.frame.minX - cocoaFrame.minX) < 2
                && abs($0.frame.minY - cocoaFrame.minY) < 2
                && abs($0.frame.width - cocoaFrame.width) < 2
                && abs($0.frame.height - cocoaFrame.height) < 2
        }
    }

    /// Backing scale factor of the screen containing a Cocoa-global point.
    public static func scale(atCocoaPoint point: CGPoint) -> CGFloat {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2
    }

    /// Backing scale factor for a display.
    public static func scale(of display: SCDisplay) -> CGFloat {
        if let screen = screen(for: display) {
            return screen.backingScaleFactor
        }
        return 2
    }

    /// The SCDisplay with the largest intersection with a Cocoa-global rect.
    public static func display(containingCocoaRect rect: CGRect, in content: SCShareableContent) -> SCDisplay? {
        let cgRect = cgGlobal(fromCocoa: rect)
        var best: (display: SCDisplay, area: CGFloat)?
        for display in content.displays {
            let intersection = display.frame.intersection(cgRect)
            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > (best?.area ?? 0) {
                    best = (display, area)
                }
            }
        }
        return best?.display
    }
}
