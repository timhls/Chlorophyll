import AppKit
import Carbon.HIToolbox

/// Full-screen overlay for interactive region selection, shown across all displays.
/// Drag to select a region; click to capture the whole display; ESC cancels.
enum RegionPicker {
    private static var windows: [PickerWindow] = []
    private static var monitor: Any?
    private static var completion: ((CGRect?) -> Void)?

    static func present(onComplete: @escaping (CGRect?) -> Void) {
        guard windows.isEmpty else { return }
        completion = onComplete

        for screen in NSScreen.screens {
            let window = PickerWindow(screen: screen)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                finish(with: nil)
                return nil
            }
            return event
        }
    }

    static func finish(with globalRect: CGRect?) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        NSCursor.pop()
        let cb = completion
        completion = nil
        cb?(globalRect)
    }
}

/// Borderless overlay window for one screen.
final class PickerWindow: NSWindow {
    fileprivate var selectionView: SelectionView!

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        backgroundColor = NSColor.black.withAlphaComponent(0.25)
        isOpaque = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false

        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        contentView = view
        selectionView = view
    }

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_: Any?) {
        RegionPicker.finish(with: nil)
    }
}

/// Draws the selection rectangle and handles mouse tracking.
final class SelectionView: NSView {
    private var dragStart: NSPoint?
    private var dragCurrent: NSPoint?
    private var mouseDownScreen: NSScreen?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_: NSRect) {
        guard let start = dragStart, let current = dragCurrent else { return }
        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        guard rect.width > 1, rect.height > 1 else { return }

        // Highlight the selected area and draw a crisp border + size badge.
        NSColor(calibratedWhite: 0, alpha: 0).setFill()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        NSColor.white.setStroke()
        border.stroke()

        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attrs)
        var badge = NSRect(
            x: rect.midX - size.width / 2 - 6,
            y: rect.maxY + 6,
            width: size.width + 12,
            height: size.height + 4
        )
        if badge.maxY > bounds.maxY - 4 {
            badge.origin.y = rect.minY - badge.height - 6
        }
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        label.draw(at: NSPoint(x: badge.minX + 6, y: badge.minY + 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragCurrent = dragStart
        mouseDownScreen = window?.screen
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let end = convert(event.locationInWindow, from: nil)
        let localRect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        // A click without a meaningful drag captures the entire clicked display.
        if localRect.width < 5 || localRect.height < 5 {
            if let screenFrame = mouseDownScreen?.frame {
                RegionPicker.finish(with: screenFrame)
            } else {
                RegionPicker.finish(with: nil)
            }
            return
        }

        let globalRect = window!.convertToScreen(localRect)
        RegionPicker.finish(with: globalRect)
    }
}
