import EventKit
import Foundation

/// Finds a joinable video-conference URL inside a calendar event.
enum MeetingLink {
    private static let providerPatterns = [
        #"https://[\w.-]*zoom\.us/[^\s<>"'\)\]]+"#,
        #"https://meet\.google\.com/[^\s<>"'\)\]]+"#,
        #"https://teams\.microsoft\.com/[^\s<>"'\)\]]+"#,
        #"https://teams\.live\.com/[^\s<>"'\)\]]+"#,
        #"https://[\w.-]*webex\.com/[^\s<>"'\)\]]+"#,
        #"https://[\w.-]*whereby\.com/[^\s<>"'\)\]]+"#,
        #"https://meet\.jit\.si/[^\s<>"'\)\]]+"#
    ]

    private static let regexes: [NSRegularExpression] = providerPatterns.compactMap {
        try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
    }

    static func detect(in event: EKEvent) -> URL? {
        let fields = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        for field in fields {
            if let url = firstProviderMatch(in: field) { return url }
        }
        if let url = event.url, url.scheme?.lowercased() == "https" { return url }
        return nil
    }

    static func firstProviderMatch(in text: String) -> URL? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for regex in regexes {
            guard let match = regex.firstMatch(in: text, range: range),
                  let matched = Range(match.range, in: text) else { continue }
            let trimmed = text[matched].trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            if let url = URL(string: trimmed) { return url }
        }
        return nil
    }
}
