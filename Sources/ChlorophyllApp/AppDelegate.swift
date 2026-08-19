import AppKit
import ChlorophyllCore
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private let settingsWindowController = SettingsWindowController()
    private var cancellable: AnyCancellable?
    private var model: AppModel!
    private var coordinator: CaptureCoordinator!

    func applicationDidFinishLaunching(_: Notification) {
        Self.shared = self

        model = AppModel()
        coordinator = CaptureCoordinator(model: model)

        buildStatusItem()
        model.registerHotkeys { [weak self] mode in
            self?.coordinator.handle(mode)
        }
        cancellable = model.$config.sink { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    func applicationWillTerminate(_: Notification) {
        model.unregisterHotkeys()
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    // MARK: - Status item & menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Chlorophyll")
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusItem.menu = menu
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let hotkeys = model.config.hotkeys
        add(menu: menu, title: "Capture Region", shortcut: hotkeys.region, action: #selector(captureRegion))
        add(menu: menu, title: "Capture Window…", shortcut: hotkeys.window, action: #selector(captureWindow))
        add(menu: menu, title: "Capture Fullscreen", shortcut: hotkeys.fullscreen, action: #selector(captureFullscreen))
        add(menu: menu, title: "Capture Last Region", shortcut: hotkeys.lastRegion, action: #selector(captureLastRegion))

        menu.addItem(.separator())
        add(menu: menu, title: "Settings…", shortcut: nil, action: #selector(openSettings), keyEquivalent: ",")
        add(menu: menu, title: "About Chlorophyll", shortcut: nil, action: #selector(showAbout))
        menu.addItem(.separator())
        add(menu: menu, title: "Quit Chlorophyll", shortcut: nil, action: #selector(quit), keyEquivalent: "q")
    }

    private func add(
        menu: NSMenu,
        title: String,
        shortcut: HotkeyBinding?,
        action: Selector,
        keyEquivalent: String = ""
    ) {
        let display = title + (shortcut.map { "   \($0.displayString)" } ?? "")
        let item = NSMenuItem(title: display, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func captureRegion() {
        coordinator.handle(.region)
    }

    @objc private func captureWindow() {
        coordinator.handle(.window)
    }

    @objc private func captureFullscreen() {
        coordinator.handle(.fullscreen)
    }

    @objc private func captureLastRegion() {
        coordinator.handle(.lastRegion)
    }

    @objc private func openSettings() {
        settingsWindowController.toggle(model: model)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Chlorophyll",
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Hotkey re-registration

    func reRegisterHotkeys() {
        model.registerHotkeys { [weak self] mode in
            self?.coordinator.handle(mode)
        }
    }
}
