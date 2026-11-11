import SwiftUI
import Shove95Kit

/// One visible row travels above all three landscape scroll views. The real
/// source/destination row is hidden until the flying copy has settled.
@Observable @MainActor
final class MacTaskTransferCoordinator {
    enum Phase { case dragging, waiting, landing }

    struct BoardSection: Hashable {
        let bucket: Bucket
        var day: Date? = nil
    }

    struct BoardDrop: Equatable {
        let section: BoardSection
        let before: UUID?
    }

    private struct BoardRow {
        let section: BoardSection
        let frame: CGRect
    }

    private(set) var task: TaskItem?
    private(set) var sessionID = UUID()
    private(set) var phase: Phase = .dragging
    private(set) var frame: CGRect = .zero
    private(set) var origin: CGRect = .zero
    private(set) var destination: Bucket?
    private(set) var targetFrame: CGRect?
    private(set) var isLifted = false
    private(set) var isBoardDrag = false
    private(set) var boardDrop: BoardDrop?
    private(set) var isOverLive = false
    private(set) var isLiveTransfer = false
    private(set) var carriedWasLive = false
    @ObservationIgnored private var liveWell: CGRect?
    var isLiveLanding: Bool { isLiveTransfer && phase == .landing }
    @ObservationIgnored private var boardLocation: CGPoint?
    @ObservationIgnored private var previewSlot: (drop: BoardDrop, frame: CGRect)?
    @ObservationIgnored private var boardRows: [UUID: BoardRow] = [:]
    @ObservationIgnored private var boardHeaders: [BoardSection: CGRect] = [:]
    @ObservationIgnored private var boardViewports: [Bucket: CGRect] = [:]
    private var boardVelocity = CGSize.zero
    private var releaseVelocity: CGFloat = 0
    private var timeout: Task<Void, Never>?
    @ObservationIgnored private var viewports: [Bucket: CGRect] = [:]

    var taskID: UUID? { task?.id }
    var isWaiting: Bool { task != nil && phase == .waiting && targetFrame == nil }
    var isBoardPreview: Bool { isBoardDrag && phase == .dragging }

    func boardGapHeight(in section: BoardSection, before id: UUID?, rowGap: CGFloat = 0) -> CGFloat {
        isBoardPreview && boardDrop == BoardDrop(section: section, before: id)
            ? origin.height + rowGap : 0
    }

    // The portfolio's motion/src/Promo.tsx: response .55, damping .62,
    // with the release velocity carried into the spring. Its receiving list
    // uses mass 1, stiffness 195, damping 17.
    static let displace = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let liftAnimation = Animation.spring(response: 0.22, dampingFraction: 0.78)
    static let listShift = Animation.interpolatingSpring(mass: 1, stiffness: 195, damping: 17)

    var flight: Animation {
        let dx = (targetFrame?.midX ?? origin.midX) - frame.midX
        let dy = (targetFrame?.midY ?? origin.midY) - frame.midY
        let distanceSquared = dx * dx + dy * dy
        let velocity = isBoardDrag
            ? (distanceSquared > 1 ? Double((boardVelocity.width * dx + boardVelocity.height * dy) / distanceSquared) : 0)
            : (abs(dx) > 1 ? Double(releaseVelocity / dx) : 0)
        let omega = 2 * Double.pi / 0.55
        return .interpolatingSpring(mass: 1, stiffness: omega * omega,
                                    damping: 2 * 0.62 * omega,
                                    initialVelocity: min(8, max(-4, velocity)))
    }

    @discardableResult
    func lift(_ task: TaskItem, from frame: CGRect) -> Bool {
        if taskID == task.id { return phase == .dragging }
        guard self.task == nil, frame.width > 0, frame.height > 0 else { return false }
        sessionID = UUID()
        self.task = task
        carriedWasLive = task.isLiveNote && !task.isCompleted
        origin = frame
        self.frame = frame
        phase = .dragging
        isLifted = true
        return true
    }

    func track(_ dx: CGFloat) {
        guard task != nil, phase == .dragging else { return }
        frame = origin.offsetBy(dx: dx, dy: 0)
    }

    @discardableResult
    func liftBoard(_ task: TaskItem, from frame: CGRect) -> Bool {
        guard lift(task, from: frame) else { return false }
        isBoardDrag = true
        return true
    }

    func trackBoard(_ translation: CGSize, at location: CGPoint) {
        guard isBoardDrag, phase == .dragging else { return }
        frame = origin.offsetBy(dx: translation.width, dy: translation.height)
        boardLocation = location
        refreshBoardDrop()

    }

    func prepareBoard(velocity: CGSize) {
        guard let boardDrop else { returnHome(); return }
        boardVelocity = velocity
        isLifted = false
        let slot = previewSlot
        prepare(for: boardDrop.section.bucket, velocity: velocity.width)
        if let slot, slot.drop == boardDrop,
           let viewport = boardViewports[boardDrop.section.bucket],
           slot.frame.minY >= viewport.minY, slot.frame.minY + origin.height <= viewport.maxY {
            // The preview has already laid out the intended slot. Never
            // acquire the old source geometry during the model/query handoff.
            targetFrame = CGRect(origin: slot.frame.origin,
                                 size: CGSize(width: slot.frame.width, height: origin.height))
            timeout?.cancel()
        }
    }

    func recordLiveWell(_ frame: CGRect?) { liveWell = frame }

    func prepareLive(velocity: CGSize) {
        guard isOverLive, let liveWell, task?.isCompleted == false else { returnHome(); return }
        boardVelocity = velocity
        isLifted = false
        isLiveTransfer = true
        prepare(for: .today, velocity: velocity.width)
        targetFrame = liveWell
        timeout?.cancel()
    }

