//
//  PinReplaceDialog.swift
//  shove95
//
//  "Something else is already pinned. Replace it?"
//
//  One question on a floating card. It was drawn twice — the other half was a
//  modal dialog box, title bar and raised bevel, because that is what 1995 did
//  when it needed an answer — and neither reused the other's geometry; only
//  the words and the outcome were shared,
//  The pin-swap question it was built for is gone with the pin itself; it
//  serves the app's other two weighty questions now — deleting a workspace
//  and deleting a photo or a live note.
//
//  Both dim the screen behind them and swallow taps outside, which is the
//  one behaviour a modal question must have: there is no third answer.
//

import SwiftUI

/// Also the app's general "are you sure" — the pin swap is simply its first
/// caller. Deleting a workspace asks through this same dialog, so the two
/// weighty questions in the app are put the same way (founder direction
/// 2026-08-17).
struct SkeuPinReplaceDialog: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    let outgoing: String
    var title: String = "Replace pinned task"
    /// Nil builds the pin wording from `outgoing`.
    var message: String? = nil
    var confirmLabel: String = "Replace"
    /// Destructive questions colour their confirm word.
    var confirmTint: Color? = nil
    var onReplace: () -> Void
    var onCancel: () -> Void

    var body: some View {
        let buttonH = SkeuToggle.height - SkeuToggle.padV * 2

        ZStack {
            skeu.shadow.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                Text(title)
                    .font(SkeuFont.title3)
                    .foregroundStyle(skeu.ink)

                Text(message ?? "\u{201C}\(outgoing)\u{201D} is pinned to your Lock Screen. Only one task can be pinned.")
                    .font(SkeuFont.callout)
                    .foregroundStyle(skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: SkeuSpace.sm) {
                    Spacer(minLength: 0)

                    dialogButton("Cancel", tint: skeu.inkMuted,
                                 height: buttonH * chromeScale, action: onCancel)
                    dialogButton(confirmLabel, tint: confirmTint ?? skeu.ink,
                                 height: buttonH * chromeScale, action: onReplace)
                }
            }
            .padding(SkeuSpace.xl)
            .frame(maxWidth: 340)
            // A card, not a trough: this floats ABOVE the screen it covers,
            // so it takes the top of the depth ladder rather than being cut
            // into the ground like every control underneath it.
            .skeuSurface(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous),
                         depth: .overlay)
            .padding(.horizontal, SkeuSpace.xl)
            // MODAL to VoiceOver as well as to the finger. The scrim already
            // swallows taps, but without this trait a VoiceOver user could
            // swipe straight past the question into the list underneath and
            // act on it — including deleting more — while "this goes for good"
            // was still on screen (found in review 2026-08-26).
            .accessibilityAddTraits(.isModal)
        }
    }

    private func dialogButton(_ title: String,
                              tint: Color,
                              height: CGFloat,
                              action: @escaping () -> Void) -> some View {
        Text(title)
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: height)
            .skeuGlass(Capsule(), height: height)
            .skeuPress { action() }
            .accessibilityAddTraits(.isButton)
    }
}
