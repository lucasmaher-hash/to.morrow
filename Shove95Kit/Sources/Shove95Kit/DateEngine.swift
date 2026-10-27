import Foundation

/// Pure date logic (PRD §3). Every function takes `now` and `calendar`
/// explicitly — no hidden `Date()` or `Calendar.current` anywhere, so all of
/// it is deterministic under test. The app injects real values at the
/// TaskStore boundary only.
///
/// Core invariant: tabs are TOTAL filters over `dueDate`. Every task maps to
/// exactly one bucket at every moment — nothing can ever become invisible.
/// `weekHorizon` is used only for date *assignment* (swipe-to-Week), never as
/// an upper bound on the Week filter.
public enum DateEngine {

    // MARK: - Day boundaries

    public static func startOfToday(now: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: now)
    }

    public static func startOfTomorrow(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfToday(now: now, calendar: calendar))!
    }

    public static func startOfDayAfterTomorrow(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 2, to: startOfToday(now: now, calendar: calendar))!
    }

    // MARK: - Bucketing (total mapping)

    /// Which tab a task with this `dueDate` belongs to. Total: never returns
    /// "nothing". Past dates fall into `.today` — that IS the overdue
    /// roll-forward; there is no rollover job (PRD §3).
    public static func bucket(for dueDate: Date?, now: Date, calendar: Calendar) -> Bucket {
        guard let dueDate else { return .general }
        if dueDate < startOfTomorrow(now: now, calendar: calendar) { return .today }
        if dueDate < startOfDayAfterTomorrow(now: now, calendar: calendar) { return .tomorrow }
        // Anything further out reports General and KEEPS its date — the tab is
        // gone, the day is not (founder direction 2026-08-17). Its chip still
        // names the weekday, and it walks into Tomorrow and Today on its own.
        return .general
    }

    /// The date a task receives when moved to `bucket` (PRD §3).
    public static func targetDate(for bucket: Bucket, now: Date, calendar: Calendar) -> Date? {
        switch bucket {
        case .today: startOfToday(now: now, calendar: calendar)
        case .tomorrow: startOfTomorrow(now: now, calendar: calendar)
        case .general: nil
        }
    }

    // MARK: - Task state

    /// Overdue = dated in the past AND not done (PRD Q2). Completed tasks are
    /// never overdue.
    public static func isOverdue(dueDate: Date?, isCompleted: Bool, now: Date, calendar: Calendar) -> Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < startOfToday(now: now, calendar: calendar)
    }

    /// Archive rule (PRD §3): a completed *dated* task leaves its list at the
    /// first midnight after completion; a completed *General* task leaves 24h
    /// after completion.
    public static func isArchived(
        dueDate: Date?, isCompleted: Bool, completedAt: Date?, now: Date, calendar: Calendar
    ) -> Bool {
        guard isCompleted, let completedAt else { return false }
        if dueDate != nil {
            return completedAt < startOfToday(now: now, calendar: calendar)
        }
        return now.timeIntervalSince(completedAt) >= 24 * 60 * 60
    }

    /// Visibility in a tab: matches the bucket filter and is not archived.
    public static func isVisible(
        in tab: Bucket, dueDate: Date?, isCompleted: Bool, completedAt: Date?,
        now: Date, calendar: Calendar
    ) -> Bool {
        bucket(for: dueDate, now: now, calendar: calendar) == tab
            && !isArchived(dueDate: dueDate, isCompleted: isCompleted,
                           completedAt: completedAt, now: now, calendar: calendar)
    }
}

// MARK: - TaskItem conveniences (thin forwarding — logic stays above)

extension TaskItem {
    public func bucket(now: Date, calendar: Calendar) -> Bucket {
        DateEngine.bucket(for: dueDate, now: now, calendar: calendar)
    }

    public func isOverdue(now: Date, calendar: Calendar) -> Bool {
        DateEngine.isOverdue(dueDate: dueDate, isCompleted: isCompleted, now: now, calendar: calendar)
    }

    public func isArchived(now: Date, calendar: Calendar) -> Bool {
        // A ticked live note archives AT ONCE. The grace period exists so a
        // task you just ticked stays visible in the list where you ticked it;
        // a live note has no such list, and its box empties the moment it is
        // done. Without this it spent a day in nowhere — gone from Live, in no
        // tab, and not yet in the archive.
        if isLiveNote { return isCompleted && completedAt != nil }
        return DateEngine.isArchived(dueDate: dueDate, isCompleted: isCompleted,
                              completedAt: completedAt, now: now, calendar: calendar)
    }

    public func isVisible(in tab: Bucket, now: Date, calendar: Calendar) -> Bool {
        // The live note belongs to no tab — see `TaskItem.isLiveNote`. This is
        // the single place the total mapping is broken, on purpose and in one
        // line, so nothing else has to know.
        guard !isLiveNote else { return false }
        return DateEngine.isVisible(in: tab, dueDate: dueDate, isCompleted: isCompleted,
                             completedAt: completedAt, now: now, calendar: calendar)
    }
}
