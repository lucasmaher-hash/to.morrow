//
//  LimitedText.swift
//  shove95
//
//  A text binding that will not accept more than it should.
//
//  Clipping on COMMIT was the first attempt and it was the wrong place: the
//  field happily took a hundred characters, showed them, and then quietly
//  threw most away when you looked elsewhere. The limit has to be felt while
//  typing or it is not a limit, it is a surprise (founder direction
//  2026-08-17).
//
//  It also has to exist at all for workspaces. Tab names were bounded and
//  workspace names were not, so a long workspace name pushed the pill wider
//  than the screen and carried the gear off the edge with it — the broken
//  layout in the founder's report.
//

import SwiftUI

extension Binding where Value == String {
    /// Refuses anything past `limit` as it is typed. Existing text longer than
    /// the limit is trimmed the first time the field is written to, so a value
    /// stored before the limit existed cannot linger.
    func limited(to limit: Int) -> Binding<String> {
        Binding<String>(
            get: { wrappedValue },
            set: { new in
                wrappedValue = new.count <= limit ? new : String(new.prefix(limit))
            }
        )
    }
}
