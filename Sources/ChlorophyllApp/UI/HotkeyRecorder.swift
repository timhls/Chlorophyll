import AppKit
import Carbon.HIToolbox
import ChlorophyllCore
import SwiftUI

/// Records a global hotkey combination. Click to arm, then press a key
/// combination (ESC cancels, ⌫ clears).
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var binding: HotkeyBinding

    func makeNSView(context _: Context) -> RecorderView {
        let view = RecorderView()
        view.onBinding = { newBinding in
            binding = newBinding
        }
        view.binding = binding
        return view
    }

    func updateNSView(_ nsView: RecorderView, context _: Context) {
        nsView.binding = binding
        nsView.onBinding = { newBinding in
            binding = newBinding
        }
    }
}

final class RecorderView: NSView {
    var onBinding: ((HotkeyBinding) -> Void)?
    var binding: HotkeyBinding = HotkeyConfig.defaults.region {
        didSet { needsDisplay = true }
    }

    private var armed = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override func draw(_: NSRect) {
        let bg: NSColor
        let text: String
        if armed {
            bg = NSColor.controlAccentColor.withAlphaComponent(0.25)
            text = "Press keys…"
        } else {
            bg = NSColor.controlBackgroundColor
            text = binding.carbonModifiers == 0 && binding.keyCode == 0
                ? "None"
                : binding.displayString
        }
        bg.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5).stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium),
            .foregroundColor: armed ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attrs
        )
    }

    override func mouseDown(with _: NSEvent) {
        armed = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        armed = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard armed else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            armed = false
            return
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            binding = HotkeyBinding(keyCode: 0, carbonModifiers: 0)
            armed = false
            onBinding?(binding)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isDisjoint(with: [.capsLock, .function]) else { return }

        var carbon: UInt32 = 0
        if flags.contains(.command) {
            carbon |= CarbonModifiers.command
        }
        if flags.contains(.option) {
            carbon |= CarbonModifiers.option
        }
        if flags.contains(.shift) {
            carbon |= CarbonModifiers.shift
        }
        if flags.contains(.control) {
            carbon |= CarbonModifiers.control
        }
        guard carbon != 0 else { return } // require at least one modifier
        guard KeyCodeMap.isKnown(UInt32(event.keyCode)) else { return }

        binding = HotkeyBinding(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
        armed = false
        onBinding?(binding)
    }
}
