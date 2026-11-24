//
//  AppSettings.swift
//  shove95
//
//  User preferences: colour, typeface and custom tab names. Persisted in
//  UserDefaults — these are device preferences, not task data, so they
//  deliberately stay out of the synced SwiftData store.
//

import SwiftUI
import Shove95Kit

@Observable @MainActor
final class AppSettings {
    private enum Key {
        static let appearance = "settings.appearance"
        static let skeuTheme = "settings.skeu.theme"
        static let skeuFace = "settings.skeu.face"
        // v2: the founder settled the default set at Personal + Work
        // (2026-08-04); the bump orphans pre-release test data.
        static let workspaces = "settings.workspaces.v2"
        static let currentWorkspace = "settings.workspace.current"
        static let colorSlot = "settings.color.slot"
        // v2: the palette was cut from six to four and reordered on
        // 2026-08-22, which moved every position.
        static let colorSlotV2 = "settings.color.slot.v2"
        // And then reordered again the same day, which is what finally settled
        // the question — the colour is stored by NAME now. See `storedThemeID`.
        static let themeID = "settings.color.id"
        static func name(_ bucket: Bucket) -> String { "settings.name.\(bucket.rawValue)" }
        static func timeRules(_ bucket: Bucket) -> String { "settings.timerules.\(bucket.rawValue)" }
    }

    /// The chosen colour, by NAME.
    ///
    /// It was a POSITION for most of its life (founder decision 2026-08-17),
    /// because two looks had to agree on a colour without either owning the
    /// list. That cost exactly what it sounds like it would: cutting the
    /// palette to four moved every index, and a Moss install opened on Slate.
    /// Moving blue to the front an hour later would have done it again.
    ///
    /// A name survives any reordering, and reordering is a design decision the
    /// founder should be able to make without a migration each time.
    var themeID: String = SkeuTheme.all[0].id {
        didSet { UserDefaults.standard.set(themeID, forKey: Key.themeID) }
    }

    /// Light / dark / follow-the-device.
    var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The typeface: Retro (pixel furniture, readable words) or Modern.
    var skeuFace: AppFace {
        didSet {
            UserDefaults.standard.set(skeuFace.rawValue, forKey: Key.skeuFace)
            SkeuFont.face = skeuFace
        }
    }

    /// The typeface. One look, so this is simply `skeuFace` — the alias
    /// survives because the settings row binds to it and renaming a binding
    /// is churn without a reader.
    var activeFace: AppFace {
        get { skeuFace }
        set { skeuFace = newValue }
    }

    /// The palette. Falls back to the first theme if the stored name is one
    /// that no longer exists.
    var skeuTheme: SkeuTheme { SkeuTheme.named(themeID) }

    /// Custom tab labels. Empty string = use the built-in name.
    private var customNames: [Bucket: String]
    /// Per tab, whether its time rules apply. Absent means on — see
    /// `timeRulesEnabled(for:)`.
    private var timeRules: [Bucket: Bool] = [:]

    /// Which workspace this DEVICE is looking at. Deliberately not synced —
    /// the workspaces themselves are records now, but where you happen to be
    /// looking is local, like a scroll position.
    var currentWorkspaceID: String {
        didSet { UserDefaults.standard.set(currentWorkspaceID, forKey: Key.currentWorkspace) }
    }

    /// Workspaces this device held in preferences before they became synced
    /// records. Read once, to seed the records with the SAME ids so tasks
    /// already stamped with them keep their home.
    var legacyWorkspaces: [(id: String, name: String)] {
        struct Legacy: Codable { let id: String; let name: String }
        guard let data = UserDefaults.standard.data(forKey: Key.workspaces),
              let decoded = try? JSONDecoder().decode([Legacy].self, from: data)
        else { return [] }
        return decoded.map { ($0.id, $0.name) }
    }

    /// Which sections of Soon are folded shut. A nil day is General.
    ///
    /// VIEW state rather than a preference, and it lives here anyway: it has
    /// to survive both a tab change and a design change, and each look builds
    /// its own coordinators — this is the one object both roots already read.
    /// Deliberately NOT persisted. A list that comes back folded after a
    /// relaunch looks like a list that lost something.
    /// Keyed on the day ITSELF. `Date?` is already Hashable, and nil is
    /// already the "General" case — the seconds-to-string conversion this used
    /// to do bought nothing and truncated the value on the way past.
    private var collapsedSections: Set<Date?> = []

    func isCollapsed(_ day: Date?) -> Bool {
        collapsedSections.contains(day)
    }

    func toggleCollapsed(_ day: Date?) {
        if collapsedSections.insert(day).inserted == false {
            collapsedSections.remove(day)
        }
    }

