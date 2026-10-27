//
//  ReorderCoordinator.swift
//  shove95
//
//  Dragging a task to a new place in its list, by its own grip.
//
//  This existed once and was cut on 2026-08-04 — "too many gestures
//  interfering with each other" — because the drag lived on the row itself,
//  beside the swipe, the hold and the tap. A grip of its own is the answer to
//  that: the handle owns the drag and nothing else on the row hears it, so
//  none of the four gestures has to guess (founder direction 2026-08-23).
//
//  NOT the system's drag and drop. `onDrag`/`onDrop` is the other reordering
//  people write, and it is a different interaction: a press, a lift, a
//  floating system preview. What Reminders does — and what the founder asked
//  for — starts the moment the finger lands on the grip and follows it one to
//  one. So the drag is a plain gesture and the arithmetic is here.
//
//  The MODEL is: one row leaves its slot and travels; every row it passes
//  closes up behind it by exactly the height of the row that left. That is
//  true whatever the rows are worth in height — a task with photos is taller
//  than one without, and none of this cares.
//

import SwiftUI
import Shove95Kit

/// Row heights, kept OUT of the observed surface.
///
/// Every row reports its height as it lays out, which is a write per row per
/// layout pass. On an `@Observable` property that would invalidate every view
/// reading the coordinator — the whole list — sixty times a second while
/// nothing about the drag had changed. A plain class holds them instead; the
/// coordinator only ever reads them at the moments it does arithmetic.
@MainActor
final class RowHeightBook {
    private var heights: [UUID: CGFloat] = [:]

    func record(_ height: CGFloat, for id: UUID) { heights[id] = height }
    func height(for id: UUID) -> CGFloat { heights[id] ?? 0 }
    func forget(_ id: UUID) { heights.removeValue(forKey: id) }
}

@Observable @MainActor
final class ReorderCoordinator {
    /// The task under the finger, or nil when nothing is being dragged.
    ///
    /// Held as the model object as well as by id: the copy that floats above
    /// the list has to draw it, and the list it came from is a block the copy
    /// no longer belongs to.
    private(set) var carriedTask: TaskItem?
    private(set) var draggingID: UUID?
    /// How far that finger has travelled from where it landed.
    private(set) var travel: CGFloat = 0
    /// Where the dragged row would land if the finger lifted now.
    private(set) var toIndex = 0
    /// Where the row sat on screen when it was picked up, so the copy that
    /// floats above the list knows where to draw itself.
    private(set) var grabFrame: CGRect = .zero
    /// How far the row would have to travel to sit exactly in its new slot.
    /// The flight it makes when the finger lifts.
    private(set) var settle: CGFloat = 0

    /// The list as it stood when the drag began. The live list is re-derived
    /// from this and `toIndex`, so nothing is written until the finger lifts.
    private var slots: [UUID] = []
    private var fromIndex = 0

    let heights = RowHeightBook()

    /// The gap the list leaves between rows. Part of the distance a row has to
    /// travel to displace the next one, so it belongs in the arithmetic.
    var rowGap: CGFloat = 0

    /// How rows close up behind the one being dragged.
    ///
    /// Quicker than the app's `layout` spring and barely damped enough to stay
    /// still on arrival: rows getting out of the way should look like they
    /// were pushed, and a slow move reads as the list thinking rather than
    /// answering.
    static let displace = Animation.spring(response: 0.28, dampingFraction: 0.82)
    /// How the dragged row settles once it is let go — this one carries the
    /// LIST's own re-shuffle, since by then the move is written down and the
    /// row is travelling to a slot it now really owns.
    static let drop = Animation.spring(response: 0.34, dampingFraction: 0.80)
    /// The grab and the release: the row rising off the page and settling back
    /// onto it. Short, and barely bouncy — it is a lift, not a throw.
    static let lift = Animation.spring(response: 0.22, dampingFraction: 0.78)
    /// How long `drop` takes to settle, near enough. The copy is uncovered
    /// after this — see the row's `onEnded`.
    static let flightTime: Double = 0.30

