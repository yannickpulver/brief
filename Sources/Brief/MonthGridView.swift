import SwiftUI

struct MonthGridView: View {
    @ObservedObject var model: CalendarModel

    var body: some View {
        VStack(spacing: 3) {
            header
            weekdayHeader
            VStack(spacing: 1) {
                ForEach(weeks, id: \.self) { week in
                    HStack(spacing: 1) {
                        ForEach(week, id: \.self) { day in
                            dayCell(day)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 12, weight: .semibold))
                .padding(.leading, 4)
            Spacer()
            Button(action: model.showPreviousMonth) {
                Image(systemName: "chevron.left")
                    .frame(width: 16, height: 16)
            }
            .help("Previous month")
            Button(action: model.showToday) {
                Circle()
                    .frame(width: 6, height: 6)
                    .frame(width: 16, height: 16)
            }
            .help("Today")
            Button(action: model.showNextMonth) {
                Image(systemName: "chevron.right")
                    .frame(width: 16, height: 16)
            }
            .help("Next month")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .font(.system(size: 12, weight: .semibold))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 1) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let calendar = model.calendar
        let isSelected = calendar.isDate(day, inSameDayAs: model.selectedDate)
        let isToday = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: model.visibleMonth, toGranularity: .month)

        return Button {
            model.selectedDate = day
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .monospacedDigit()
                Circle()
                    .frame(width: 2.5, height: 2.5)
                    .opacity(model.hasEvents(on: day) ? 1 : 0)
            }
            .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday, inMonth: inMonth))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 18)
            .background(background(isSelected: isSelected, isToday: isToday))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func foreground(isSelected: Bool, isToday: Bool, inMonth: Bool) -> some ShapeStyle {
        if isSelected { return AnyShapeStyle(.white) }
        if isToday { return AnyShapeStyle(Color.accentColor) }
        return AnyShapeStyle(inMonth ? Color.primary : Color.secondary.opacity(0.5))
    }

    @ViewBuilder
    private func background(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
        } else if isToday {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = model.calendar
        formatter.locale = model.calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: model.visibleMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.veryShortStandaloneWeekdaySymbols
        let offset = model.calendar.firstWeekday - 1
        return (0..<symbols.count).map { symbols[($0 + offset) % symbols.count] }
    }

    /// Six fixed weeks so the popover height never jumps between months.
    private var days: [Date] {
        let calendar = model.calendar
        guard let month = calendar.dateInterval(of: .month, for: model.visibleMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: month.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -leading, to: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weeks: [[Date]] {
        let days = self.days
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }
}
