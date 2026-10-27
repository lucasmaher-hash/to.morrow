//
//  TypedText.swift
//  shove95
//
//  Text that types itself out when the typeface under it changes.
//
//  Swapping a face is the one setting whose effect is the TEXT ITSELF, and it
//  used to happen between two frames — every label on the screen was suddenly
//  a different shape and nothing said why. Typing it out makes the change the
//  subject rather than a side effect: you see the words being set again in the
//  face you just chose (founder direction 2026-08-16).
//
//  The trigger is passed in rather than read here. That is what let one
//  typewriter serve two looks, each reacting to its own face setting; one look
//  is left, and passing the trigger in still keeps this view from knowing
//  where the face comes from.
//
//  Style rides the OUTSIDE: `.font`, `.foregroundStyle`, `.tracking` and the
//  rest are ordinary View modifiers and reach the Text inside, so a call site
//  keeps the styling it already had and only changes what it wraps.
//
//  The first appearance never types. A row scrolling into a lazy list has not
//  changed face; it was simply not on screen yet, and typing it out there
//  would make the list look like it was loading.
//

import SwiftUI

struct TypedText: View {
    let text: String
    /// The chosen face, and what THIS text is. Together they answer the only
    /// question that matters: is this particular string about to be set
    /// differently?
    ///
    /// Watching the face alone was wrong, and obviously so once Blend existed:
    /// going W95FA → Blend leaves every heading exactly as it was, and they
    /// all typed themselves out anyway for no visible reason (founder bug
    /// report 2026-08-16). Watching the RESOLVED face — pixel or not, for this
    /// role — means only the text that actually changes announces it.
    let face: AppFace
    let role: TextRole

    private var trigger: Bool { face.isPixel(role) }

    /// The whole run, not per character: a long label would otherwise take
    /// noticeably longer than a short one sitting beside it, and the two are
    /// meant to finish together.
    private static let duration: Double = 0.42

    @State private var revealed: Int?
    /// Seeded from the value this view was BORN with, not left empty for the
    /// first `task` to fill in. An environment-supplied face arrives with a
    /// default on the very first pass, and a nil-then-fill seed read that
    /// default as the previous value — so simply opening the settings sheet
    /// typed every heading out, having changed nothing (caught in the
    /// simulator 2026-08-16).
    @State private var seen: Bool

    init(text: String, face: AppFace, role: TextRole) {
        self.text = text
        self.face = face
        self.role = role
        _seen = State(initialValue: face.isPixel(role))
    }

    var body: some View {
        // The FULL string, hidden, holds the final size — and the growing
        // prefix is laid over it from the leading edge.
        //
        // Without that, a half-typed label is a shorter view, so its layout
        // centres it and the text crawls outward from the middle with even
        // margins either side. Nothing ends up where it started. Reserving the
        // final box means the first character appears exactly where it is
        // going to stay and the rest arrive after it (founder direction
        // 2026-08-16).
        Text(text)
            .hidden()
            .overlay(alignment: .leading) {
                Text(revealed.map { String(text.prefix($0)) } ?? text)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .fixedSize(horizontal: false, vertical: true)
            .task(id: trigger) {
                guard seen != trigger else { return }   // nothing changed here
                seen = trigger
                await type()
            }
            // A half-typed label must never be what survives. The run is
            // async, so anything that interrupts it — the sheet being
            // dismissed, the view scrolling away, another face change landing
            // mid-run — can strand `revealed` partway, and a heading reading
            // "TYPEF" is worse than one that never animated at all (caught in
            // the simulator 2026-08-16, on the ✕ tap that closed the sheet).
            .onDisappear { revealed = nil }
    }

    private func type() async {
        let count = text.count
        guard count > 0 else { return }
        // Whatever happens below — return, cancellation, the task being torn
        // down — the text ends up whole.
        defer { revealed = nil }
        let step = UInt64(Self.duration / Double(count) * 1_000_000_000)
        revealed = 0
        for n in 1...count {
            try? await Task.sleep(nanoseconds: step)
            if Task.isCancelled { return }
            revealed = n
        }
    }
}
