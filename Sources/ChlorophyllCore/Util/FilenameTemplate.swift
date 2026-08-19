import Foundation

/// Renders Greenshot-style filename templates.
///
/// Supported tokens:
/// - `${YYYY}`, `${MM}`, `${DD}` — date parts
/// - `${hh}`, `${mm}`, `${ss}` — time parts
/// - `${title}` — window title (sanitized, may be empty)
/// - `${n}` — incrementing counter
/// - `${w}`, `${h}` — image dimensions in pixels
public enum FilenameTemplate {
    public static func render(
        _ pattern: String,
        date: Date = Date(),
        title: String = "",
        counter: Int = 1,
        size: CGSize? = nil
    ) -> String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let tokens: [String: String] = [
            "YYYY": String(format: "%04d", comps.year ?? 0),
            "MM": String(format: "%02d", comps.month ?? 0),
            "DD": String(format: "%02d", comps.day ?? 0),
            "hh": String(format: "%02d", comps.hour ?? 0),
            "mm": String(format: "%02d", comps.minute ?? 0),
            "ss": String(format: "%02d", comps.second ?? 0),
            "title": sanitize(title),
            "n": String(max(counter, 1)),
            "NUM": String(format: "%04d", max(counter, 1)),
            "w": size.map { String(Int($0.width)) } ?? "",
            "h": size.map { String(Int($0.height)) } ?? ""
        ]

        var result = pattern
        for (token, value) in tokens.sorted(by: { $0.key.count > $1.key.count }) {
            result = result.replacingOccurrences(of: "${\(token)}", with: value)
        }
        return sanitize(result)
    }

    /// Removes characters that are problematic in filenames and strips leading/trailing
    /// whitespace and dots (hidden-file guard). Truncates to a sane length.
    public static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var result = String(cleaned.prefix(180))
        while result.hasSuffix(".") {
            result.removeLast()
        }
        return result
    }
}
