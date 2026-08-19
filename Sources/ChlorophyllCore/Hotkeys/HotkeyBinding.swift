import AppKit
import Carbon.HIToolbox
import Foundation

/// Carbon modifier bit masks as UInt32 for `HotkeyBinding.carbonModifiers`.
public enum CarbonModifiers {
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let alphaLock: UInt32 = 0x0400
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000
}

/// A global hotkey binding: a virtual key code plus Carbon modifier flags.
public struct HotkeyBinding: Codable, Equatable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Human-readable representation, e.g. "⌥⇧4".
    public var displayString: String {
        var s = ""
        if carbonModifiers & CarbonModifiers.control != 0 {
            s += "⌃"
        }
        if carbonModifiers & CarbonModifiers.option != 0 {
            s += "⌥"
        }
        if carbonModifiers & CarbonModifiers.shift != 0 {
            s += "⇧"
        }
        if carbonModifiers & CarbonModifiers.command != 0 {
            s += "⌘"
        }
        s += KeyCodeMap.string(for: keyCode)
        return s
    }

    /// NSEvent-compatible modifier flags (deviceIndependentFlagsMask space).
    public var eventModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if carbonModifiers & CarbonModifiers.control != 0 {
            flags |= UInt32(NSEvent.ModifierFlags.control.rawValue)
        }
        if carbonModifiers & CarbonModifiers.option != 0 {
            flags |= UInt32(NSEvent.ModifierFlags.option.rawValue)
        }
        if carbonModifiers & CarbonModifiers.shift != 0 {
            flags |= UInt32(NSEvent.ModifierFlags.shift.rawValue)
        }
        if carbonModifiers & CarbonModifiers.command != 0 {
            flags |= UInt32(NSEvent.ModifierFlags.command.rawValue)
        }
        return flags
    }
}

/// Virtual key code helpers (ANSI keys, enough for hotkey defaults/recorders).
public enum KeyCodeMap {
    static let ansiTable: [Int: String] = [
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    public static func string(for keyCode: UInt32) -> String {
        ansiTable[Int(keyCode)] ?? "Key \(keyCode)"
    }

    /// True if the key code is one we can represent/record.
    public static func isKnown(_ keyCode: UInt32) -> Bool {
        ansiTable[Int(keyCode)] != nil
    }

    /// Best-effort mapping from a typed character to a virtual key code (ANSI layout).
    public static func keyCode(for character: Character) -> UInt32? {
        guard let entry = ansiTable.first(where: { $0.value == String(character).uppercased() }) else { return nil }
        return UInt32(exactly: entry.key)
    }
}
