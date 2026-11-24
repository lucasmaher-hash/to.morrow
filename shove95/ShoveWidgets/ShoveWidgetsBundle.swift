//
//  ShoveWidgetsBundle.swift
//  ShoveWidgets
//
//  The extension's entry point. One member for now — the pinned task's Live
//  Activity. Home Screen widgets, if they ever arrive, join here.
//

import SwiftUI
import WidgetKit

@main
struct ShoveWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PinnedTaskLiveActivity()
    }
}
