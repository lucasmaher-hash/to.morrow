//
//  HowToContent.swift
//  shove95
//
//  What the app expects you to do, written once.
//
//  THREE BLOCKS, and that is the whole screen (founder direction 2026-09-01).
//  It used to be thirteen items — three essentials plus three sections of
//  lookup — each a glyph, a named control and a five-word result. True, and
//  far too much: the app is simple, and a screen listing every gesture in it
//  made it look like it was not.
//
//  What survives is the three things you cannot work out by looking: going
//  live, the swipe, and workspaces. Everything cut is discoverable by using
//  the app — tapping a circle ticks a task off, the camera adds a photo, a
//  heading folds. Those never needed a manual entry; they needed one try.
//
//  Each block is now a heading, one picture, and a short paragraph under it,
//  rather than a column of terse rows. With only three of them there is room
//  to say a whole sentence, and a sentence explains where five words could
//  only label.
//
import Foundation

enum HowTo {
    /// The pictogram beside an item. Drawn, not lettered: they had to read in
    /// a look where SF Symbols are prohibited (design.md §9).
    ///
    /// A VOCABULARY, not a list of what is currently used — a case with no
    /// block pointing at it costs nothing and lets the content above change
    /// without anyone opening the drawing code. Most of these are unused
    /// since the screen came down to three; they stay for exactly that
    /// reason.
    enum Glyph: String {
        case line           // the dated tabs, as a row of steps
        case swipeRight
        case swipeLeft
        case clock
        case tick
        case caret          // tap to edit
        case hold
        case drag
        case plus
        case camera
        case calendar
        case fold           // a section heading that opens and shuts
        case pin
        case lockScreen
        case workspace
        case undo
        case photo
    }

    /// What stands at the top of a block.
    ///
    /// Two of the three are now the REAL control, alive and performing the
    /// thing the words describe, rather than a pictogram of it (founder
    /// direction 2026-09-01) — a reader recognises the object they are about
    /// to touch, which a drawing of it only approximates. `glyph` remains for
    /// anything a live control cannot show; the swipe is that case for now,
    /// since it needs a task and a finger, not just a control sitting still.
    enum Art {
        case glyph(Glyph)
        /// The Live tab, lit and breathing as though something were on air.
        case liveTab
        /// The workspace pill, opening and switching on a loop.
        case workspacePill
        /// Two task rows, the first shoving left and the second right.
        case swipeRows
    }

    /// One explained thing: a heading that sits above its frame, a single
    /// picture at the top inside it, and the words underneath.
    struct Block: Identifiable {
        let title: String
        let art: Art
        let body: String
        var id: String { title }
    }

    /// In the order someone meets them: the feature that has no visible
    /// explanation at all, then the gesture the whole app is built on, then
    /// the thing that quietly changes what the list contains.
    static let blocks: [Block] = [
        Block(title: "Go live",
              art: .liveTab,
              body: "In the bottom left panel you can add a live task. "
                  + "Clicking the \u{201C}Live\u{201D} button adds it "
                  + "permanently to your Lock Screen until you tick it off."),

        Block(title: "Swiping",
              art: .swipeRows,
              body: "Not going to get a task done today? Swipe it right and "
                  + "it moves to Tomorrow. Swipe left to bring it back."),

        Block(title: "Workspaces",
              art: .workspacePill,
              body: "Switch between workspaces with the button at the top "
                  + "left. Add or rename them in Settings."),
    ]
}
