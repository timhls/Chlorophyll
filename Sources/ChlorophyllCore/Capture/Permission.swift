import AppKit
import CoreGraphics
import Foundation

/// Helpers around the macOS Screen Recording (TCC) permission.
public enum ScreenCapturePermission {
    /// True if the app already has screen-recording permission.
    public static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system permission prompt (returns false when already granted
    /// or denied; the actual grant lands after the user toggles it in Settings
    /// and the app is restarted).
    @discardableResult
    public static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Opens the Privacy & Security pane where screen recording is configured.
    public static func openSystemSettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }
}
