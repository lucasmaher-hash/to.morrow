import Foundation
import Testing
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct SettingsTests {
    @Test func settingsPersistAndTimeRulesHoldTasksInTheirSection() {
        let suite = "TomorrowMacSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); SkeuFont.face = .system }
        let settings = MacSettings(defaults: defaults)
        settings.names[Bucket.today.rawValue] = "Now"
        settings.zoom(1)
        #expect(settings.textSize == 16)
        settings.zoom(-1)
        #expect(settings.textSize == 15)
        settings.zoom(100)
        #expect(settings.textSize == 24)
        settings.zoom(-100)
        #expect(settings.textSize == 11)
        let task = TaskItem()
        task.dueDate = DateEngine.targetDate(for: .tomorrow, now: .now, calendar: .current)
        settings.setRules(false, for: .tomorrow, tasks: [task])
        task.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        #expect(settings.visible(task, in: .tomorrow))
        #expect(!settings.visible(task, in: .today))
        let restored = MacSettings(defaults: defaults)
        #expect(restored.name(.today) == "Now")
        #expect(restored.visible(task, in: .tomorrow))
        restored.setRules(true, for: .tomorrow, tasks: [task])
        #expect(restored.visible(task, in: .today))
        #expect(!restored.visible(task, in: .tomorrow))
        restored.names[Bucket.today.rawValue] = "   "
        #expect(restored.name(.today) == Bucket.today.displayName)
    }
}
