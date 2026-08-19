import AppKit
import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys via Carbon's RegisterEventHotKey API
/// (still the supported mechanism for system-wide shortcuts on macOS).
public final class HotkeyCenter {
    public static let shared = HotkeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef?] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let lock = NSLock()
    private var installed = false

    private static let signature: UInt32 = 0x4348_4C52 // 'CHLR'

    private init() {}

    /// Registers a global hotkey. Returns an identifier for unregistration,
    /// or nil if registration failed (e.g. conflict with another app).
    @discardableResult
    public func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> UInt32? {
        installEventHandlerIfNeeded()

        lock.lock()
        let id = nextID
        nextID += 1
        lock.unlock()

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, ref != nil else { return nil }

        lock.lock()
        handlers[id] = action
        hotKeyRefs[id] = ref
        lock.unlock()
        return id
    }

    /// Registers a binding; returns the registration id.
    @discardableResult
    public func register(_ binding: HotkeyBinding, action: @escaping () -> Void) -> UInt32? {
        register(keyCode: binding.keyCode, modifiers: binding.carbonModifiers, action: action)
    }

    public func unregister(_ id: UInt32) {
        lock.lock()
        if let ref = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers.removeValue(forKey: id)
        lock.unlock()
    }

    public func unregisterAll() {
        lock.lock()
        for (_, ref) in hotKeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        handlers.removeAll()
        hotKeyRefs.removeAll()
        lock.unlock()
    }

    // MARK: - Internals

    private func installEventHandlerIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }
        installed = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, _ in
            var hkID = EventHotKeyID()
            guard GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            ) == noErr else { return noErr }
            HotkeyCenter.shared.fire(id: hkID.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler)
    }

    private func fire(id: UInt32) {
        lock.lock()
        let handler = handlers[id]
        lock.unlock()
        handler?()
    }
}
