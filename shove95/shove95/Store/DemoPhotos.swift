//
//  DemoPhotos.swift
//  shove95
//
//  Drawn, not bundled. The App Store screenshots need photos attached to
//  tasks, and the alternatives were both worse: shipping real image assets
//  bloats the app for something only a debug seed uses, and base64 blobs in
//  source are unreadable. These are drawn at seed time and never ship in a
//  Release build.
//
//  They are the kinds of things this app is actually for — a parcel label, a
//  note from a lecture, a receipt. Not scenery.
//

#if DEBUG
import UIKit

enum DemoPhotos {

    static func parcelLabel() -> Data {
        render(size: CGSize(width: 900, height: 620), background: .init(white: 0.93, alpha: 1)) { ctx, rect in
            UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: rect.width, height: 150))
            text("PAKETSHOP 4471", at: CGPoint(x: 44, y: 44), size: 58, color: .white, bold: true)
            text("Abholung bis Fr. 18:00", at: CGPoint(x: 44, y: 190), size: 40, color: .darkGray)
            text("Sendung  9F 2244 8817 03", at: CGPoint(x: 44, y: 260), size: 34, color: .darkGray)
            text("Fach  B-14", at: CGPoint(x: 44, y: 320), size: 34, color: .darkGray)
            barcode(in: CGRect(x: 44, y: 400, width: 700, height: 140), ctx: ctx)
        }
    }

    static func lectureNote() -> Data {
        render(size: CGSize(width: 900, height: 640), background: .init(white: 0.97, alpha: 1)) { ctx, rect in
            // Faint ruled lines, like a notebook page photographed badly.
            UIColor(white: 0.85, alpha: 1).setStroke()
            let path = UIBezierPath()
            for y in stride(from: 120.0, to: rect.height, by: 62) {
                path.move(to: CGPoint(x: 40, y: y)); path.addLine(to: CGPoint(x: rect.width - 40, y: y))
            }
            path.lineWidth = 2; path.stroke()

            text("Ergonomie — Klausur", at: CGPoint(x: 52, y: 46), size: 52, color: .black, bold: true)
            text("Perzentile: 5. Frau – 95. Mann", at: CGPoint(x: 52, y: 140), size: 38, color: .init(white: 0.2, alpha: 1))
            text("Greifraum ≠ Greifart", at: CGPoint(x: 52, y: 264), size: 38, color: .init(white: 0.2, alpha: 1))
            text("Belastung → Beanspruchung", at: CGPoint(x: 52, y: 388), size: 38, color: .init(white: 0.2, alpha: 1))
            text("ISO 9241 — 7 Grundsätze", at: CGPoint(x: 52, y: 512), size: 38, color: .init(white: 0.2, alpha: 1))
        }
    }

    static func receipt() -> Data {
        render(size: CGSize(width: 620, height: 820), background: .white) { ctx, rect in
            text("HORNBACH", at: CGPoint(x: 40, y: 40), size: 46, color: .black, bold: true)
            text("München–Freimann", at: CGPoint(x: 40, y: 104), size: 28, color: .darkGray)
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 40, y: 168, width: rect.width - 80, height: 3))

            let items = [("Fahrradlampe LED", "24,99"),
                         ("Halterung 31,8mm", " 6,49"),
                         ("Batterien AA x4", " 5,99")]
            var y = 208.0
            for (name, price) in items {
                text(name, at: CGPoint(x: 40, y: y), size: 30, color: .black)
                text(price, at: CGPoint(x: rect.width - 170, y: y), size: 30, color: .black)
                y += 62
            }
            ctx.fill(CGRect(x: 40, y: y + 14, width: rect.width - 80, height: 3))
            text("SUMME", at: CGPoint(x: 40, y: y + 44), size: 34, color: .black, bold: true)
            text("37,47", at: CGPoint(x: rect.width - 180, y: y + 44), size: 34, color: .black, bold: true)
            barcode(in: CGRect(x: 40, y: y + 140, width: rect.width - 80, height: 90), ctx: ctx)
        }
    }

    // MARK: - Drawing helpers

    /// The bike light that stopped working, photographed on a kitchen table.
    ///
    /// Drawn for the same reason as the map: a real product photo is somebody
    /// else's copyright and usually somebody else's trademark on the casing.
    /// This is a generic lamp with a cracked lens — no maker, no logo, nothing
    /// borrowed (founder direction 2026-09-01).
    static func brokenBikeLight() -> Data {
        render(size: CGSize(width: 900, height: 620),
               background: .init(red: 0.80, green: 0.78, blue: 0.74, alpha: 1)) { ctx, rect in
            // Table grain, faint — enough that the lamp is ON something.
            UIColor(red: 0.76, green: 0.73, blue: 0.69, alpha: 1).setFill()
            var y: CGFloat = 0
            while y < rect.height {
                ctx.fill(CGRect(x: 0, y: y, width: rect.width, height: 3))
                y += 46
            }

            // Shadow under the lamp.
            UIColor(white: 0.45, alpha: 0.30).setFill()
            ctx.fillEllipse(in: CGRect(x: 210, y: 430, width: 480, height: 70))

            // Body: a rounded slab lying on its side.
            let body = CGRect(x: 250, y: 210, width: 400, height: 230)
            UIColor(red: 0.18, green: 0.19, blue: 0.21, alpha: 1).setFill()
            ctx.addPath(UIBezierPath(roundedRect: body, cornerRadius: 46).cgPath)
            ctx.fillPath()
            // A lit edge along the top, so it reads as an object not a rectangle.
            UIColor(white: 1, alpha: 0.16).setFill()
            ctx.addPath(UIBezierPath(roundedRect: body.insetBy(dx: 18, dy: 16)
                                        .offsetBy(dx: 0, dy: -8),
                                     cornerRadius: 34).cgPath)
            ctx.fillPath()

            // The lens, dark — this is the point of the photo.
            let lens = CGRect(x: 286, y: 250, width: 150, height: 150)
            UIColor(red: 0.55, green: 0.56, blue: 0.58, alpha: 1).setFill()
            ctx.fillEllipse(in: lens)
            UIColor(red: 0.30, green: 0.31, blue: 0.33, alpha: 1).setFill()
            ctx.fillEllipse(in: lens.insetBy(dx: 22, dy: 22))

            // The crack: three strokes from the centre out.
            ctx.setStrokeColor(UIColor(white: 0.92, alpha: 0.95).cgColor)
            ctx.setLineWidth(6)
            let c = CGPoint(x: lens.midX, y: lens.midY)
            for end in [CGPoint(x: c.x + 66, y: c.y - 40),
                        CGPoint(x: c.x - 18, y: c.y + 70),
                        CGPoint(x: c.x - 70, y: c.y - 26)] {
                ctx.move(to: c)
                ctx.addLine(to: end)
            }
            ctx.strokePath()

            // The bracket it clips to, sitting loose beside it.
            UIColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1).setFill()
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 660, y: 330, width: 120, height: 96),
                                     cornerRadius: 22).cgPath)
            ctx.fillPath()
            UIColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 1).setFill()
            ctx.fillEllipse(in: CGRect(x: 692, y: 356, width: 56, height: 44))
        }
    }

    /// A dentist's location, as a map card.
    ///
    /// DRAWN, like the other three, and for a sharper reason than theirs: the
    /// obvious version of this is a screenshot of a real maps app, and that
    /// would put another company's UI, pin style and wordmark into an App
    /// Store screenshot. Guideline 2.3.10 covers third-party trademarks in
    /// metadata, and the map providers' own brand terms restrict reuse in
    /// marketing. Nothing here belongs to anyone: generic roads, a generic
    /// pin, an invented practice at an invented address (founder direction
    /// 2026-09-01, and the reason it is a drawing rather than a capture).
    static func dentistMap() -> Data {
        render(size: CGSize(width: 900, height: 620),
               background: .init(red: 0.90, green: 0.91, blue: 0.88, alpha: 1)) { ctx, rect in
            // Blocks of built-up ground, so the roads have something to divide.
            UIColor(red: 0.85, green: 0.86, blue: 0.83, alpha: 1).setFill()
            for block in [CGRect(x: 40, y: 40, width: 300, height: 190),
                          CGRect(x: 420, y: 40, width: 260, height: 120),
                          CGRect(x: 40, y: 330, width: 240, height: 240),
                          CGRect(x: 520, y: 300, width: 330, height: 270)] {
                ctx.fill(block)
            }

            // Roads: two wide, one thin, none of them anywhere.
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 250, width: rect.width, height: 56))
            ctx.fill(CGRect(x: 360, y: 0, width: 44, height: rect.height))
            UIColor(white: 0.97, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 470, width: rect.width, height: 26))

            // A river, because a map with only right angles reads as a diagram.
            UIColor(red: 0.72, green: 0.82, blue: 0.86, alpha: 1).setFill()
            ctx.fill(CGRect(x: 700, y: 0, width: 60, height: 250))

            // The pin, at the junction.
            let pin = CGPoint(x: 382, y: 278)
            UIColor(red: 0.78, green: 0.20, blue: 0.22, alpha: 1).setFill()
            ctx.fillEllipse(in: CGRect(x: pin.x - 34, y: pin.y - 34, width: 68, height: 68))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pin.x - 22, y: pin.y + 18))
            ctx.addLine(to: CGPoint(x: pin.x + 22, y: pin.y + 18))
            ctx.addLine(to: CGPoint(x: pin.x, y: pin.y + 62))
            ctx.closePath()
            ctx.fillPath()
            UIColor.white.setFill()
            ctx.fillEllipse(in: CGRect(x: pin.x - 12, y: pin.y - 12, width: 24, height: 24))

            // The card along the bottom — the part that makes it worth keeping.
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 452, width: rect.width, height: 168))
            text("Zahnarztpraxis am Hofgarten", at: CGPoint(x: 44, y: 476),
                 size: 46, color: .black, bold: true)
            text("Ludwigstraße 12  ·  0.8 km", at: CGPoint(x: 44, y: 536),
                 size: 34, color: .darkGray)
            text("Opens 08:00  ·  Closed Fridays", at: CGPoint(x: 44, y: 578),
                 size: 32, color: UIColor(red: 0.20, green: 0.45, blue: 0.25, alpha: 1))
        }
    }

    private static func render(size: CGSize, background: UIColor,
                               _ body: (CGContext, CGRect) -> Void) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            background.setFill()
            context.cgContext.fill(rect)
            body(context.cgContext, rect)
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    private static func text(_ string: String, at point: CGPoint, size: CGFloat,
                             color: UIColor, bold: Bool = false) {
        let font = bold ? UIFont.systemFont(ofSize: size, weight: .semibold)
                        : UIFont.systemFont(ofSize: size)
        string.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    /// Not a real barcode — just the right rhythm of bars. It only has to read
    /// as "a label with a barcode on it" at thumbnail size.
    private static func barcode(in rect: CGRect, ctx: CGContext) {
        UIColor.black.setFill()
        var x = rect.minX
        var seed = 7
        while x < rect.maxX - 4 {
            seed = (seed &* 31 &+ 17) % 97
            let width = CGFloat(2 + seed % 4)
            if seed % 3 != 0 {
                ctx.fill(CGRect(x: x, y: rect.minY, width: width, height: rect.height))
            }
            x += width + CGFloat(2 + seed % 3)
        }
    }
}
#endif
