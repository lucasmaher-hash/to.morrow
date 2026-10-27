//
//  HowToGlyph.swift
//  shove95
//
//  The pictograms on the How-to screen.
//
//  DRAWN, not lettered. This screen existed in two looks, one of which could
//  not use SF Symbols (design.md §9), so every glyph here is a path on a unit
//  square that takes a tint. They are deliberately plain: a reader scanning for "the one where
//  you drag" needs to recognise it at a glance, not admire it.
//
//  One stroke width, one cap style, one geometry. A picture set that varies
//  its own weight reads as a set of unrelated icons.
//

import SwiftUI

struct HowToGlyph: View {
    let glyph: HowTo.Glyph
    let tint: Color
    /// The box the pictogram is drawn in. Everything scales from it.
    var size: CGFloat = 26

    private var stroke: CGFloat { max(1.5, size * 0.075) }

    var body: some View {
        Canvas { context, box in
            let w = box.width, h = box.height
            var path = Path()
            var fills: [Path] = []

            switch glyph {
            case .line:
                // Four steps on one line: the chain, as it is.
                path.move(to: CGPoint(x: 0, y: h / 2))
                path.addLine(to: CGPoint(x: w, y: h / 2))
                for i in 0..<4 {
                    let x = w * (0.11 + 0.26 * CGFloat(i))
                    fills.append(dot(at: CGPoint(x: x, y: h / 2), r: w * 0.075))
                }

            case .swipeRight, .swipeLeft:
                // A finger and the direction it travels.
                let toRight = glyph == .swipeRight
                let y = h * 0.5
                let tail = toRight ? w * 0.18 : w * 0.82
                let head = toRight ? w * 0.88 : w * 0.12
                path.move(to: CGPoint(x: tail, y: y))
                path.addLine(to: CGPoint(x: head, y: y))
                let back = toRight ? -w * 0.16 : w * 0.16
                path.move(to: CGPoint(x: head + back, y: y - h * 0.16))
                path.addLine(to: CGPoint(x: head, y: y))
                path.addLine(to: CGPoint(x: head + back, y: y + h * 0.16))
                fills.append(dot(at: CGPoint(x: tail, y: y), r: w * 0.11))

            case .clock:
                path.addEllipse(in: CGRect(x: w * 0.14, y: h * 0.14,
                                           width: w * 0.72, height: h * 0.72))
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.52))
                path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.62))

            case .tick:
                path.addEllipse(in: CGRect(x: w * 0.10, y: h * 0.10,
                                           width: w * 0.80, height: h * 0.80))
                path.move(to: CGPoint(x: w * 0.31, y: h * 0.52))
                path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.66))
                path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.36))

            case .caret:
                // Two lines of text and a caret standing in them.
                path.move(to: CGPoint(x: w * 0.08, y: h * 0.34))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.34))
                path.move(to: CGPoint(x: w * 0.08, y: h * 0.62))
                path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.62))
                path.move(to: CGPoint(x: w * 0.80, y: h * 0.20))
                path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.76))

            case .hold:
                // A press RIPPLING OUT — two rings, not one. With a single
                // ring this was the pin glyph exactly, and the two sat six
                // rows apart meaning different things.
                path.addEllipse(in: CGRect(x: w * 0.02, y: h * 0.02,
                                           width: w * 0.96, height: h * 0.96))
                path.addEllipse(in: CGRect(x: w * 0.20, y: h * 0.20,
                                           width: w * 0.60, height: h * 0.60))
                fills.append(dot(at: CGPoint(x: w * 0.5, y: h * 0.5), r: w * 0.15))

            case .drag:
                // Held, and travelling.
                fills.append(dot(at: CGPoint(x: w * 0.5, y: h * 0.5), r: w * 0.17))
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
                path.move(to: CGPoint(x: w * 0.36, y: h * 0.19))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
                path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.19))
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.70))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.95))
                path.move(to: CGPoint(x: w * 0.36, y: h * 0.81))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.95))
                path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.81))

            case .plus:
                path.move(to: CGPoint(x: w * 0.5, y: h * 0.16))
                path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.84))
                path.move(to: CGPoint(x: w * 0.16, y: h * 0.5))
                path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.5))

            case .calendar:
                // A page with its two hangers and the week rule under them.
                path.addRoundedRect(in: CGRect(x: w * 0.10, y: h * 0.20,
                                               width: w * 0.80, height: h * 0.66),
                                    cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
                path.move(to: CGPoint(x: w * 0.10, y: h * 0.40))
                path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.40))
                for x in [w * 0.32, w * 0.68] {
                    path.move(to: CGPoint(x: x, y: h * 0.12))
                    path.addLine(to: CGPoint(x: x, y: h * 0.28))
                }
                // One day marked, because that is what the control is for.
                fills.append(dot(at: CGPoint(x: w * 0.5, y: h * 0.63), r: w * 0.09))

            case .fold:
                // A heading with its chevron, and the rows tucking away under
                // it — the same shape the section headings wear.
                path.move(to: CGPoint(x: w * 0.06, y: h * 0.26))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.26))
                path.move(to: CGPoint(x: w * 0.74, y: h * 0.18))
                path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.18))
                path.move(to: CGPoint(x: w * 0.06, y: h * 0.60))
                path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.60))
                path.move(to: CGPoint(x: w * 0.06, y: h * 0.84))
                path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.84))

            case .camera:
                path.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.26,
                                               width: w * 0.84, height: h * 0.52),
                                    cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
                path.move(to: CGPoint(x: w * 0.34, y: h * 0.26))
                path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.14))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.14))
                path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.26))
                path.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.38,
                                           width: w * 0.24, height: w * 0.24))

            case .pin:
                // The ring that holds, with its core filled.
                path.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.12,
                                           width: w * 0.76, height: h * 0.76))
                fills.append(dot(at: CGPoint(x: w * 0.5, y: h * 0.5), r: w * 0.19))

            case .lockScreen:
                // A phone, with the card sitting on it.
                path.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.06,
                                               width: w * 0.56, height: h * 0.88),
                                    cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
                path.addRoundedRect(in: CGRect(x: w * 0.32, y: h * 0.40,
                                               width: w * 0.36, height: h * 0.20),
                                    cornerSize: CGSize(width: w * 0.05, height: w * 0.05))

            case .workspace:
                // The pill and its chevron.
                path.addRoundedRect(in: CGRect(x: w * 0.04, y: h * 0.30,
                                               width: w * 0.68, height: h * 0.40),
                                    cornerSize: CGSize(width: h * 0.20, height: h * 0.20))
                path.move(to: CGPoint(x: w * 0.78, y: h * 0.42))
                path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.56))
                path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.42))

            case .undo:
                // An arc turning back on itself.
                path.addArc(center: CGPoint(x: w * 0.5, y: h * 0.56),
                            radius: w * 0.34,
                            startAngle: .degrees(160), endAngle: .degrees(20),
                            clockwise: true)
                path.move(to: CGPoint(x: w * 0.04, y: h * 0.34))
                path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.44))
                path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.28))

            case .photo:
                path.addRoundedRect(in: CGRect(x: w * 0.10, y: h * 0.16,
                                               width: w * 0.80, height: h * 0.68),
                                    cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
                path.move(to: CGPoint(x: w * 0.18, y: h * 0.70))
                path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.44))
                path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.64))
                path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.52))
                path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.70))
            }

            context.stroke(path, with: .color(tint),
                           style: StrokeStyle(lineWidth: stroke,
                                              lineCap: .round, lineJoin: .round))
            for fill in fills { context.fill(fill, with: .color(tint)) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // the words beside it already say this
    }

    private func dot(at c: CGPoint, r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
