import EventKit
import SwiftUI

struct EventListView: View {
    @ObservedObject var model: CalendarModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if model.selectedDayEvents.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.selectedDayEvents, id: \.self) { event in
                            EventRow(
                                event: event,
                                link: model.link(for: event),
                                hidesTitle: model.hidesTitle(of: event)
                            ) { model.open($0) }
                                .id(event)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            // The edge fades already signal scrolling; a scroller would eat row width.
            .scrollIndicators(.never)
            .onAppear { scrollToCurrent(proxy, animated: false) }
            .onChange(of: model.selectedDayEvents) { scrollToCurrent(proxy, animated: true) }
        }
        .frame(height: 200)
        // Fade both edges so a partially visible row reads as
        // "scroll for more" instead of clipped text.
        .mask(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 6)
                Rectangle()
                LinearGradient(
                    colors: [.black, .clear], startPoint: .top, endPoint: .bottom
                )
                .frame(height: 14)
            }
        )
    }

    /// Puts the running or next timed event at the top; all-day events don't
    /// count as "next". Days that are over or not yet started stay at the first row.
    private func scrollToCurrent(_ proxy: ScrollViewProxy, animated: Bool) {
        let now = Date()
        let target = model.selectedDayEvents.first { !$0.isAllDay && $0.endDate > now }
            ?? model.selectedDayEvents.first
        guard let target else { return }
        // Defer until the popover has laid out, or the scroll is a no-op.
        DispatchQueue.main.async {
            if animated {
                withAnimation { proxy.scrollTo(target, anchor: .top) }
            } else {
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
            Text("No events")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}

extension View {
    /// Blurs a private event's text so it can't be read over the shoulder.
    func privateBlur(_ isBlurred: Bool) -> some View {
        blur(radius: isBlurred ? 4 : 0)
            .animation(.easeOut(duration: 0.2), value: isBlurred)
    }
}

private extension EKEvent {
    /// Finished events are dimmed and skipped when scrolling. An all-day event
    /// only counts as finished once its whole day is behind us.
    func isDone(at now: Date) -> Bool {
        guard !isAllDay else { return endDate < Calendar.current.startOfDay(for: now) }
        return endDate <= now
    }
}

private struct EventRow: View {
    let event: EKEvent
    let link: URL?
    let hidesTitle: Bool
    let open: (URL) -> Void

    /// A click reveals a blurred private title until the popover closes.
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)
            if event.isAllDay {
                title
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(timeRange)
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    title
                    if let room {
                        Label(room, systemImage: "mappin")
                            .labelStyle(RoomLabelStyle())
                            .privateBlur(isBlurred)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            Spacer(minLength: 4)
            if let link, !isDone {
                JoinButton(isLive: isSoon) { open(link) }
            }
        }
        .opacity(isDone ? 0.45 : 1)
        .padding(.vertical, event.isAllDay ? 3 : 4)
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(minHeight: event.isAllDay ? nil : 30)
        .background(
            RoundedRectangle(cornerRadius: 7).fill(accent.opacity(isDone ? 0.08 : 0.16))
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture { if hidesTitle { revealed.toggle() } }
        .help(isBlurred ? "Private – click to reveal" : "")
    }

    private var isBlurred: Bool { hidesTitle && !revealed }

    private var title: some View {
        Text(event.title ?? "Untitled")
            .font(.system(size: 11, weight: .medium))
            .lineLimit(event.isAllDay ? 1 : 2)
            .privateBlur(isBlurred)
    }

    private var isDone: Bool { event.isDone(at: Date()) }

    /// Running, or starting within ten minutes – same window as the Join banner.
    private var isSoon: Bool { !event.isAllDay && event.startDate.timeIntervalSinceNow <= 10 * 60 }

    private var accent: Color {
        let calendar: EKCalendar? = event.calendar
        guard let cgColor: CGColor = calendar?.cgColor else { return .accentColor }
        return Color(cgColor: cgColor)
    }

    /// The event's location, unless it's just the video-call link the Join button already covers.
    private var room: String? {
        let location = (event.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty, !location.lowercased().hasPrefix("http") else { return nil }
        return location
    }

    private var timeRange: String {
        let formatter = EventRow.timeFormatter
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }

    /// Icon and text set tight, so the pin reads as part of the room name.
    private struct RoomLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 2) {
                configuration.icon
                configuration.title
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
