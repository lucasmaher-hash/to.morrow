import Foundation
import Testing
@testable import Shove95Kit

/// Fixed calendar: gregorian, Europe/Berlin — deterministic regardless of the
/// machine running the tests. Reference week: Mon 2026-08-03 … Sun 2026-08-09.
enum Fixed {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return cal
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12, _ mm: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh, minute: mm))!
    }
}

@Suite("Bucketing (total mapping, overdue rolls forward)")
struct BucketingTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func nilDateIsGeneral() {
        #expect(DateEngine.bucket(for: nil, now: mondayNoon, calendar: cal) == .general)
    }

    @Test func todayTomorrowGeneralBoundaries() {
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 3, 0, 0), now: mondayNoon, calendar: cal) == .today)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 4, 0, 0), now: mondayNoon, calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 5, 0, 0), now: mondayNoon, calendar: cal) == .general)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 9, 0, 0), now: mondayNoon, calendar: cal) == .general)
    }

    @Test func pastDatesFallIntoToday() {
        // The overdue roll-forward IS the filter — no rollover job (PRD FR-001).
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 1, 0, 0), now: mondayNoon, calendar: cal) == .today)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 7, 1, 0, 0), now: mondayNoon, calendar: cal) == .today)
    }

    @Test func fiveDayGapShowsEverythingInToday() {
        let now = Fixed.date(2026, 8, 8) // closed Aug 3–7, reopened Sat Aug 8
        for day in 3...7 {
            #expect(DateEngine.bucket(for: Fixed.date(2026, 8, day, 0, 0), now: now, calendar: cal) == .today)
        }
    }

    @Test func midnightBoundaryFlipsTomorrowIntoToday() {
        let tuesday = Fixed.date(2026, 8, 4, 0, 0)
        #expect(DateEngine.bucket(for: tuesday, now: Fixed.date(2026, 8, 3, 23, 59), calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: tuesday, now: Fixed.date(2026, 8, 4, 0, 0), calendar: cal) == .today)
    }

    /// A date months out is still General, and still dated. Nothing can fall
    /// out of the tabs — the mapping stays total with three buckets.
    @Test func datesFarOutStayVisibleInGeneral() {
        // Total mapping: nothing can ever vanish (safety deviation noted in DateEngine).
        #expect(DateEngine.bucket(for: Fixed.date(2026, 9, 20, 0, 0), now: mondayNoon, calendar: cal) == .general)
    }

    @Test func saturdayTomorrowVsGeneralSplit() {
        let saturday = Fixed.date(2026, 8, 8)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 9, 0, 0), now: saturday, calendar: cal) == .tomorrow)
        #expect(DateEngine.bucket(for: Fixed.date(2026, 8, 10, 0, 0), now: saturday, calendar: cal) == .general)
    }
}

@Suite("Target dates for moves")
struct TargetDateTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func targets() {
        #expect(DateEngine.targetDate(for: .today, now: mondayNoon, calendar: cal) == Fixed.date(2026, 8, 3, 0, 0))
        #expect(DateEngine.targetDate(for: .tomorrow, now: mondayNoon, calendar: cal) == Fixed.date(2026, 8, 4, 0, 0))
        #expect(DateEngine.targetDate(for: .general, now: mondayNoon, calendar: cal) == nil)
    }
}

@Suite("Overdue")
struct OverdueTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test func pastAndUnfinishedIsOverdue() {
        #expect(DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: false, now: mondayNoon, calendar: cal))
    }

    @Test func completedIsNeverOverdue() {
        // The classic first-app bug, pinned (locked Q11).
        #expect(!DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: true, now: mondayNoon, calendar: cal))
    }

    @Test func todayAndGeneralAreNotOverdue() {
        #expect(!DateEngine.isOverdue(dueDate: Fixed.date(2026, 8, 3, 0, 0), isCompleted: false, now: mondayNoon, calendar: cal))
        #expect(!DateEngine.isOverdue(dueDate: nil, isCompleted: false, now: mondayNoon, calendar: cal))
    }
}

@Suite("Archive visibility")
struct ArchiveTests {
    let cal = Fixed.calendar

