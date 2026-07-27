import EventKit
import SwiftUI

struct EventListView: View {
    @ObservedObject var model: CalendarModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if model.selectedDayEvents.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.selectedDayEvents, id: \.self) { event in
                            EventRow(event: event, link: model.link(for: event)) { model.open($0) }
                                .id(event)
                        }
                    }
                }
                .padding(.trailing, 2)
                .padding(.bottom, 12)
            }
            .onAppear { scrollToCurrent(proxy, animated: false) }
            .onChange(of: model.selectedDayEvents) { scrollToCurrent(proxy, animated: true) }
        }
        .frame(height: 200)
        // Fade the bottom edge so a partially visible row reads as
        // "scroll for more" instead of clipped text.
        .mask(
            VStack(spacing: 0) {
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
    let open: (URL) -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)
            if event.isAllDay {
                title
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(timeRange)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    title
                }
            }
            Spacer(minLength: 4)
            if let link, !isDone {
                Button("Join") { open(link) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .opacity(isDone ? 0.45 : 1)
        .padding(.vertical, event.isAllDay ? 2 : 3)
        .padding(.horizontal, 5)
        .frame(minHeight: event.isAllDay ? nil : 27)
        .background(
            RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05))
        )
    }

    private var title: some View {
        Text(event.title ?? "Untitled")
            .font(.system(size: 11))
            .lineLimit(event.isAllDay ? 1 : 2)
    }

    private var isDone: Bool { event.isDone(at: Date()) }

    private var accent: Color {
        let calendar: EKCalendar? = event.calendar
        guard let cgColor: CGColor = calendar?.cgColor else { return .accentColor }
        return Color(cgColor: cgColor)
    }

    private var timeRange: String {
        let formatter = EventRow.timeFormatter
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
