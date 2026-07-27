import AppKit
import EventKit
import UserNotifications

private enum NotificationID {
    static let category = "MEETING"
    static let joinAction = "JOIN"
    static let linkKey = "link"
    static let test = "brief-test"
}

/// Reminds about meetings that have a joinable video link, shortly before they start.
@MainActor
final class MeetingNotifier: NSObject {
    private static let options: UNAuthorizationOptions = [.alert, .sound]

    private let center = UNUserNotificationCenter.current()

    /// Called once at startup: wires up delegate and category WITHOUT prompting.
    /// The permission prompt only appears once the user enables notifications.
    func prepare() {
        configure()
    }

    /// Prompts on first call (no-op afterwards) and reports the resulting status.
    func ensureAuthorization() async -> UNAuthorizationStatus {
        configure()
        _ = try? await center.requestAuthorization(options: Self.options)
        return await authorizationStatus()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces the pending reminders with ones for `events`, so meetings that moved
    /// or were deleted don't leave a stale banner behind. A negative `lead` means off.
    func schedule(events: [EKEvent], lead: TimeInterval) {
        guard lead >= 0 else {
            center.removeAllPendingNotificationRequests()
            return
        }
        let cutoff = Date().addingTimeInterval(lead)
        let requests = events.compactMap { event -> UNNotificationRequest? in
            guard !event.isAllDay, event.startDate > cutoff,
                  let link = MeetingLink.detect(in: event) else { return nil }
            return request(for: event, link: link, lead: lead)
        }
        Task { await apply(requests) }
    }

    /// Delivers a banner right away so the user can see what a reminder looks like.
    func sendTest(lead: TimeInterval) {
        configure()
        let content = UNMutableNotificationContent()
        content.title = "Brief test"
        content.body = Self.body(lead: lead)
        content.sound = .default
        content.categoryIdentifier = NotificationID.category
        let request = UNNotificationRequest(
            identifier: NotificationID.test, content: content, trigger: nil
        )
        Task {
            // Ask up front, so the test still lands if the user was never prompted.
            _ = try? await center.requestAuthorization(options: Self.options)
            try? await center.add(request)
        }
    }

    private func configure() {
        center.delegate = self
        let join = UNNotificationAction(
            identifier: NotificationID.joinAction, title: "Join", options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: NotificationID.category,
                actions: [join],
                intentIdentifiers: []
            )
        ])
    }

    private func apply(_ requests: [UNNotificationRequest]) async {
        let wanted = Set(requests.map(\.identifier))
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { !wanted.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        for request in requests {
            try? await center.add(request)
        }
    }

    private func request(for event: EKEvent, link: URL, lead: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = event.title ?? "Untitled"
        content.body = Self.body(lead: lead)
        content.sound = .default
        content.categoryIdentifier = NotificationID.category
        content.userInfo = [NotificationID.linkKey: link.absoluteString]

        let fireDate = event.startDate.addingTimeInterval(-lead)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate
        )

        return UNNotificationRequest(
            identifier: identifier(for: event),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private static func body(lead: TimeInterval) -> String {
        let seconds = Int(lead)
        guard seconds > 0 else { return "Starting now" }
        guard seconds >= 60 else { return "Starts in \(seconds) seconds" }
        let minutes = seconds / 60
        return "Starts in \(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    /// Stable per occurrence, so re-scheduling replaces a request instead of duplicating it.
    private func identifier(for event: EKEvent) -> String {
        let base = event.eventIdentifier ?? event.calendarItemIdentifier
        return "\(base)-\(Int(event.startDate.timeIntervalSince1970))"
    }
}

extension MeetingNotifier: UNUserNotificationCenterDelegate {
    /// Banners are worth showing even while Brief itself is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Both the Join action and a plain click on the banner open the meeting.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let opensMeeting = response.actionIdentifier == NotificationID.joinAction
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let link = (response.notification.request.content.userInfo[NotificationID.linkKey] as? String)
            .flatMap { URL(string: $0) }
        if opensMeeting, let link {
            MainActor.assumeIsolated { _ = NSWorkspace.shared.open(link) }
        }
        completionHandler()
    }
}
