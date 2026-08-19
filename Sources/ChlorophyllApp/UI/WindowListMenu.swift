import AppKit
import ChlorophyllCore

/// Pops a menu listing on-screen windows at the current mouse location.
@MainActor
enum WindowListMenu {
    private static var proxy: MenuProxy?

    static func show(_ windows: [WindowInfo], onSelect: @escaping (WindowInfo) -> Void) {
        guard !windows.isEmpty else {
            Toast.show(text: "No capturable windows found.")
            return
        }

        let sorted = windows.sorted {
            let lhsTitled = !$0.title.isEmpty ? 1 : 0
            let rhsTitled = !$1.title.isEmpty ? 1 : 0
            if lhsTitled != rhsTitled {
                return lhsTitled > rhsTitled
            }
            return $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height
        }
        let top = Array(sorted.prefix(20))

        let menu = NSMenu()
        menu.autoenablesItems = false
        let menuProxy = MenuProxy(windows: top, onSelect: onSelect)
        for (index, window) in top.enumerated() {
            let item = NSMenuItem(
                title: window.displayName,
                action: #selector(MenuProxy.selectWindow(_:)),
                keyEquivalent: index < 9 ? String(index + 1) : ""
            )
            item.target = menuProxy
            item.representedObject = NSNumber(value: window.id)
            item.isEnabled = true
            menu.addItem(item)
        }
        proxy = menuProxy

        let location = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: location, in: nil)
        proxy = nil
    }
}

private final class MenuProxy: NSObject {
    private let windows: [CGWindowID: WindowInfo]
    private let onSelect: (WindowInfo) -> Void

    init(windows: [WindowInfo], onSelect: @escaping (WindowInfo) -> Void) {
        self.windows = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        self.onSelect = onSelect
    }

    @objc func selectWindow(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber,
              let window = windows[CGWindowID(number.intValue)] else { return }
        onSelect(window)
    }
}
