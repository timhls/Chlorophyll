import AppKit
import SwiftUI

/// Transient toast notification in the bottom-right corner of the main screen.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(text: String, revealURL: URL? = nil, duration: TimeInterval = 2.8) {
        dismiss()

        let host = NSHostingView(rootView: ToastView(text: text, revealURL: revealURL))

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = max(host.fittingSize.width, 200)
        let height = max(host.fittingSize.height, 44)
        let origin = NSPoint(
            x: screenFrame.maxX - width - 16,
            y: screenFrame.minY + 16
        )

        let toastPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toastPanel.level = .floating
        toastPanel.isOpaque = false
        toastPanel.backgroundColor = .clear
        toastPanel.hasShadow = true
        toastPanel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        toastPanel.contentView = host
        toastPanel.orderFrontRegardless()

        panel = toastPanel
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            dismiss()
        }
    }

    static func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct ToastView: View {
    let text: String
    let revealURL: URL?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
            Text(text)
                .lineLimit(2)
            if let revealURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([revealURL])
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }
}