    @Test func datedTaskArchivesAtMidnightAfterCompletion() {
        let completedLateMonday = Fixed.date(2026, 8, 3, 23, 50)
        let due = Fixed.date(2026, 8, 3, 0, 0)
        // Still Monday → visible struck-through.
        #expect(!DateEngine.isArchived(dueDate: due, isCompleted: true, completedAt: completedLateMonday,
                                       now: Fixed.date(2026, 8, 3, 23, 59), calendar: cal))
        // Ten minutes later (Tuesday 00:10) → archived.
        #expect(DateEngine.isArchived(dueDate: due, isCompleted: true, completedAt: completedLateMonday,
                                      now: Fixed.date(2026, 8, 4, 0, 10), calendar: cal))
    }

    @Test func generalTaskArchivesAfter24Hours() {
        let completed = Fixed.date(2026, 8, 3, 10, 0)
        #expect(!DateEngine.isArchived(dueDate: nil, isCompleted: true, completedAt: completed,
                                       now: Fixed.date(2026, 8, 4, 9, 59), calendar: cal))
        #expect(DateEngine.isArchived(dueDate: nil, isCompleted: true, completedAt: completed,
                                      now: Fixed.date(2026, 8, 4, 10, 1), calendar: cal))
    }

    @Test func incompleteIsNeverArchived() {
        #expect(!DateEngine.isArchived(dueDate: nil, isCompleted: false, completedAt: nil,
                                       now: Fixed.date(2026, 8, 4), calendar: cal))
    }

    @Test func completedYesterdayDatedTaskInvisibleInToday() {
        // End-to-end visibility handoff (TASK-054 pre-check): completed-yesterday
        // dated task is archived, so not visible in Today despite matching the filter.
        let due = Fixed.date(2026, 8, 2, 0, 0)
        let completed = Fixed.date(2026, 8, 2, 18, 0)
        let now = Fixed.date(2026, 8, 3)
        #expect(DateEngine.bucket(for: due, now: now, calendar: cal) == .today)
        #expect(!DateEngine.isVisible(in: .today, dueDate: due, isCompleted: true,
                                      completedAt: completed, now: now, calendar: cal))
    }
}

@Suite("Chip labels")
struct ChipFormatTests {
    let cal = Fixed.calendar
    let mondayNoon = Fixed.date(2026, 8, 3)

    @Test("counts the days it has waited, all the way down")
    func countsDays() {
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "1 Day")
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 7, 31, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "3 Days")
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 7, 28, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "6 Days")
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 6, 24, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == "40 Days")
    }

    @Test func notOverdueMeansNoChip() {
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 3, 0, 0), isCompleted: false,
                                 now: mondayNoon, calendar: cal) == nil)
        #expect(ChipFormat.label(dueDate: Fixed.date(2026, 8, 2, 0, 0), isCompleted: true,
                                 now: mondayNoon, calendar: cal) == nil)
        #expect(ChipFormat.label(dueDate: nil, isCompleted: false,
                                 now: mondayNoon, calendar: cal) == nil)
    }
}

@Suite("The live note: in no tab, and archived the moment it is done")
struct LiveNoteTests {
    private let cal = Fixed.calendar
    private let noon = Fixed.date(2026, 8, 3, 12, 0)

    @Test("belongs to no tab, whatever its date")
    func inNoTab() {
        let note = TaskItem()
        note.isLiveNote = true
        note.dueDate = Fixed.date(2026, 8, 3, 0, 0)   // today, if it were a task
        for tab in Bucket.line {
            #expect(note.isVisible(in: tab, now: noon, calendar: cal) == false)
        }
    }

    /// The hole this closes: a ticked live note has no list to linger in, so
    /// the ordinary grace period left it gone from Live, in no tab, and not
    /// yet in the archive — a whole day in nowhere.
    @Test("archives at once when ticked, with no grace period")
    func archivesImmediately() {
        let note = TaskItem()
        note.isLiveNote = true
        note.isCompleted = true
        note.completedAt = Fixed.date(2026, 8, 3, 11, 59)   // one minute ago
        #expect(note.isArchived(now: noon, calendar: cal))
    }

    @Test("an ordinary dateless task still waits its day out")
    func ordinaryTaskKeepsItsGrace() {
        let task = TaskItem()
        task.isCompleted = true
        task.completedAt = Fixed.date(2026, 8, 3, 11, 59)
        #expect(task.isArchived(now: noon, calendar: cal) == false)
    }
}

@Suite("Soon day headings")
struct DayHeadingTests {
    @Test("weekday, day and month, in that order")
    func format() {
        // Fri 2026-08-14.
        let day = Fixed.date(2026, 8, 14, 0, 0)
        #expect(DayHeading.label(for: day, calendar: Fixed.calendar) == "Fri 14 Aug")
    }

