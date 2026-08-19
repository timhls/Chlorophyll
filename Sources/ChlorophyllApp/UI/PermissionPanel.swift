import AppKit
import ChlorophyllCore
import SwiftUI

/// Onboarding panel shown when screen-recording permission is missing.
@MainActor
enum PermissionPanel {
    private static var window: NSWindow?

    static func show(onRetry: @escaping () -> Void) {
        if window != nil {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Screen Recording Permission"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.center()

        let view = PermissionView(
            onOpenSettings: {
                ScreenCapturePermission.openSystemSettings()
            },
            onRetry: {
                close()
                if ScreenCapturePermission.isGranted {
                    onRetry()
                } else {
                    show(onRetry: onRetry)
                }
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
        window = nil
    }
}

private struct PermissionView: View {
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Chlorophyll needs your permission")
                .font(.title2.bold())
            Text("To capture your screen, allow **Chlorophyll** under *Screen & System Audio Recording* in System Settings. After toggling it on, Chlorophyll must be restarted (quit it from the menu bar and open it again).")
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Open System Settings") { onOpenSettings() }
                    .controlSize(.large)
                Button("I've enabled it — retry") { onRetry() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
