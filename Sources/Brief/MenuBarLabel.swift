import Foundation

/// The next meeting, reduced to what the menu bar needs.
struct UpcomingEvent {
    let title: String
    let start: Date
    let end: Date
    let link: URL?
}

/// Pure formatting of the menu bar string, kept free of EventKit so it stays easy to reason about.
enum MenuBarLabel {
    /// How far ahead an event may start and still show up in the menu bar.
    static let menuBarLookahead: TimeInterval = 4 * 60 * 60

    /// Which parts of the label the user wants to see.
    struct Options {
        var showWeekday = true
        var showDate = true
        var showMeeting = true
        var titleLimit = 15

        static let `default` = Options()
    }

    static func text(
        now: Date,
        upcoming: UpcomingEvent?,
        calendar: Calendar = .current,
        options: Options = .default
    ) -> String {
        var parts: [String] = []
        if let datePart = datePart(now: now, calendar: calendar, options: options) {
            parts.append(datePart)
        }
        if options.showMeeting, let upcoming, let countdown = countdown(from: now, to: upcoming) {
            parts.append("\(countdown) \(truncate(upcoming.title, limit: options.titleLimit))")
        }
        // Never let the pill go empty: fall back to the plain date.
        guard !parts.isEmpty else { return formatted(now, format: dateFormat, calendar: calendar) }
        return parts.joined(separator: " | ")
    }

    /// `nil` when the event is over or too far out to be worth showing.
    /// Running events show the time remaining instead of a countdown to start.
    static func countdown(from now: Date, to event: UpcomingEvent) -> String? {
        if event.end <= now { return nil }
        if event.start <= now { return "-\(duration(event.end.timeIntervalSince(now)))" }
        let seconds = event.start.timeIntervalSince(now)
        guard seconds <= menuBarLookahead else { return nil }
        return duration(seconds)
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    static func truncate(_ title: String, limit: Int) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return trimmed.prefix(limit) + "…"
    }

    private static let weekdayFormat = "EEE"
    private static let dateFormat = "d MMM"

    private static func datePart(now: Date, calendar: Calendar, options: Options) -> String? {
        var formats: [String] = []
        if options.showWeekday { formats.append(weekdayFormat) }
        if options.showDate { formats.append(dateFormat) }
        guard !formats.isEmpty else { return nil }
        return formatted(now, format: formats.joined(separator: ", "), calendar: calendar)
    }

    private static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
