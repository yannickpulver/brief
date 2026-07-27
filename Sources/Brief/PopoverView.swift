import SwiftUI
import UserNotifications

struct PopoverView: View {
    @ObservedObject var model: CalendarModel

    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showingSettings {
                settings
            } else {
                if model.accessDenied {
                    accessDeniedBanner
                } else if let upcoming = model.upcoming, let link = upcoming.link {
                    JoinBanner(event: upcoming, link: link) { model.open($0) }
                }

                HStack(alignment: .top, spacing: 6) {
                    MonthGridView(model: model)
                        .frame(width: 162)
                    Divider()
                    EventListView(model: model)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }

            Divider()
            footer
        }
        .frame(width: 340)
        .background(.regularMaterial)
        .onChange(of: model.settingsRequested, initial: true) {
            guard model.settingsRequested else { return }
            showingSettings = true
            model.settingsRequested = false
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: model.openCalendarApp) {
                Image(systemName: "calendar")
            }
            .help("Open Calendar")
            Button { showingSettings.toggle() } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
            }
            .help("Settings")
            Button("Quit", action: model.quit)
        }
        .buttonStyle(.accessoryBar)
        .font(.system(size: 10))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button {
                    showingSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.accessoryBar)
                .help("Back")
                Text("Settings")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            settingsSection("Menu bar") {
                toggleRow("Show weekday", isOn: $model.showWeekday)
                toggleRow("Show date", isOn: $model.showDate)
            }

            settingsSection("Next meeting") {
                toggleRow("Show next meeting", isOn: $model.showMeeting)
                HStack(spacing: 6) {
                    Text("Meeting title max length")
                    Spacer()
                    Text("\(model.meetingTitleLength)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.meetingTitleLength, in: 5...40)
                        .labelsHidden()
                }
                .disabled(!model.showMeeting)
                .opacity(model.showMeeting ? 1 : 0.5)
            }

            settingsSection("Notifications") {
                toggleRow("Notifications", isOn: notificationsEnabled)

                Group {
                    HStack(spacing: 6) {
                        Text("Notify before meeting")
                        Spacer()
                        Picker("Notify before meeting", selection: notificationLead) {
                            Text("At start").tag(0)
                            Text("30 seconds").tag(30)
                            Text("1 minute").tag(60)
                            Text("5 minutes").tag(300)
                            Text("10 minutes").tag(600)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(notificationStatusColor)
                            .frame(width: 6, height: 6)
                        Text(notificationStatusLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Test", action: model.sendTestNotification)
                        Button("System Settings…", action: model.openNotificationSettings)
                    }
                    .controlSize(.small)
                    .font(.system(size: 11))
                }
                .disabled(!notificationsEnabled.wrappedValue)
                .opacity(notificationsEnabled.wrappedValue ? 1 : 0.5)
            }
        }
        .font(.system(size: 12))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    /// The lead value doubles as the on/off state: `-1` is off, re-enabling defaults to 30 s.
    private var notificationsEnabled: Binding<Bool> {
        Binding(
            get: { model.notificationLeadSeconds >= 0 },
            set: { model.notificationLeadSeconds = $0 ? 30 : -1 }
        )
    }

    private var notificationLead: Binding<Int> {
        Binding(
            get: { max(model.notificationLeadSeconds, 0) },
            set: { model.notificationLeadSeconds = $0 }
        )
    }

    private var notificationStatusLabel: String {
        switch model.notificationStatus {
        case .authorized, .provisional: "Notification access granted"
        case .denied: "Notification access denied — allow it in System Settings"
        default: "Permission is requested when you pick a time"
        }
    }

    private var notificationStatusColor: Color {
        switch model.notificationStatus {
        case .authorized, .provisional: .green
        case .denied: .red
        default: .secondary
        }
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 7) {
                content()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
        }
    }

    private var accessDeniedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No calendar access", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Brief needs full calendar access to show your meetings.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Open Privacy Settings", action: model.openPrivacySettings)
                .font(.system(size: 11))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12))
    }
}

private struct JoinBanner: View {
    let event: UpcomingEvent
    let link: URL
    let open: (URL) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "video.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(startsIn)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Join") { open(link) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.12))
    }

    private var startsIn: String {
        let now = Date()
        if event.start <= now { return "In progress" }
        guard let countdown = MenuBarLabel.countdown(from: now, to: event) else {
            return "Starts \(event.start.formatted(date: .omitted, time: .shortened))"
        }
        return "Starts in \(countdown)"
    }
}
