import AppKit

enum DestinationPicker {
    static func show(completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Choose screenshot destination"
        alert.informativeText = "Chlorophyll will use this destination once for this capture."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Save to File")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            completion("clipboard")
        case .alertSecondButtonReturn:
            completion("file")
        default:
            break
        }
    }
}
