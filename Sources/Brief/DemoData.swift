import AppKit
import EventKit

/// Fake events for screenshots: `open Brief.app --args --demo`.
/// Nothing is saved to the event store.
enum DemoData {
    static var isActive: Bool { CommandLine.arguments.contains("--demo") }

    static func events(from start: Date, to end: Date, store: EKEventStore, calendar: Calendar) -> [EKEvent] {
        var result: [EKEvent] = []
        var day = calendar.startOfDay(for: start)
        while day < end {
            if !calendar.isDateInWeekend(day) {
                result += events(on: day, store: store, calendar: calendar)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result.filter { $0.startDate < end && $0.endDate > start }
    }

    private static func events(on day: Date, store: EKEventStore, calendar: Calendar) -> [EKEvent] {
        func event(_ title: String, _ startHour: Int, _ startMinute: Int, _ minutes: Int,
                   link: String? = nil, in cal: EKCalendar) -> EKEvent {
            let event = EKEvent(eventStore: store)
            event.title = title
            event.calendar = cal
            event.startDate = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day)
            event.endDate = event.startDate.addingTimeInterval(TimeInterval(minutes * 60))
            if let link { event.url = URL(string: link) }
            return event
        }

        let calendars = demoCalendars(store: store)
        var events = [
            event("Run", 8, 0, 45, in: calendars[3]),
            event("Coffee Time", 9, 0, 30, in: calendars[2]),
            event("Team Lunch", 12, 0, 60, in: calendars[0]),
            event("Bookclub", 19, 0, 60, link: "https://meet.google.com/abc-defg-hij", in: calendars[1]),
            event("Iceland planning", 20, 0, 60, link: "https://zoom.us/j/123456789", in: calendars[3]),
        ]
        if calendar.component(.day, from: day) % 7 == 0 {
            let birthday = EKEvent(eventStore: store)
            birthday.title = "Jamie's birthday"
            birthday.calendar = calendars[2]
            birthday.isAllDay = true
            birthday.startDate = day
            birthday.endDate = calendar.date(byAdding: .day, value: 1, to: day)
            events.insert(birthday, at: 0)
        }
        return events
    }

    private static var cached: [EKCalendar]?

    private static func demoCalendars(store: EKEventStore) -> [EKCalendar] {
        if let cached { return cached }
        let colors: [(String, NSColor)] = [
            ("Work", .systemBlue), ("Design", .systemPurple),
            ("Personal", .systemOrange), ("Projects", .systemTeal),
        ]
        let calendars = colors.map { name, color in
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = name
            calendar.cgColor = color.cgColor
            return calendar
        }
        cached = calendars
        return calendars
    }
}
