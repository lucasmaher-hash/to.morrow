//
//  PinnedTaskLiveActivity.swift
//  ShoveWidgets
//
//  The pinned task, on the Lock Screen and in the Dynamic Island.
//
//  This file knows NOTHING about themes. Every colour arrives resolved in the
//  content state, because the app is the only place allowed to know colours
//  (CLAUDE.md rule 2) and duplicating the palettes here would have meant two
//  places to change when a theme changes. What lives here is GEOMETRY, which
//  the app cannot send: a soft slab is a drawing, not values.
//

import SwiftUI
import WidgetKit
import ActivityKit
import Shove95Kit

// MARK: - Colour bridging

private extension Color {
    init(_ c: ActivityColor) {
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }
}

private extension PinnedTaskAttributes.ContentState {
    /// The typeface setting, honoured on the Lock Screen too. W95FA is set
    /// 1.22× the system size — the inverse of the 0.82 factor the app uses to
    /// keep the two faces optically level.
    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = fontName {
            return .custom(name, fixedSize: size * 1.22)
        }
        return .system(size: size, weight: weight)
    }
}

// MARK: - The configuration

struct PinnedTaskLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinnedTaskAttributes.self) { context in
            LockScreenCard(state: context.state, taskID: context.attributes.taskID)
                // The card paints its own surface edge to edge; without this
                // iOS puts its default material behind it and the flat grey
                // floats on a translucent slab.
                .activityBackgroundTint(Color(context.state.palette.surface))
                .activitySystemActionForegroundColor(Color(context.state.palette.ink))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedIsland(state: context.state, taskID: context.attributes.taskID)
                }
            } compactLeading: {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color(context.state.palette.accent))
            } compactTrailing: {
                // Truncated hard: the compact slot is a few characters wide,
                // and a title that elides to "sort out th…" is still a better
                // reminder than an icon alone.
                Text(context.state.title)
                    .font(context.state.font(13))
                    .foregroundStyle(Color(context.state.palette.ink))
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)
            } minimal: {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color(context.state.palette.accent))
            }
            // Tapping anywhere that is not the button opens the app.
            .widgetURL(URL(string: "shove95://task/\(context.attributes.taskID.uuidString)"))
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenCard: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        // One grammar. A Windows 95 dialog card stood beside this one until
        // the look was removed (2026-08-22), which is why the state still
        // names a look at all.
        SkeuCardView(state: state, taskID: taskID)
    }
}

// MARK: Skeu

/// A slab lying on the Lock Screen: soft material, a rim light along the top
/// edge, one light source from above — the same physics contract the app's
/// surfaces follow, drawn with what arrives in the state.
private struct SkeuCardView: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // No day chip (founder direction 2026-08-17). A pinned task is
            // the one you are doing NOW; when it is due is the list's
            // question, not this card's, and a second line halves the size
            // the title can take.
            Text(state.title)
                .font(state.font(17, weight: .medium))
                .foregroundStyle(Color(state.palette.ink))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: CompletePinnedTaskIntent(taskID: taskID)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(state.palette.ink))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color(state.palette.surface))
                            .overlay {
                                // Rim light on the TOP edge only — one light
                                // source, from above and slightly left.
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color(state.palette.light).opacity(0.9),
                                                 Color(state.palette.light).opacity(0.05)],
                                        startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1)
                            }
                            .shadow(color: Color(state.palette.dark).opacity(0.35),
                                    radius: 5, x: 0, y: 3)
                    }
            }
            .buttonStyle(.plain)
            // Without this VoiceOver reads the SF Symbol's name — "checkmark,
            // button" — on the Lock Screen, which says nothing about what it
            // does or to what (found in review 2026-08-26).
            .accessibilityLabel("Complete \(state.title)")
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(state.palette.surface))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(state.palette.light).opacity(0.85),
                                         Color(state.palette.light).opacity(0.04)],
                                startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                }
        }
        .padding(8)
    }
}

// MARK: - Dynamic Island, expanded

private struct ExpandedIsland: View {
    let state: PinnedTaskAttributes.ContentState
    let taskID: UUID

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(state.font(15, weight: .medium))
                    .foregroundStyle(Color(state.palette.ink))
                    .lineLimit(2)
                if let chip = state.chip {
                    Text(chip)
                        .font(state.font(12))
                        .foregroundStyle(Color(state.palette.inkMuted))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: CompletePinnedTaskIntent(taskID: taskID)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color(state.palette.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(state.title)")
        }
        .padding(.horizontal, 4)
    }
}
