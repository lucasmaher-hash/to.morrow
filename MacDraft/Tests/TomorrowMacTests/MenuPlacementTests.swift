import SwiftUI
import Testing
@testable import TomorrowMac

@Suite @MainActor struct MenuPlacementTests {
    @Test func menuOpensBelowOrFlipsAboveTheRow() {
        let bounds = CGRect(x: 8, y: 8, width: 944, height: 584)
        let size = CGSize(width: 210, height: 258)
        let upper = CGRect(x: 30, y: 80, width: 240, height: 56)
        let below = MacTaskMenuOverlay.menuFrame(row: upper, bounds: bounds, size: size)
        #expect(below.minY == upper.maxY + 8)
        let lower = CGRect(x: 700, y: 500, width: 240, height: 56)
        let above = MacTaskMenuOverlay.menuFrame(row: lower, bounds: bounds, size: size)
        #expect(above.maxY == lower.minY - 8)
        #expect(bounds.contains(above))
    }
    @Test func oversizedMenuStaysInsideVisibleBounds() {
        let bounds = CGRect(x: 8, y: 8, width: 160, height: 180)
        let frame = MacTaskMenuOverlay.menuFrame(row: CGRect(x: 155, y: 150, width: 80, height: 40), bounds: bounds, size: CGSize(width: 210, height: 350))
        #expect(frame == bounds)
    }
}