    @Test("a single-digit day is not padded")
    func singleDigit() {
        let day = Fixed.date(2026, 8, 3, 0, 0)
        #expect(DayHeading.label(for: day, calendar: Fixed.calendar) == "Mon 3 Aug")
    }

    // MARK: The device calendar (regression, review 2026-08-26)
    //
    // The name tables have 8 and 13 slots, but `weekday` and `month` were read
    // through the USER's calendar. A Hebrew leap year, and every Coptic and
    // Ethiopic year, reports month 13 — which ran off the end of the table and
    // trapped. The Soon tab builds one of these per day heading, so the tab
    // crashed outright for anyone whose device calendar was one of those.

    /// Every calendar Foundation ships.
    static let allCalendars: [Calendar.Identifier] = [
        .gregorian, .buddhist, .chinese, .coptic, .ethiopicAmeteMihret,
        .ethiopicAmeteAlem, .hebrew, .indian, .islamic, .islamicCivil,
        .islamicTabular, .islamicUmmAlQura, .iso8601, .japanese, .persian,
        .republicOfChina
    ]

    private static func calendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// A full year against every calendar — 5 856 labels, none of which may
    /// trap. Stepping by day rather than by month is deliberate: monthly steps
    /// would skip the thirteenth month a leap year introduces.
    @Test("never traps, on any calendar, on any day of the year")
    func neverTrapsOnAnyDeviceCalendar() {
        for identifier in Self.allCalendars {
            let calendar = Self.calendar(identifier)
            for dayOffset in 0..<366 {
                let day = Fixed.calendar.date(byAdding: .day, value: dayOffset,
                                              to: Fixed.date(2026, 1, 1, 0, 0))!
                #expect(!DayHeading.label(for: day, calendar: calendar).isEmpty)
            }
        }
    }

    /// The exact case that crashed.
    @Test("a Hebrew thirteenth month does not trap")
    func hebrewThirteenthMonth() {
        let hebrew = Self.calendar(.hebrew)
        let day = Fixed.date(2026, 8, 26, 0, 0)
        #expect(hebrew.dateComponents([.month], from: day).month == 13,
                "the regression needs a month-13 date to be meaningful")
        #expect(DayHeading.label(for: day, calendar: hebrew) == "Wed 26 Aug")
    }

    /// The names stay GREGORIAN whatever the reader runs: Hebrew month 5 is
    /// not May, and a heading that renamed itself per device would also reflow
    /// the list it heads.
    @Test("names stay Gregorian regardless of the device calendar")
    func namingIsGregorian() {
        let day = Fixed.date(2026, 4, 14, 0, 0)
        for identifier in Self.allCalendars {
            #expect(DayHeading.label(for: day, calendar: Self.calendar(identifier)) == "Tue 14 Apr")
        }
    }

    /// The TIME ZONE still comes from the caller — which day a moment falls on
    /// is a question about where the reader is standing.
    @Test("the caller's time zone still decides the day")
    func timeZoneStillHonoured() {
        // 00:30 in Berlin is still 12:30 the previous afternoon in Honolulu.
        let moment = Fixed.date(2026, 4, 14, 0, 30)
        var honolulu = Calendar(identifier: .hebrew)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        #expect(DayHeading.label(for: moment, calendar: honolulu) == "Mon 13 Apr")
    }
}

@Suite("Month grid layout")
struct MonthGridTests {
    private let cal = Fixed.calendar

    /// August 2026 starts on a Saturday, so a Monday-first grid needs five
    /// blanks before the 1st. Getting this wrong puts every date in the month
    /// under the wrong weekday, silently.
    @Test("leading blanks put the 1st under its own weekday")
    func leadingBlanks() {
        let august = Fixed.date(2026, 8, 1, 0, 0)
        let cells = MonthGrid.cells(for: august, calendar: cal)
        #expect(cells.prefix(5).allSatisfy { $0 == nil })
        #expect(cells[5] == august)
        #expect(cells.count == 5 + 31)
    }

    @Test("a month starting on Monday needs no blanks")
    func noBlanks() {
        let june = Fixed.date(2026, 6, 1, 0, 0)   // Monday
        let cells = MonthGrid.cells(for: june, calendar: cal)
        #expect(cells.first == june)
        #expect(cells.count == 30)
    }
}