    var isDragging: Bool { draggingID != nil }

    func isDragging(_ id: UUID) -> Bool { draggingID == id }

    // MARK: The drag

    func begin(_ task: TaskItem, in order: [UUID], frame: CGRect) {
        let id = task.id
        guard let index = order.firstIndex(of: id) else { return }
        carriedTask = task
        slots = order
        fromIndex = index
        toIndex = index
        travel = 0
        settle = 0
        grabFrame = frame
        draggingID = id
        SkeuHaptic.press()
    }

    /// The finger moved. Walks outward from the row's own slot, crossing each
    /// neighbour whose HALF height has been passed — which is the point at
    /// which the dragged row covers more of that neighbour's slot than the
    /// neighbour does, and so the point at which they should trade places.
    func update(_ dy: CGFloat) {
        guard draggingID != nil else { return }
        travel = dy

        var target = fromIndex
        var covered: CGFloat = 0
        if dy > 0 {
            var i = fromIndex + 1
            while i < slots.count {
                let step = slotHeight(i)
                guard dy > covered + step / 2 else { break }
                target = i; covered += step; i += 1
            }
        } else if dy < 0 {
            var i = fromIndex - 1
            while i >= 0 {
                let step = slotHeight(i)
                guard -dy > covered + step / 2 else { break }
                target = i; covered += step; i -= 1
            }
        }

        guard target != toIndex else { return }
        // `covered` is the exact distance to the near edge of the target slot,
        // which is the flight the row makes when it is let go.
        settle = target > fromIndex ? covered : (target < fromIndex ? -covered : 0)
        withAnimation(Self.displace) { toIndex = target }
        // The same tick a picker gives at every stop. It is the only signal
        // that the drop has changed target — the row under the finger has not
        // moved relative to the finger, so the eye can miss the swap.
        SkeuHaptic.selection()
    }

    /// The ids either side of the dragged row in the order it would leave
    /// behind, for whoever writes the move down.
    func destination() -> (moved: UUID, above: UUID?, below: UUID?)? {
        guard let draggingID else { return nil }
        var order = slots
        order.remove(at: fromIndex)
        order.insert(draggingID, at: min(toIndex, order.count))
        guard let at = order.firstIndex(of: draggingID) else { return nil }
        return (draggingID,
                at > 0 ? order[at - 1] : nil,
                at + 1 < order.count ? order[at + 1] : nil)
    }

    /// Sends the floating copy to the slot it is going to live in. Called
    /// inside the drop animation; the row underneath is uncovered once it
    /// lands, by which time the two are in the same place.
    func flyHome() { travel = settle }

    func end() {
        carriedTask = nil
        draggingID = nil
        travel = 0
        settle = 0
        grabFrame = .zero
        slots = []
    }

    // MARK: What the list draws

    /// How far this row sits from where the list would otherwise put it.
    ///
    /// The dragged row does not move AT ALL. It is invisible — the copy above
    /// the list is what follows the finger — and it used to be offset by the
    /// travel anyway, which fed straight back into the gesture measuring that
    /// travel: the view moved with the finger, so the finger only ever
    /// appeared to have gone half as far, and the task trailed further behind
    /// the further it was dragged (founder bug report 2026-08-23). Its slot
    /// stays put; that is what the rows around it close into.
    func offset(for id: UUID) -> CGFloat {
        guard let draggingID else { return 0 }
        if id == draggingID { return 0 }
        guard let i = slots.firstIndex(of: id) else { return 0 }
        let vacated = heights.height(for: draggingID) + rowGap
        if fromIndex < toIndex, i > fromIndex, i <= toIndex { return -vacated }
        if fromIndex > toIndex, i < fromIndex, i >= toIndex { return vacated }
        return 0
    }

    private func slotHeight(_ index: Int) -> CGFloat {
        heights.height(for: slots[index]) + rowGap
    }
}
