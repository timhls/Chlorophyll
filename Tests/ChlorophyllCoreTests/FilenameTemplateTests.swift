@testable import ChlorophyllCore
import Foundation
import Testing

struct FilenameTemplateTests {
    private func makeDate() -> (Date, [String: String]) {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 20
        comps.hour = 14
        comps.minute = 5
        comps.second = 9
        let date = Calendar.current.date(from: comps)!
        let expected = [
            "YYYY": "2026", "MM": "08", "DD": "20",
            "hh": "14", "mm": "05", "ss": "09"
        ]
        return (date, expected)
    }

    @Test func dateTokens() {
        let (date, e) = makeDate()
        let result = FilenameTemplate.render("${YYYY}-${MM}-${DD} ${hh}-${mm}-${ss}", date: date)
        #expect(result == "\(e["YYYY"]!)-\(e["MM"]!)-\(e["DD"]!) \(e["hh"]!)-\(e["mm"]!)-\(e["ss"]!)")
    }

    @Test func counterTokens() {
        #expect(FilenameTemplate.render("shot_${n}", counter: 3) == "shot_3")
        #expect(FilenameTemplate.render("shot_${NUM}", counter: 3) == "shot_0003")
    }

    @Test func sizeTokens() {
        #expect(FilenameTemplate.render("${w}x${h}", size: CGSize(width: 800, height: 600)) == "800x600")
    }

    @Test func titleTokenIsSanitized() {
        #expect(FilenameTemplate.render("t-${title}", title: "a/b\\c") == "t-a-b-c")
    }

    @Test func sanitizeReplacesInvalidCharacters() {
        #expect(FilenameTemplate.sanitize("a/b\\c:d?e%f*g|h\"i<j>k") == "a-b-c-d-e-f-g-h-i-j-k")
    }

    @Test func sanitizeTrimsDotsAndSpaces() {
        #expect(FilenameTemplate.sanitize("  name... ") == "name")
    }

    @Test func sanitizeTruncatesLongStrings() {
        let long = String(repeating: "x", count: 500)
        #expect(FilenameTemplate.sanitize(long).count <= 180)
    }

    @Test func unknownTokensRemain() {
        #expect(FilenameTemplate.render("${nope}", counter: 1) == "${nope}")
    }
}