    func recordBoardGap(_ frame: CGRect, drop: BoardDrop) {
        guard isBoardPreview, drop == boardDrop, frame.width > 0, frame.height > 0 else { return }
        previewSlot = (drop, frame)
    }

    func recordBoardViewport(_ frame: CGRect, in bucket: Bucket) {
        boardViewports[bucket] = frame
    }

    func recordBoardHeader(_ frame: CGRect, section: BoardSection) {
        boardHeaders[section] = frame
        refreshBoardDrop()
    }

    func forgetBoardHeader(_ section: BoardSection) { boardHeaders[section] = nil }

    func recordBoardRow(_ frame: CGRect, id: UUID, section: BoardSection) {
        boardRows[id] = BoardRow(section: section, frame: frame)
        refreshBoardDrop()
    }

    func forgetBoardRow(_ id: UUID, section: BoardSection) {
        if boardRows[id]?.section == section { boardRows[id] = nil }
    }

    private func refreshBoardDrop() {
        guard isBoardDrag, phase == .dragging, let location = boardLocation else { return }
        isOverLive = task?.isCompleted == false && liveWell?.contains(location) == true
        if isOverLive { boardDrop = nil; return }
        guard let (bucket, _) = boardViewports.first(where: {
            location.x >= $0.value.minX && location.x <= $0.value.maxX
                && location.y >= $0.value.minY - 44 && location.y <= $0.value.maxY + 16
        }) else { boardDrop = nil; return }
        var section = BoardSection(bucket: bucket)
        if bucket == .general {
            let headers = boardHeaders.filter { $0.key.bucket == bucket }
                .sorted { $0.value.minY < $1.value.minY }
            section = headers.last(where: { $0.value.minY <= location.y })?.key
                ?? headers.first?.key ?? section
        }
        let rows = boardRows.filter {
            $0.key != taskID && $0.value.section == section
                && $0.value.frame.width > 0 && $0.value.frame.height > 0
        }.sorted { $0.value.frame.midY < $1.value.frame.midY }
        let before = rows.first(where: { $0.value.frame.midY > location.y })?.key
        let target = BoardDrop(section: section, before: before)
        if boardDrop != target { boardDrop = target }
    }

    /// Reveal one neighbouring row at a time while the handle is held at an edge.
    func boardScrollTarget(in bucket: Bucket, order: [UUID]) -> (id: UUID, downward: Bool)? {
        guard isBoardDrag, phase == .dragging, let point = boardLocation,
              let viewport = boardViewports[bucket],
              point.x >= viewport.minX, point.x <= viewport.maxX else { return nil }
        let visible = order.enumerated().filter { _, id in
            guard let row = boardRows[id] else { return false }
            return row.frame.intersects(viewport)
        }
        if point.y > viewport.maxY - 44, let last = visible.last,
           last.offset + 1 < order.count {
            return (order[last.offset + 1], true)
        }
        if point.y < viewport.minY + 44, let first = visible.first, first.offset > 0 {
            return (order[first.offset - 1], false)
        }
        return nil
    }

    func prepare(for bucket: Bucket, velocity: CGFloat) {
        guard task != nil, phase == .dragging else { return }
        releaseVelocity = velocity
        destination = bucket
        targetFrame = nil
        phase = .waiting
        let session = sessionID
        // A changed workspace/scene normally resets immediately. This also
        // prevents an unavailable lazy row from leaving a task hidden forever.
        timeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, session == sessionID, isWaiting else { return }
            reset()
        }
    }

    func recordViewport(_ frame: CGRect, in bucket: Bucket) {
        viewports[bucket] = frame
    }

    func report(_ frame: CGRect, taskID: UUID, in bucket: Bucket, day: Date? = nil) {
        guard isWaiting, self.taskID == taskID, destination == bucket,
              frame.width > 0, frame.height > 0,
              let viewport = isBoardDrag ? boardViewports[bucket] : viewports[bucket] else { return }
        if isBoardDrag, boardDrop?.section != BoardSection(bucket: bucket, day: day) { return }
        // LazyVStack also lays out rows below the fold. Those frames are real,
        // but flying to one would take the card offscreen. Leave the request
        // waiting so the destination's ScrollViewReader reveals it first.
        if frame.height <= viewport.height {
            guard frame.minY >= viewport.minY, frame.maxY <= viewport.maxY else { return }
        } else {
            guard viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return }
        }
        targetFrame = frame
        timeout?.cancel()
    }

    func returnHome() {
        guard task != nil, phase == .dragging else { return }
        destination = nil
        releaseVelocity = 0
        phase = .waiting
        targetFrame = origin
    }

    func flyToTarget() {
        guard let targetFrame else { return }
        phase = .landing
        frame = targetFrame
    }

    func lower(session: UUID) {
        guard session == sessionID, phase == .landing else { return }
        isLifted = false
    }

    func finish(session: UUID) {
        guard session == sessionID else { return }
        reset()
    }

    func reset() {
        timeout?.cancel()
        timeout = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            task = nil
            destination = nil
            targetFrame = nil
            frame = .zero
            origin = .zero
            isLifted = false
            isBoardDrag = false
            boardDrop = nil
            isOverLive = false
            isLiveTransfer = false
            carriedWasLive = false
            boardLocation = nil
            previewSlot = nil
            boardVelocity = .zero
            phase = .dragging
            sessionID = UUID()
        }
    }
}