    init() {

        appearance = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: Key.appearance) ?? "")
            ?? .system
        // "w95" was the all-pixel face, cut on 2026-08-22. Decoding it now
        // yields nil, and the plain fallback would drop those readers on
        // Modern — the furthest thing from what they had chosen. They land on
        // the blend, which is the closest face that still exists and is what
        // now carries the name "Retro".
        let storedFaceName = UserDefaults.standard.string(forKey: Key.skeuFace) ?? ""
        let storedFace = AppFace(rawValue: storedFaceName)
            ?? (storedFaceName == "w95" ? .blend : .system)
        skeuFace = storedFace
        SkeuFont.face = storedFace

        var names: [Bucket: String] = [:]
        for bucket in Bucket.line {
            if let value = UserDefaults.standard.string(forKey: Key.name(bucket)), !value.isEmpty {
                // Trimmed on LOAD as well as on entry. The limit arrived after
                // these were stored, and a name saved before it existed would
                // otherwise sit in the bar for ever — too long to fit, with no
                // way to shorten it but retyping it (founder bug report
                // 2026-08-17).
                names[bucket] = String(value.prefix(Self.maxNameLength))
            }
        }
        customNames = names

        var rules: [Bucket: Bool] = [:]
        for bucket in Bucket.line {
            if let stored = UserDefaults.standard.object(forKey: Key.timeRules(bucket)) as? Bool {
                rules[bucket] = stored
            }
        }
        timeRules = rules

        currentWorkspaceID = UserDefaults.standard.string(forKey: Key.currentWorkspace)
            ?? Workspace.defaultID

        themeID = Self.storedThemeID()
    }

    /// The colour to open with, migrating every older stored form.
    ///
    /// This has been written four ways: a NAME per look; one shared POSITION
    /// (2026-08-17), which is what made a picker of coloured pills possible; a
    /// second position after the palette was cut from six to four; and a name
    /// again (2026-08-22), because the second reorder that day proved the
    /// position was the wrong thing to keep.
    ///
    /// Each older form is read once and written forward, so nobody's app
    /// quietly changes colour on update — which reads as a bug rather than as
    /// a change to the palette.
    private static func storedThemeID() -> String {
        let defaults = UserDefaults.standard
        let fallback = SkeuTheme.all[0].id

        func settle(_ id: String) -> String {
            let known = SkeuTheme.named(id).id
            defaults.set(known, forKey: Key.themeID)
            return known
        }

        if let current = defaults.string(forKey: Key.themeID) {
            return SkeuTheme.named(current).id
        }

        // The four, in the order they sat in for the hour the second key was
        // the current one.
        let cutOrder = ["cream", "moss", "slate", "rose"]
        if let slot = defaults.object(forKey: Key.colorSlotV2) as? Int {
            return settle(cutOrder.indices.contains(slot) ? cutOrder[slot] : fallback)
        }

        // The six before the cut. Clay and Ember were both warm, and Cream and
        // Rose are what is left of that half; Silver was a near-neutral, which
        // is Slate now.
        let sixOrder = ["cream", "cream", "moss", "slate", "rose", "slate"]
        if let slot = defaults.object(forKey: Key.colorSlot) as? Int {
            return settle(sixOrder.indices.contains(slot) ? sixOrder[slot] : fallback)
        }

        // Older still: a name, one per look. The Windows one went with the
        // look it named, so only this one is read.
        return settle(defaults.string(forKey: Key.skeuTheme) ?? fallback)
    }

    /// The label to show for a bucket — the user's name if set, else the default.
    /// Bucket semantics never change; only the label does.
    /// Whether a tab's TIME RULES apply.
    ///
    /// Off means the tab moves nothing (founder direction, settled
    /// 2026-08-17): no rollover at midnight, no pull into Today, no overdue
    /// mark. Tasks stay exactly where they were put. The tab keeps its name
    /// and behaves the way General does today.
    ///
    /// General is the one tab this cannot be turned on for — it has no time
    /// rules to switch off, so the control would be a lie.
    func timeRulesEnabled(for bucket: Bucket) -> Bool {
        guard bucket != .general else { return false }
        return timeRules[bucket] ?? true
    }

    func setTimeRules(_ enabled: Bool, for bucket: Bucket) {
        guard bucket != .general else { return }
        timeRules[bucket] = enabled
        UserDefaults.standard.set(enabled, forKey: Key.timeRules(bucket))
    }

    func name(for bucket: Bucket) -> String {
        customNames[bucket] ?? bucket.displayName
    }

    /// Abbreviated label, for when the full one no longer fits.
    func shortName(for bucket: Bucket) -> String {
        if let custom = customNames[bucket] {
            return String(custom.prefix(3))
        }
        return bucket.shortName
    }

    /// What the tab bar should actually print at this text scale.
    ///
    /// The bar used to hand every label to `minimumScaleFactor` and let the
    /// long one shrink. That is why "Tomorrow" arrived at the accessibility
    /// sizes visibly smaller than "Today" and "Soon" beside it (founder bug
    /// report 2026-09-01): the two short names fit and held their size, and
    /// only the long one was squeezed, so the row read as two normal tabs and
    /// one undersized one. A reader who has asked for large text is the last
    /// one who should be given small text.
    ///
    /// Abbreviating instead keeps every label at the SAME size, which is the
    /// point of a segmented row. Only names that genuinely run out of room are
    /// touched: five characters still fit at 1.6×, so "Today" and "Soon" are
    /// never abbreviated and neither is a short custom name.
    func tabLabel(for bucket: Bucket, textScale: CGFloat) -> String {
        let full = name(for: bucket)
        guard textScale >= 1.22, full.count > 5 else { return full }
        return shortName(for: bucket)
    }

    /// The longest a tab name may be.
    ///
    /// Four of them share one bar across a phone, so a name is bounded by the
    /// bar and not by the field it is typed into. Twelve is what the longest
    /// built-in name needs ("Tomorrow" is eight) plus room to be personal,
    /// measured against the tab bar at the design step (founder direction
    /// 2026-08-17).
    static let maxNameLength = 12

    func setName(_ raw: String, for bucket: Bucket) {
        // Clipped rather than refused: someone pasting a sentence gets a
        // usable name, not an error, and the bar stays readable either way.
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(Self.maxNameLength))
        if trimmed.isEmpty {
            customNames.removeValue(forKey: bucket)
            UserDefaults.standard.removeObject(forKey: Key.name(bucket))
        } else {
            customNames[bucket] = trimmed
            UserDefaults.standard.set(trimmed, forKey: Key.name(bucket))
        }
    }

    func resetName(for bucket: Bucket) {
        setName("", for: bucket)
    }
}
