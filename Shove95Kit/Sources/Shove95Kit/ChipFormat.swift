import Foundation

/// Overdue date-chip labels (PRD §3, design.md §5).
///
/// HOW OLD, not which weekday (founder direction 2026-08-17). "Wed" told you
/// when the task was due and left you to work out what that meant; "3 Days"
/// is the thing you actually wanted to know, and it does not need a calendar
/// in your head. The chip was already counting for anything a week or more
/// overdue — this makes it count all the way down.
///
/// Locale-independent by design, like the day headings: the chip is a factual
/// marker, and one that changed width with the system language would reflow
/// every row it sits in.
public enum ChipFormat {
    /// Label for an overdue task's chip, or nil when the task isn't overdue.
    public static func label(dueDate: Date?, isCompleted: Bool, now: Date, calendar: Calendar) -> String? {
        guard DateEngine.isOverdue(dueDate: dueDate, isCompleted: isCompleted, now: now, calendar: calendar),
              let dueDate else { return nil }
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = DateEngine.startOfToday(now: now, calendar: calendar)
        let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
        return days == 1 ? "1 Day" : "\(days) Days"
    }
}

/// Day headings for the Soon tab: "Fri 14 Apr".
///
/// The weekday says how far away it FEELS and the date says exactly when —
/// the founder asked for both (2026-08-17). Locale-independent like the
/// chips, and for the same reason: these are factual markers, and a heading
/// that changes width with the system language would reflow the whole list.
public enum DayHeading {
    private static let weekdays = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// These names are GREGORIAN, so the components that index them have to be
    /// Gregorian too — read through the user's calendar they were both wrong
    /// and unsafe. A Hebrew, Coptic or Ethiopic calendar reaches month 13,
    /// which ran straight off the end of a 13-element table and crashed the
    /// Soon tab (found in review 2026-08-26); short of that it simply printed
    /// the wrong month, since Hebrew month 5 is not May.
    ///
    /// The TIME ZONE still comes from the caller's calendar: which day a date
    /// falls on is a question about where the reader is, and only the naming
    /// is fixed.
    public static func naming(_ calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian
    }

    public static func label(for day: Date, calendar: Calendar) -> String {
        let parts = naming(calendar).dateComponents([.weekday, .day, .month], from: day)
        // Indexed defensively as well as corrected above: a label is not worth
        // a crash under any component this table has not anticipated.
        let weekday = weekdays.indices.contains(parts.weekday ?? 1) ? weekdays[parts.weekday ?? 1] : ""
        let month = months.indices.contains(parts.month ?? 1) ? months[parts.month ?? 1] : ""
        return "\(weekday) \(parts.day ?? 1) \(month)"
    }
}


/// One month as a flat run of cells, `nil` where the grid is empty.
///
/// Monday-first. `weekday` is 1 = Sunday, so the shift is +5 mod 7: Monday's 2
/// becomes 0 and Sunday's 1 becomes 6. Leading blanks put the 1st under its
/// own weekday; trailing ones are dropped, because a row of nothing at the
/// bottom is just a gap.
public enum MonthGrid {
    public static func cells(for month: Date, calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: month) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        return cells
    }
}
