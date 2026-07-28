import AppKit
import Combine
import EventKit
import SwiftUI
import UserNotifications

@MainActor
final class CalendarModel: ObservableObject {
    static let shared = CalendarModel()

    @Published private(set) var menuBarTitle: String = ""
    @Published private(set) var accessDenied = false
    @Published private(set) var upcoming: UpcomingEvent?
    @Published private(set) var selectedDayEvents: [EKEvent] = []
    @Published private(set) var daysWithEvents: Set<Date> = []

    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, inSameDayAs: oldValue) else { return }
            if !calendar.isDate(selectedDate, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = selectedDate
            }
            loadSelectedDay()
        }
    }

    @Published private(set) var visibleMonth: Date {
        didSet { loadMonth() }
    }

    // MARK: - Menu bar content settings

    @Published var showWeekday: Bool {
        didSet { persist(showWeekday, forKey: SettingsKey.showWeekday) }
    }

    @Published var showDate: Bool {
        didSet { persist(showDate, forKey: SettingsKey.showDate) }
    }

    @Published var showMeeting: Bool {
        didSet { persist(showMeeting, forKey: SettingsKey.showMeeting) }
    }

    @Published var meetingTitleLength: Int {
        didSet {
            UserDefaults.standard.set(meetingTitleLength, forKey: SettingsKey.meetingTitleLength)
            refreshUpcoming()
        }
    }

    /// How long before a meeting its notification fires; `-1` turns notifications off.
    @Published var notificationLeadSeconds: Int {
        didSet {
            UserDefaults.standard.set(notificationLeadSeconds, forKey: SettingsKey.notificationLead)
            if notificationLeadSeconds >= 0 {
                // First enable is what triggers the macOS permission prompt.
                Task {
                    notificationStatus = await notifier.ensureAuthorization()
                    scheduleNotifications()
                }
            } else {
                scheduleNotifications()
            }
        }
    }

    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    /// Set by the menu bar's "Settings…" item so the popover opens straight into settings.
    @Published var settingsRequested = false

    private enum SettingsKey {
        static let showWeekday = "showWeekday"
        static let showDate = "showDate"
        static let showMeeting = "showMeeting"
        static let meetingTitleLength = "meetingTitleLength"
        static let notificationLead = "notificationLeadSeconds"
    }

    let calendar = Calendar.current

    private let store = EKEventStore()
    private let notifier = MeetingNotifier()
    private var accessGranted = false
    private var timer: Timer?
    private var dismissedEventIDs: Set<String> = []

    private init() {
        let today = Date()
        showWeekday = Self.flag(SettingsKey.showWeekday)
        showDate = Self.flag(SettingsKey.showDate)
        showMeeting = Self.flag(SettingsKey.showMeeting)
        let storedLength = UserDefaults.standard.object(forKey: SettingsKey.meetingTitleLength)
        meetingTitleLength = (storedLength as? Int) ?? 15
        let storedLead = UserDefaults.standard.object(forKey: SettingsKey.notificationLead)
        notificationLeadSeconds = (storedLead as? Int) ?? -1
        selectedDate = today
        visibleMonth = today
        menuBarTitle = MenuBarLabel.text(
            now: today, upcoming: nil, calendar: calendar, options: labelOptions
        )
    }

    /// Settings default to on until the user has touched them.
    private static func flag(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    private func persist(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        refreshUpcoming()
    }

    private var labelOptions: MenuBarLabel.Options {
        MenuBarLabel.Options(
            showWeekday: showWeekday,
            showDate: showDate,
            showMeeting: showMeeting,
            titleLimit: meetingTitleLength
        )
    }

    // MARK: - Lifecycle

    func start() {
        Task { await requestAccess() }
        notifier.prepare()
        refreshNotificationStatus()

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshUpcoming() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func requestAccess() async {
        if DemoData.isActive {
            accessGranted = true
            accessDenied = false
            reload()
            return
        }
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        accessGranted = granted
        accessDenied = !granted
        reload()
    }

    func reload() {
        // Nudge CalendarAgent to re-sync remote accounts (Google etc.); the
        // EKEventStoreChanged notification reloads us again when data arrives.
        store.refreshSourcesIfNecessary()
        refreshUpcoming()
        loadMonth()
        loadSelectedDay()
        scheduleNotifications()
        refreshNotificationStatus()
    }

    private func refreshNotificationStatus() {
        Task { notificationStatus = await notifier.authorizationStatus() }
    }

    private func scheduleNotifications() {
        guard !DemoData.isActive else { return }
        let now = Date()
        guard let horizon = calendar.date(byAdding: .hour, value: 24, to: now) else { return }
        notifier.schedule(
            events: events(from: now, to: horizon).filter { !$0.isAllDay },
            lead: TimeInterval(notificationLeadSeconds)
        )
    }

    func sendTestNotification() {
        notifier.sendTest(lead: TimeInterval(notificationLeadSeconds))
    }

    // MARK: - Navigation

    func showPreviousMonth() { shiftMonth(by: -1) }
    func showNextMonth() { shiftMonth(by: 1) }

    func showToday() {
        let today = Date()
        visibleMonth = today
        selectedDate = today
    }

    private func shiftMonth(by months: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        visibleMonth = shifted
    }

    // MARK: - Loading

    private func refreshUpcoming() {
        let now = Date()
        upcoming = accessGranted ? nextEvent(after: now) : nil
        menuBarTitle = MenuBarLabel.text(
            now: now, upcoming: upcoming, calendar: calendar, options: labelOptions
        )
    }

    private func nextEvent(after now: Date) -> UpcomingEvent? {
        guard let horizon = calendar.date(byAdding: .hour, value: 24, to: now) else { return nil }
        let candidate = events(from: now, to: horizon)
            .filter { !$0.isAllDay && $0.endDate > now && !dismissedEventIDs.contains(eventKey($0)) }
            .min { $0.startDate < $1.startDate }
        guard let candidate else { return nil }
        return UpcomingEvent(
            id: eventKey(candidate),
            title: candidate.title ?? "Untitled",
            start: candidate.startDate,
            end: candidate.endDate,
            link: MeetingLink.detect(in: candidate)
        )
    }

    /// Occurrence key that also works for unsaved demo events, which have no identifier.
    private func eventKey(_ event: EKEvent) -> String {
        "\(event.eventIdentifier ?? event.title ?? "")-\(event.startDate.timeIntervalSince1970)"
    }

    private func loadSelectedDay() {
        let start = calendar.startOfDay(for: selectedDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        selectedDayEvents = events(from: start, to: end).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            return lhs.startDate < rhs.startDate
        }
    }

    private func loadMonth() {
        guard let month = calendar.dateInterval(of: .month, for: visibleMonth) else { return }
        // Include the padding days the grid shows so their dots are correct too.
        let start = calendar.date(byAdding: .day, value: -7, to: month.start) ?? month.start
        let end = calendar.date(byAdding: .day, value: 14, to: month.end) ?? month.end
        daysWithEvents = Set(events(from: start, to: end).map { calendar.startOfDay(for: $0.startDate) })
    }

    private func events(from start: Date, to end: Date) -> [EKEvent] {
        guard accessGranted else { return [] }
        if DemoData.isActive {
            return DemoData.events(from: start, to: end, store: store, calendar: calendar)
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    // MARK: - Queries used by the views

    func hasEvents(on day: Date) -> Bool {
        daysWithEvents.contains(calendar.startOfDay(for: day))
    }

    func link(for event: EKEvent) -> URL? { MeetingLink.detect(in: event) }

    // MARK: - Actions

    /// Hides the currently running meeting from the menu bar so the next one shows instead.
    func dismissCurrentMeeting() {
        guard let upcoming, upcoming.start <= Date() else { return }
        dismissedEventIDs.insert(upcoming.id)
        refreshUpcoming()
    }

    func open(_ url: URL) { NSWorkspace.shared.open(url) }

    func openNotificationSettings() {
        let pane = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        guard let url = URL(string: "\(pane)?id=com.yannickpulver.brief") else { return }
        NSWorkspace.shared.open(url)
    }

    func openCalendarApp() {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    func openPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func quit() { NSApplication.shared.terminate(nil) }
}
