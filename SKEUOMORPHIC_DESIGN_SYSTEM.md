# Soft-Skeuomorphic Design System — SwiftUI / iOS

**Version 1.0 · Codename "Cream"**

> This file is the single source of truth for the visual language of this project.
> It is written to be read by an AI coding agent *and* a human. Every rule is
> stated as a constraint, not a suggestion. When you are unsure, re-read
> §1 (Physics Contract) — it resolves almost every ambiguity.

---

## 0. How to use this file

1. Read §1 and §4 first. They define *why* every surface looks the way it does.
2. Never invent shadow, radius, spacing or color values. Use tokens from §2, §3, §5, §7.
3. When building a new component, find the closest recipe in §9 and extend it.
4. Before shipping any view, run the checklist in §13.
5. The rules block in §14 is meant to be copied into `CLAUDE.md` at repo root.

**Two hard constraints for this system:**

- **No textures.** No image fills, no noise layers, no grain overlays, no leather,
  no fabric, no paper scans, no `Image(...).resizable()` used as a surface fill.
  All depth comes from *geometry, gradients, shadows and light*. If a surface
  needs to feel material, it does so through bevel and light — never through a
  bitmap.
- **No fixed palette.** Every color in the UI resolves through a swappable
  `SkeuPalette`. The default is cream + light brown, but the entire system must
  re-theme correctly by replacing one struct. Never hardcode a hex value inside
  a component.

---

## 1. Design thesis & the physics contract

### 1.1 Thesis

This is **soft skeuomorphism**: objects that feel physically present and pressable,
without imitating a specific real-world material. It sits between neumorphism
(too low contrast, mushy) and 2013-era skeuomorphism (too literal, textured).

The mental model: every UI element is a piece of **matte, slightly soft,
injection-molded material** — think a warm ceramic, a matte resin, a bar of
pressed clay — lit by a single soft light. It has thickness. It casts a shadow.
Its top edge catches light. Its bottom edge is in shade. Pressing it moves it.

### 1.2 The Physics Contract

These five laws are non-negotiable. Every visual decision follows from them.

**Law 1 — One light source.**
A single soft key light sits above and slightly in front of the screen, at
roughly 10 o'clock. Direction vector: `(x: -0.25, y: -1.0)`.
Consequence: highlights are on **top** edges (and very slightly leading edges),
shadows fall **downward** and slightly trailing. Never invert this per-component.

**Law 2 — Light falls off, it does not glow.**
Highlights are white at low alpha, applied as a *gradient stroke* or a *top-biased
overlay*, never as a `.shadow(color: .white)` glow and never as a full-opacity line.
Max highlight alpha anywhere in the system: `0.60`.

**Law 3 — Every object has thickness.**
A surface is never a flat filled rectangle. It is minimally:
fill gradient + rim light + rim shade + ambient shadow + contact shadow.
See §4.2 for the five-layer anatomy. A view with only a `.fill()` and a
`.shadow()` is not compliant.

**Law 4 — Depth is a ladder, not a spectrum.**
There are exactly six depth levels (§4.1). A component picks one. There is no
"a bit more shadow". If a design needs an in-between, the ladder is wrong,
not the component.

**Law 5 — Pressing costs depth.**
Interactive elements move *down the ladder* on press: they shrink slightly,
lose outer shadow, gain inner shadow. The transition is spring-based and
always uses the same spring (§8.2). A press that only changes opacity is
non-compliant.

### 1.3 What this system is not

| Not this | Because |
|---|---|
| Neumorphism | Neumorphism puts the object and background at the same color and relies on symmetric double shadows. Here, surfaces are *lighter* than the canvas and shadows are asymmetric and directional. |
| Glassmorphism | No blur-behind as the primary depth cue. Blur is used only for true overlays (§9.12). |
| Material Design elevation | MD shadows are neutral gray and hue-less. Ours are tinted with the palette's shadow hue (§5.4). |
| Literal skeuomorphism | No representational textures, no simulated stitching by bitmap, no wood/leather/metal imagery. |

---

## 2. Theme architecture — the swappable palette

### 2.1 Principle

A theme is **one struct**. Swapping it re-skins the entire app. Components never
read raw colors; they read *roles* from the environment.

Roles are semantic (`material`, `recess`, `ink`, `accent`), never literal
(`brown`, `cream`, `lightBeige`).

### 2.2 The palette type

```swift
import SwiftUI

/// The complete color contract of the design system.
/// Swap the instance in the environment to re-theme the app.
public struct SkeuPalette: Equatable, Sendable {

    // MARK: Ground
    /// The page behind everything. Always the *darkest* light-mode neutral
    /// among the surface roles, so raised material reads as lifted.
    public var canvas: Color
    /// Optional secondary ground for grouped/sectioned scenes.
    public var canvasAlt: Color

    // MARK: Material (raised surfaces)
    /// Base body color of a raised object. Gradient stops derive from this.
    public var material: Color
    /// Top stop of the material gradient (lighter).
    public var materialTop: Color
    /// Bottom stop of the material gradient (darker).
    public var materialBottom: Color

    // MARK: Recess (carved-in surfaces)
    /// Fill of wells, tracks, input fields, inset containers.
    public var recess: Color
    /// Bottom stop of the recess gradient (lighter — light pools at the base).
    public var recessBottom: Color

    // MARK: Edges
    /// Rim light on top edges. Applied at ≤0.60 alpha.
    public var edgeLight: Color
    /// Rim shade on bottom edges.
    public var edgeShade: Color
    /// Hairline separating stacked material of the same elevation.
    public var seam: Color

    // MARK: Ink
    public var ink: Color          // primary text/icons on material
    public var inkMuted: Color     // secondary text, ≥ 4.5:1 required
    public var inkFaint: Color     // decorative labels, ≥ 3:1 required
    public var inkOnAccent: Color  // text on accent fills

    // MARK: Accent
    public var accent: Color       // primary action body
    public var accentTop: Color    // gradient top
    public var accentBottom: Color // gradient bottom

    // MARK: Semantic
    public var positive: Color
    public var caution: Color
    public var critical: Color

    // MARK: Shadow
    /// Shadows are TINTED, never pure black. This is the tint.
    public var shadow: Color
    /// Global multiplier on all shadow alphas. Lower for dark themes.
    public var shadowIntensity: Double

    /// Whether this palette is a dark theme. Flips a few internal rules
    /// (see §2.6) without requiring component changes.
    public var isDark: Bool
}
```

### 2.3 Derivation — build a whole palette from one seed

Any brand color can generate a compliant palette. This is the interchange
mechanism: designers hand over **one** color, the system derives the rest.

```swift
public extension SkeuPalette {

    /// Derives a full palette from a single material seed color.
    /// - Parameters:
    ///   - seed: the body color of raised surfaces
    ///   - accent: optional action color; defaults to a deepened, saturated seed
    ///   - dark: build a dark-mode variant
    static func derived(from seed: Color,
                        accent accentSeed: Color? = nil,
                        dark: Bool = false) -> SkeuPalette {

        let s = seed.hsb
        let acc = (accentSeed ?? seed.shifted(sat: +0.22, bri: -0.24)).hsb

        // Light-mode ladder. Canvas sits BELOW material in brightness so that
        // raised objects read as lifted (Law 3).
        if !dark {
            return SkeuPalette(
                canvas:         Color(h: s.h, s: s.s * 0.42, b: min(s.b * 1.06, 0.97)),
                canvasAlt:      Color(h: s.h, s: s.s * 0.50, b: min(s.b * 1.01, 0.95)),

                material:       seed,
                materialTop:    Color(h: s.h, s: s.s * 0.82, b: min(s.b * 1.09, 0.99)),
                materialBottom: Color(h: s.h, s: min(s.s * 1.12, 1), b: s.b * 0.88),

                recess:         Color(h: s.h, s: min(s.s * 1.18, 1), b: s.b * 0.86),
                recessBottom:   Color(h: s.h, s: min(s.s * 1.05, 1), b: s.b * 0.95),

                edgeLight:      .white,
                edgeShade:      Color(h: s.h, s: min(s.s * 1.4, 1), b: s.b * 0.42),
                seam:           Color(h: s.h, s: s.s * 0.35, b: min(s.b * 1.14, 1)),

                ink:            Color(h: s.h, s: min(s.s * 1.35, 1), b: s.b * 0.26),
                inkMuted:       Color(h: s.h, s: min(s.s * 1.15, 1), b: s.b * 0.46),
                inkFaint:       Color(h: s.h, s: s.s * 0.9,          b: s.b * 0.62),
                inkOnAccent:    Color(h: acc.h, s: acc.s * 0.10, b: 0.99),

                accent:         Color(h: acc.h, s: acc.s, b: acc.b),
                accentTop:      Color(h: acc.h, s: acc.s * 0.88, b: min(acc.b * 1.14, 1)),
                accentBottom:   Color(h: acc.h, s: min(acc.s * 1.10, 1), b: acc.b * 0.84),

                positive:       Color(h: 0.35, s: 0.45, b: 0.55),
                caution:        Color(h: 0.10, s: 0.62, b: 0.72),
                critical:       Color(h: 0.02, s: 0.58, b: 0.62),

                shadow:         Color(h: s.h, s: min(s.s * 1.5, 1), b: s.b * 0.22),
                shadowIntensity: 1.0,
                isDark:         false
            )
        }

        // Dark ladder: material sits ABOVE canvas in brightness, shadows soften,
        // rim light weakens, rim shade strengthens.
        return SkeuPalette(
            canvas:         Color(h: s.h, s: min(s.s * 0.9, 1), b: 0.10),
            canvasAlt:      Color(h: s.h, s: min(s.s * 0.9, 1), b: 0.13),

            material:       Color(h: s.h, s: s.s * 0.72, b: 0.20),
            materialTop:    Color(h: s.h, s: s.s * 0.62, b: 0.26),
            materialBottom: Color(h: s.h, s: s.s * 0.80, b: 0.16),

            recess:         Color(h: s.h, s: s.s * 0.85, b: 0.12),
            recessBottom:   Color(h: s.h, s: s.s * 0.75, b: 0.17),

            edgeLight:      Color(h: s.h, s: 0.10, b: 1.0),
            edgeShade:      .black,
            seam:           Color(h: s.h, s: s.s * 0.4, b: 0.34),

            ink:            Color(h: s.h, s: 0.06, b: 0.96),
            inkMuted:       Color(h: s.h, s: 0.10, b: 0.74),
            inkFaint:       Color(h: s.h, s: 0.12, b: 0.55),
            inkOnAccent:    Color(h: acc.h, s: 0.08, b: 0.99),

            accent:         Color(h: acc.h, s: acc.s * 0.95, b: min(acc.b * 1.25, 0.86)),
            accentTop:      Color(h: acc.h, s: acc.s * 0.85, b: min(acc.b * 1.45, 0.95)),
            accentBottom:   Color(h: acc.h, s: acc.s,        b: min(acc.b * 1.05, 0.70)),

            positive:       Color(h: 0.35, s: 0.42, b: 0.72),
            caution:        Color(h: 0.10, s: 0.60, b: 0.86),
            critical:       Color(h: 0.02, s: 0.55, b: 0.80),

            shadow:         .black,
            shadowIntensity: 0.72,
            isDark:         true
        )
    }
}
```

### 2.4 Default theme — Cream

**This is the shipping default.** Warm cream ground, light-brown material,
caramel accent. Every screenshot, preview and snapshot test uses this unless
explicitly testing theming.

```swift
public extension SkeuPalette {

    /// The default theme. Cream canvas, light-brown material, caramel accent.
    static let cream = SkeuPalette(
        canvas:         Color(hex: 0xF2EBDF),
        canvasAlt:      Color(hex: 0xEAE0D0),

        material:       Color(hex: 0xDDCBAF),
        materialTop:    Color(hex: 0xEBDCC3),
        materialBottom: Color(hex: 0xCBB694),

        recess:         Color(hex: 0xC9B392),
        recessBottom:   Color(hex: 0xD8C6A8),

        edgeLight:      Color.white,
        edgeShade:      Color(hex: 0x6A5233),
        seam:           Color(hex: 0xFAF1E1),

        ink:            Color(hex: 0x3B2E1C),
        inkMuted:       Color(hex: 0x77664C),
        inkFaint:       Color(hex: 0x9A8A70),
        inkOnAccent:    Color(hex: 0xFFF7EA),

        accent:         Color(hex: 0xA9713F),
        accentTop:      Color(hex: 0xC08B55),
        accentBottom:   Color(hex: 0x8C5B30),

        positive:       Color(hex: 0x5C7A52),
        caution:        Color(hex: 0xB98A3C),
        critical:       Color(hex: 0xA6503E),

        shadow:         Color(hex: 0x4A3720),
        shadowIntensity: 1.0,
        isDark:         false
    )
}
```

**Cream token table (for reference / design handoff):**

| Role | Hex | Notes |
|---|---|---|
| `canvas` | `#F2EBDF` | page ground |
| `canvasAlt` | `#EAE0D0` | grouped sections |
| `material` | `#DDCBAF` | raised body |
| `materialTop` | `#EBDCC3` | gradient stop 0 |
| `materialBottom` | `#CBB694` | gradient stop 1 |
| `recess` | `#C9B392` | well fill |
| `recessBottom` | `#D8C6A8` | well gradient stop 1 |
| `edgeLight` | `#FFFFFF` | applied ≤ 0.60α |
| `edgeShade` | `#6A5233` | applied ≤ 0.35α |
| `seam` | `#FAF1E1` | hairline, ≤ 0.45α |
| `ink` | `#3B2E1C` | 10.1:1 on material |
| `inkMuted` | `#77664C` | 4.7:1 on material |
| `inkFaint` | `#9A8A70` | 3.1:1 — decorative only |
| `accent` | `#A9713F` | primary action |
| `accentTop` | `#C08B55` | |
| `accentBottom` | `#8C5B30` | |
| `inkOnAccent` | `#FFF7EA` | 5.4:1 on accent |
| `shadow` | `#4A3720` | tint, never black |

### 2.5 Alternate presets

Ship these so theming is provably real. Each is one line.

```swift
public extension SkeuPalette {
    static let clay   = SkeuPalette.derived(from: Color(hex: 0xC98B6E))
    static let moss   = SkeuPalette.derived(from: Color(hex: 0xA8B79A),
                                            accent: Color(hex: 0x4E6B45))
    static let slate  = SkeuPalette.derived(from: Color(hex: 0xB4BAC4),
                                            accent: Color(hex: 0x3F5670))
    static let ember  = SkeuPalette.derived(from: Color(hex: 0xC96F60),
                                            accent: Color(hex: 0x8E3324))
    static let creamDark = SkeuPalette.derived(from: Color(hex: 0xDDCBAF),
                                               accent: Color(hex: 0xC08B55),
                                               dark: true)
}
```

### 2.6 Environment injection

```swift
private struct SkeuPaletteKey: EnvironmentKey {
    static let defaultValue: SkeuPalette = .cream
}

public extension EnvironmentValues {
    var skeu: SkeuPalette {
        get { self[SkeuPaletteKey.self] }
        set { self[SkeuPaletteKey.self] = newValue }
    }
}

public extension View {
    func skeuTheme(_ palette: SkeuPalette) -> some View {
        environment(\.skeu, palette)
    }
}
```

Usage in every component — **this is the only permitted way to read color**:

```swift
struct SomeView: View {
    @Environment(\.skeu) private var skeu
    var body: some View {
        Text("Hello").foregroundStyle(skeu.ink)
    }
}
```

Automatic light/dark:

```swift
struct ThemedRoot<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content
    var body: some View {
        content.skeuTheme(scheme == .dark ? .creamDark : .cream)
    }
}
```

### 2.7 Color utilities (required helpers)

```swift
public extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: alpha)
    }

    init(h: Double, s: Double, b: Double, opacity: Double = 1) {
        self.init(hue: h.clamped01, saturation: s.clamped01,
                  brightness: b.clamped01, opacity: opacity)
    }

    /// HSB decomposition. Uses UIColor bridging; cache results in themes.
    var hsb: (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }

    func shifted(sat: Double = 0, bri: Double = 0, hue: Double = 0) -> Color {
        let c = hsb
        return Color(h: c.h + hue, s: c.s + sat, b: c.b + bri)
    }
}

extension Double { var clamped01: Double { min(max(self, 0), 1) } }
```

---

## 3. Geometry tokens

### 3.1 Corner radius

**Always `.continuous`.** `RoundedRectangle(cornerRadius: r, style: .continuous)`.
Never `.circular`. A circular corner reads as cheap in this system.

```swift
public enum SkeuRadius {
    public static let xs:  CGFloat = 8    // badges, tiny chips
    public static let sm:  CGFloat = 12   // inline controls, small wells
    public static let md:  CGFloat = 16   // buttons, list rows
    public static let lg:  CGFloat = 22   // cards, panels
    public static let xl:  CGFloat = 28   // sheets, large tiles
    public static let xxl: CGFloat = 40   // hero tiles, app-icon-like objects
    public static let pill: CGFloat = 999 // capsules
}
```

**Nesting law.** A child inside a parent uses:
`childRadius = parentRadius − parentInsetPadding`, floored at `SkeuRadius.xs`.
Concentric corners are mandatory. A 22pt card with 10pt padding contains
12pt-radius children. Violating this is the single most visible amateur tell.

```swift
public func nestedRadius(_ parent: CGFloat, inset: CGFloat) -> CGFloat {
    max(parent - inset, SkeuRadius.xs)
}
```

### 3.2 Stroke widths

| Token | pt | Use |
|---|---|---|
| `hairline` | `1 / displayScale` | seams, dividers |
| `rim` | `1.0` | rim light / rim shade stroke |
| `rimThick` | `1.5` | rim on ≥ 28pt radius surfaces |
| `focus` | `2.5` | keyboard/VoiceOver focus ring |

### 3.3 Control heights

| Token | pt |
|---|---|
| `controlXS` | 28 |
| `controlSM` | 36 |
| `controlMD` | 44 ← default, matches HIG minimum |
| `controlLG` | 54 |
| `controlXL` | 64 |

Minimum tap target is **44 × 44** regardless of visual size. Use
`.contentShape(Rectangle())` with padding to expand hit area without
changing appearance.

---

## 4. The elevation system — the core of the look

### 4.1 The depth ladder

Six levels. A component picks exactly one. `e0` and `e1` are *below* the plane.

| Level | Name | Reads as | Typical use |
|---|---|---|---|
| `e0` | **Carved** | cut deep into the ground | slider tracks, progress rails, code blocks |
| `e1` | **Recessed** | pressed inward | input fields, wells, pressed buttons, selected segment background |
| `e2` | **Flush** | sitting on the surface | list rows inside a card, quiet chips |
| `e3` | **Raised** | lifted, pressable | buttons, cards, tiles ← **the default object** |
| `e4` | **Floating** | hovering above content | floating toolbars, FABs, popovers |
| `e5` | **Overlay** | detached from the page | sheets, modals, dialogs |

```swift
public enum SkeuDepth: Int, CaseIterable {
    case carved = 0, recessed, flush, raised, floating, overlay
}
```

### 4.2 Anatomy of a raised surface (e3)

A compliant raised surface is **five layers**, bottom to top:

```
┌─ 5. CONTENT ─────────────────────────────┐  text, icons
│  ┌─ 4. RIM SHADE ───────────────────┐    │  1pt stroke, gradient
│  │  ┌─ 3. RIM LIGHT ────────────┐   │    │  1pt stroke, gradient (top only)
│  │  │  ┌─ 2. SHEEN ─────────┐   │   │    │  top-biased white overlay, ≤0.10α
│  │  │  │  1. BODY GRADIENT  │   │   │    │  materialTop → materialBottom
│  │  │  └────────────────────┘   │   │    │
│  │  └───────────────────────────┘   │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘
       ↓ 6. AMBIENT SHADOW (large, soft)
       ↓ 7. CONTACT SHADOW (small, tight, darker)
```

Layer specs:

1. **Body gradient** — `LinearGradient(colors: [materialTop, materialBottom],
   startPoint: UnitPoint(x: 0.35, y: 0), endPoint: UnitPoint(x: 0.65, y: 1))`.
   The x-offset encodes the 10 o'clock light. Never a flat fill.
2. **Sheen** — a `LinearGradient` from `white.opacity(0.10)` at `y: 0` to
   `.clear` at `y: 0.55`. Optional below 40pt tall. Mandatory above 80pt.
3. **Rim light** — stroke with a gradient from `edgeLight.opacity(0.55)` at
   top to `.clear` at 55% height. It lights only the top arc.
4. **Rim shade** — stroke with a gradient from `.clear` at 45% height to
   `edgeShade.opacity(0.22)` at bottom. Draw *after* rim light.
5. **Content** — inherits `ink`.
6. **Ambient shadow** — wide, low alpha, offset down by ~⅓ of blur.
7. **Contact shadow** — tight, higher alpha, small offset. Grounds the object.

### 4.3 Anatomy of a recessed surface (e0/e1)

Inverted, and the light *pools at the bottom* of the cavity:

1. **Body gradient** — `recess → recessBottom`, top to bottom
   (darker at top: the near wall shades the cavity).
2. **Inner shadow** — cast from the top edge downward, `shadow.opacity(0.30)`,
   blur 4, offset `(0, 2)`.
3. **Inner bottom light** — `edgeLight.opacity(0.35)`, blur 2, offset `(0, -1)`.
4. **Rim shade on the outside top edge** — 1pt, `edgeShade.opacity(0.18)`.
5. **No outer shadow.** A recessed object never casts.

### 4.4 Shadow token table

All alphas are multiplied by `palette.shadowIntensity` and use `palette.shadow`
as the color. **Never `.black`, never `.gray`.**

| Depth | Ambient (r / y / α) | Contact (r / y / α) | Inner (r / y / α) | Rim light α | Rim shade α |
|---|---|---|---|---|---|
| `e0` carved | — | — | 6 / 3 / 0.38 | 0.30 (bottom) | 0.22 (top) |
| `e1` recessed | — | — | 4 / 2 / 0.28 | 0.24 (bottom) | 0.16 (top) |
| `e2` flush | 6 / 2 / 0.06 | 1 / 1 / 0.08 | — | 0.30 | 0.10 |
| `e3` raised | 14 / 6 / 0.12 | 2 / 1 / 0.14 | — | 0.50 | 0.20 |
| `e4` floating | 26 / 12 / 0.16 | 4 / 2 / 0.16 | — | 0.55 | 0.24 |
| `e5` overlay | 44 / 20 / 0.22 | 6 / 3 / 0.18 | — | 0.60 | 0.28 |

Dark themes: `shadowIntensity = 0.72`, and rim-light alphas are multiplied by
`0.5` (light behaves differently on dark material — a bright rim on a dark
object reads as chrome, which we do not want).

### 4.5 Implementation

```swift
// MARK: - Inner shadow

public struct InnerShadow<S: Shape>: ViewModifier {
    let shape: S
    let color: Color
    let radius: CGFloat
    let offset: CGSize

    public func body(content: Content) -> some View {
        content.overlay {
            shape
                .stroke(color, lineWidth: radius * 2)
                .offset(x: offset.width, y: offset.height)
                .blur(radius: radius)
                .mask(shape.fill())
                .allowsHitTesting(false)
        }
    }
}

public extension View {
    func innerShadow<S: Shape>(_ shape: S, color: Color,
                               radius: CGFloat, offset: CGSize) -> some View {
        modifier(InnerShadow(shape: shape, color: color,
                             radius: radius, offset: offset))
    }
}

// MARK: - The surface modifier (use this for EVERY object)

public struct SkeuSurface<S: Shape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    let depth: SkeuDepth
    let tint: Color?        // nil = material; pass skeu.accent for actions
    let sheen: Bool

    public func body(content: Content) -> some View {
        content
            .background { fill }
            .overlay { sheenLayer }
            .overlay { rimLight }
            .overlay { rimShade }
            .modifier(InnerLayer(shape: shape, depth: depth))
            .clipShape(shape)
            .modifier(OuterShadows(depth: depth))
    }

    // 1. body gradient
    private var fill: some View {
        let top: Color, bottom: Color
        switch (depth, tint) {
        case (_, .some(let t)):
            top = t.shifted(bri: +0.08); bottom = t.shifted(bri: -0.08)
        case (.carved, _), (.recessed, _):
            top = skeu.recess;      bottom = skeu.recessBottom
        default:
            top = skeu.materialTop; bottom = skeu.materialBottom
        }
        return shape.fill(
            LinearGradient(colors: [top, bottom],
                           startPoint: UnitPoint(x: 0.35, y: 0),
                           endPoint:   UnitPoint(x: 0.65, y: 1))
        )
    }

    // 2. sheen
    @ViewBuilder private var sheenLayer: some View {
        if sheen && depth.rawValue >= SkeuDepth.flush.rawValue {
            shape.fill(
                LinearGradient(
                    stops: [.init(color: .white.opacity(0.10), location: 0),
                            .init(color: .clear,               location: 0.55)],
                    startPoint: .top, endPoint: .bottom)
            )
            .allowsHitTesting(false)
        }
    }

    // 3. rim light
    private var rimLight: some View {
        let a = skeu.isDark ? depth.rimLight * 0.5 : depth.rimLight
        let isRecessed = depth.rawValue <= SkeuDepth.recessed.rawValue
        return shape.stroke(
            LinearGradient(
                stops: [.init(color: skeu.edgeLight.opacity(isRecessed ? 0 : a), location: 0),
                        .init(color: .clear, location: 0.55),
                        .init(color: skeu.edgeLight.opacity(isRecessed ? a : 0), location: 1)],
                startPoint: .top, endPoint: .bottom),
            lineWidth: 1
        )
        .allowsHitTesting(false)
    }

    // 4. rim shade
    private var rimShade: some View {
        let a = depth.rimShade
        let isRecessed = depth.rawValue <= SkeuDepth.recessed.rawValue
        return shape.stroke(
            LinearGradient(
                stops: [.init(color: skeu.edgeShade.opacity(isRecessed ? a : 0), location: 0),
                        .init(color: .clear, location: 0.45),
                        .init(color: skeu.edgeShade.opacity(isRecessed ? 0 : a), location: 1)],
                startPoint: .top, endPoint: .bottom),
            lineWidth: 1
        )
        .allowsHitTesting(false)
    }

    private struct InnerLayer: ViewModifier {
        @Environment(\.skeu) private var skeu
        let shape: S
        let depth: SkeuDepth
        func body(content: Content) -> some View {
            guard let inner = depth.inner else { return AnyView(content) }
            return AnyView(
                content
                    .innerShadow(shape,
                                 color: skeu.shadow.opacity(inner.alpha * skeu.shadowIntensity),
                                 radius: inner.radius,
                                 offset: .init(width: 0, height: inner.y))
                    .innerShadow(shape,
                                 color: skeu.edgeLight.opacity(depth.rimLight),
                                 radius: 2, offset: .init(width: 0, height: -1))
            )
        }
    }

    private struct OuterShadows: ViewModifier {
        @Environment(\.skeu) private var skeu
        let depth: SkeuDepth
        func body(content: Content) -> some View {
            var v = AnyView(content)
            if let amb = depth.ambient {
                v = AnyView(v.shadow(color: skeu.shadow.opacity(amb.alpha * skeu.shadowIntensity),
                                     radius: amb.radius, x: 0, y: amb.y))
            }
            if let con = depth.contact {
                v = AnyView(v.shadow(color: skeu.shadow.opacity(con.alpha * skeu.shadowIntensity),
                                     radius: con.radius, x: 0, y: con.y))
            }
            return v
        }
    }
}

public extension View {
    /// The one entry point for depth. Every visible object uses this.
    func skeuSurface<S: Shape>(_ shape: S,
                               depth: SkeuDepth = .raised,
                               tint: Color? = nil,
                               sheen: Bool = true) -> some View {
        modifier(SkeuSurface(shape: shape, depth: depth, tint: tint, sheen: sheen))
    }

    /// Convenience for the 95% case.
    func skeuSurface(radius: CGFloat = SkeuRadius.lg,
                     depth: SkeuDepth = .raised,
                     tint: Color? = nil,
                     sheen: Bool = true) -> some View {
        skeuSurface(RoundedRectangle(cornerRadius: radius, style: .continuous),
                    depth: depth, tint: tint, sheen: sheen)
    }
}

// MARK: - Depth → numbers (the table in §4.4, encoded)

public extension SkeuDepth {
    struct Shadow { let radius: CGFloat; let y: CGFloat; let alpha: Double }

    var ambient: Shadow? {
        switch self {
        case .carved, .recessed: return nil
        case .flush:    return .init(radius: 6,  y: 2,  alpha: 0.06)
        case .raised:   return .init(radius: 14, y: 6,  alpha: 0.12)
        case .floating: return .init(radius: 26, y: 12, alpha: 0.16)
        case .overlay:  return .init(radius: 44, y: 20, alpha: 0.22)
        }
    }
    var contact: Shadow? {
        switch self {
        case .carved, .recessed: return nil
        case .flush:    return .init(radius: 1, y: 1, alpha: 0.08)
        case .raised:   return .init(radius: 2, y: 1, alpha: 0.14)
        case .floating: return .init(radius: 4, y: 2, alpha: 0.16)
        case .overlay:  return .init(radius: 6, y: 3, alpha: 0.18)
        }
    }
    var inner: Shadow? {
        switch self {
        case .carved:   return .init(radius: 6, y: 3, alpha: 0.38)
        case .recessed: return .init(radius: 4, y: 2, alpha: 0.28)
        default:        return nil
        }
    }
    var rimLight: Double {
        switch self {
        case .carved: 0.30; case .recessed: 0.24; case .flush: 0.30
        case .raised: 0.50; case .floating: 0.55; case .overlay: 0.60
        }
    }
    var rimShade: Double {
        switch self {
        case .carved: 0.22; case .recessed: 0.16; case .flush: 0.10
        case .raised: 0.20; case .floating: 0.24; case .overlay: 0.28
        }
    }
    /// One step down the ladder — used for press states.
    var pressed: SkeuDepth {
        switch self {
        case .carved, .recessed: .carved
        case .flush:    .recessed
        case .raised:   .recessed
        case .floating: .raised
        case .overlay:  .overlay
        }
    }
}
```

### 4.6 Seams (optional detail)

A **seam** is a 1pt inset hairline that traces a surface ~6–8pt inside its
edge. It is the *only* decorative detail permitted, it is **not** a texture,
and it must be drawn with `strokeBorder`, never with an image.

Use it on: large tiles, wallet-style stacked cards, sheet headers.
Do **not** use it on: buttons under 44pt, list rows, inputs.

```swift
public struct Seam: ViewModifier {
    @Environment(\.skeu) private var skeu
    var radius: CGFloat
    var inset: CGFloat = 7
    var dashed: Bool = false
    var opacity: Double = 0.35

    public func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: nestedRadius(radius, inset: inset),
                             style: .continuous)
                .strokeBorder(skeu.seam.opacity(opacity),
                              style: StrokeStyle(lineWidth: 1,
                                                 dash: dashed ? [4, 4] : []))
                .padding(inset)
                .allowsHitTesting(false)
        }
    }
}

public extension View {
    func seam(radius: CGFloat, inset: CGFloat = 7,
              dashed: Bool = false, opacity: Double = 0.35) -> some View {
        modifier(Seam(radius: radius, inset: inset,
                      dashed: dashed, opacity: opacity))
    }
}
```

---

## 5. Color roles & states

### 5.1 Role → usage map

| Role | Where it may appear | Where it may NOT |
|---|---|---|
| `canvas` | scroll background, window background | any raised object |
| `material*` | all `e2`–`e5` surfaces | text |
| `recess*` | all `e0`–`e1` surfaces | text |
| `ink` | body text, primary icons | large fills |
| `inkMuted` | secondary labels, captions | primary CTA labels |
| `inkFaint` | metadata, section eyebrows | anything conveying meaning alone |
| `accent*` | primary action fill, active segment, selection | large background areas > 25% of screen |
| `positive/caution/critical` | status only | decoration |

### 5.2 State matrix

Every interactive element must define all six states.

| State | Depth | Fill | Scale | Extra |
|---|---|---|---|---|
| rest | as declared | base gradient | 1.00 | — |
| hover (iPadOS pointer) | +0 | `+4%` brightness | 1.01 | — |
| pressed | `.pressed` | `−5%` brightness | 0.97 | inner shadow appears |
| selected | `e1` recessed | accent tint @ 0.16 | 1.00 | accent 1pt rim |
| disabled | `e2` flush | desaturate 60%, α 0.5 | 1.00 | no shadow, no sheen |
| focused | unchanged | unchanged | 1.00 | 2.5pt accent ring, 3pt outside |

### 5.3 Tinting rule

To tint a surface with accent, **do not** replace the material color. Pass
`tint:` to `skeuSurface`, which derives its own ±8% brightness gradient.
Tinted surfaces keep the same rim/shadow treatment as untinted ones.

### 5.4 Shadow hue rule

Shadows always use `palette.shadow`, which is a dark, saturated version of the
material hue — **never** neutral black. On the Cream palette this is `#4A3720`,
a deep warm brown. Neutral shadows make warm material look dirty.

---

## 6. Typography

### 6.1 Families

| Role | Font | Rationale |
|---|---|---|
| Display | `.system(.largeTitle, design: .serif)` (New York) | the reference uses a high-contrast serif for the wordmark; New York is the system serif and needs no bundling |
| UI | `.system(design: .default)` (SF Pro) | body, labels, controls |
| Numeric | `.system(design: .rounded)` + `.monospacedDigit()` | balances, counters, timers |

Never bundle a display font unless the brand requires it. If one is bundled,
register it in `SkeuFont` and never call `Font.custom` at a call site.

### 6.2 Scale

```swift
public enum SkeuFont {
    public static let display   = Font.system(size: 40, weight: .regular, design: .serif).italic()
    public static let title1    = Font.system(size: 28, weight: .semibold)
    public static let title2    = Font.system(size: 22, weight: .semibold)
    public static let title3    = Font.system(size: 18, weight: .semibold)
    public static let body      = Font.system(size: 16, weight: .regular)
    public static let bodyEmph  = Font.system(size: 16, weight: .medium)
    public static let callout   = Font.system(size: 15, weight: .regular)
    public static let caption   = Font.system(size: 13, weight: .regular)
    public static let eyebrow   = Font.system(size: 11, weight: .semibold)   // + tracking
    public static let numeral   = Font.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit()
}
```

**Eyebrow style** (the `TOOL / MADE IN FIGMA` labels in the reference):
`eyebrow` + `.textCase(.uppercase)` + `.tracking(0.8)` + `inkFaint`.
Always in a two-line stack: label on top in `inkFaint`, value below in `inkMuted`.

### 6.3 Text on material

- Body text carries **no shadow**. Ever.
- The single permitted exception: a display numeral debossed into a surface
  may use the *deboss* treatment (§9.9) — that is a mask effect, not a shadow.
- Minimum body size 15pt. Always support Dynamic Type via `.system(_:)` styles
  in production; the fixed sizes above are the design reference.

---

## 7. Spacing & layout

```swift
public enum SkeuSpace {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 16
    public static let xl:  CGFloat = 20
    public static let xxl: CGFloat = 28
    public static let xxxl: CGFloat = 40
}
```

Rules:

- Screen horizontal margin: `xl` (20).
- Card internal padding: `lg` (16) for ≤ 200pt wide, `xl` (20) above.
- Gap between sibling cards: `md` (12).
- Gap between sections: `xxl` (28).
- Icon-to-label gap inside a control: `sm` (8).
- Vertical rhythm inside a list row: label baseline grid of 4.

**Optical padding.** A leading icon needs ~2pt less leading padding than a text
label to look aligned. Apply `-2` manually for icon-first rows. This is
intentional and must not be "cleaned up".

---

## 8. Motion & interaction physics

### 8.1 Principle

Motion communicates **mass**. Objects in this system are light but not weightless:
they settle quickly with a small overshoot. Nothing linear, nothing bouncy.

### 8.2 The springs

```swift
public enum SkeuMotion {
    /// Press / release. The most-used curve in the system.
    public static let press   = Animation.spring(response: 0.26, dampingFraction: 0.68)
    /// Layout shifts, appearance of inline content.
    public static let layout  = Animation.spring(response: 0.40, dampingFraction: 0.86)
    /// Sheets, large overlays.
    public static let present = Animation.spring(response: 0.52, dampingFraction: 0.84)
    /// State cross-fades where no movement occurs.
    public static let tint    = Animation.easeOut(duration: 0.16)
}
```

### 8.3 The press interaction (canonical)

```swift
public struct SkeuPressStyle: ButtonStyle {
    @Environment(\.skeu) private var skeu
    var radius: CGFloat = SkeuRadius.md
    var depth: SkeuDepth = .raised
    var tint: Color? = nil

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let d = configuration.isPressed ? depth.pressed : depth
        return configuration.label
            .skeuSurface(shape, depth: d, tint: tint,
                         sheen: !configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(SkeuMotion.press, value: configuration.isPressed)
    }
}
```

### 8.4 Haptics

| Interaction | Feedback |
|---|---|
| Button tap | `.impact(.light)` on touch-down, none on release |
| Toggle | `.impact(.rigid)` at the flip |
| Segment change | `.selection` |
| Destructive confirm | `.notification(.warning)` |
| Success | `.notification(.success)` |

Touch-down (not release) is deliberate: it reinforces that the object physically
moved under the finger.

### 8.5 Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
// →  scaleEffect stays 1.0; depth change still applies but with SkeuMotion.tint.
```

Depth changes are *not* removed under Reduce Motion — they are the affordance.
Only scale and any translation are removed.

---

## 9. Component recipes

Each recipe states: shape, depth, padding, typography, states. Extend, don't
reinvent.

### 9.1 Panel / Card

Shape `lg` (22) · Depth `e3` · Padding `xl` (20) · Sheen on · Seam optional.

```swift
public struct SkeuCard<Content: View>: View {
    @Environment(\.skeu) private var skeu
    var radius: CGFloat = SkeuRadius.lg
    var depth: SkeuDepth = .raised
    var padding: CGFloat = SkeuSpace.xl
    var seamed: Bool = false
    @ViewBuilder var content: Content

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .skeuSurface(radius: radius, depth: depth)
            .modifier(ConditionalSeam(on: seamed, radius: radius))
    }
}
```

### 9.2 Well / Inset container

Shape `md` (16) · Depth `e1` · Padding `lg`.
Used for: grouped rows inside a card, quiet stats, code, quotes.

```swift
content.padding(SkeuSpace.lg)
       .skeuSurface(radius: SkeuRadius.md, depth: .recessed, sheen: false)
```

### 9.3 Primary button

Shape `pill` or `md` · Depth `e3` · Tint `accent` · Height `controlMD` (44)
· Label `bodyEmph` in `inkOnAccent`.

```swift
public struct SkeuButton: View {
    @Environment(\.skeu) private var skeu
    let title: String
    var systemImage: String? = nil
    var kind: Kind = .primary
    let action: () -> Void

    public enum Kind { case primary, secondary, quiet, destructive }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SkeuSpace.sm) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(SkeuFont.bodyEmph)
            }
            .foregroundStyle(labelColor)
            .padding(.horizontal, SkeuSpace.xl)
            .frame(height: 44)
            .frame(maxWidth: kind == .primary ? .infinity : nil)
        }
        .buttonStyle(SkeuPressStyle(radius: SkeuRadius.pill,
                                    depth: kind == .quiet ? .flush : .raised,
                                    tint: tint))
    }

    private var tint: Color? {
        switch kind {
        case .primary:     skeu.accent
        case .secondary:   nil
        case .quiet:       nil
        case .destructive: skeu.critical
        }
    }
    private var labelColor: Color {
        switch kind {
        case .primary, .destructive: skeu.inkOnAccent
        case .secondary:             skeu.ink
        case .quiet:                 skeu.inkMuted
        }
    }
}
```

### 9.4 Icon button

Circle · Depth `e3` · 44pt · Icon 17pt semibold `ink`.
The `+` button in the reference: `Circle()`, accent-tinted only when it is the
primary action of the screen, otherwise plain material.

```swift
Button(action: action) { Image(systemName: name).font(.system(size: 17, weight: .semibold)) }
    .frame(width: 44, height: 44)
    .buttonStyle(SkeuPressStyle(radius: 22))
```

### 9.5 Floating toolbar / segmented pill bar

This is the signature component (the red card's `search · person · Projects · +`
row). Anatomy:

- Container: `Capsule()` · Depth `e3` · Height 56 · Horizontal padding 6.
- Items: 44pt tap targets, `Capsule()` each.
- **Selected item**: Depth `e1` *recessed*, tinted with `accent.opacity(0.18)`,
  label in `ink`. The selected item is pressed *into* the bar — this is what
  makes it read as physical.
- Unselected: no surface at all, icon in `inkMuted`.
- Selection movement: `matchedGeometryEffect` with `SkeuMotion.press`.

```swift
public struct SkeuSegmentedBar<Item: Hashable>: View {
    @Environment(\.skeu) private var skeu
    @Namespace private var ns
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> AnyView

    public var body: some View {
        HStack(spacing: SkeuSpace.xxs) {
            ForEach(items, id: \.self) { item in
                Button { withAnimation(SkeuMotion.press) { selection = item } }
                label: {
                    label(item)
                        .frame(height: 44)
                        .padding(.horizontal, SkeuSpace.lg)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(skeu.accent.opacity(0.18))
                                    .innerShadow(Capsule(),
                                                 color: skeu.shadow.opacity(0.28),
                                                 radius: 4, offset: .init(width: 0, height: 2))
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                        .foregroundStyle(selection == item ? skeu.ink : skeu.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .skeuSurface(Capsule(), depth: .raised)
    }
}
```

### 9.6 List row (the "Dashboard / Projects 10 / Account" stack)

Shape `md` (16) · Depth `e3` · Height 56 · Padding leading 16 / trailing 16.
Layout: `icon (18pt, inkMuted) — 12 — title (body, ink) — Spacer — trailing`.
Trailing value in `inkMuted`, `.monospacedDigit()`.

Rows are **individual raised objects with 10pt gaps**, not a grouped table with
dividers. This is a defining characteristic: each row is its own physical slat.

```swift
public struct SkeuRow: View {
    @Environment(\.skeu) private var skeu
    let icon: String
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    public var body: some View {
        Button { action?() } label: {
            HStack(spacing: SkeuSpace.md) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(skeu.inkMuted)
                    .frame(width: 22)
                Text(title).font(SkeuFont.body).foregroundStyle(skeu.ink)
                Spacer(minLength: SkeuSpace.md)
                if let trailing {
                    Text(trailing)
                        .font(SkeuFont.callout.monospacedDigit())
                        .foregroundStyle(skeu.inkMuted)
                }
            }
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: 56)
        }
        .buttonStyle(SkeuPressStyle(radius: SkeuRadius.md))
    }
}
```

### 9.7 Text field

Shape `md` · Depth `e1` recessed · Height 48 · No sheen.
Placeholder `inkFaint`. Focused: accent rim at 1.5pt + focus ring.
The caret uses `accent`.

```swift
TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(skeu.inkFaint))
    .textFieldStyle(.plain)
    .font(SkeuFont.body)
    .foregroundStyle(skeu.ink)
    .tint(skeu.accent)
    .padding(.horizontal, SkeuSpace.lg)
    .frame(height: 48)
    .skeuSurface(radius: SkeuRadius.md, depth: .recessed, sheen: false)
    .overlay {
        if isFocused {
            RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                .strokeBorder(skeu.accent.opacity(0.7), lineWidth: 1.5)
        }
    }
```

### 9.8 Toggle

Track: `Capsule()` 52 × 32 · Depth `e1` (off) → tinted `e1` (on).
Knob: `Circle()` 26pt · Depth `e3` · material fill · travels 20pt.
The knob keeps its shadow in both positions — it is always above the track.

```swift
public struct SkeuToggleStyle: ToggleStyle {
    @Environment(\.skeu) private var skeu
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? skeu.accent.opacity(0.9) : skeu.recess)
                    .innerShadow(Capsule(), color: skeu.shadow.opacity(0.30),
                                 radius: 4, offset: .init(width: 0, height: 2))
                    .frame(width: 52, height: 32)
                Circle()
                    .frame(width: 26, height: 26)
                    .skeuSurface(Circle(), depth: .raised)
                    .padding(3)
            }
            .onTapGesture {
                withAnimation(SkeuMotion.press) { configuration.isOn.toggle() }
            }
        }
    }
}
```

### 9.9 Deboss (engraved text/glyph)

For large numerals or logos that should look stamped into the material.
Two offset copies: a dark one down, a light one up, both clipped to the glyph.

```swift
public struct Deboss: ViewModifier {
    @Environment(\.skeu) private var skeu
    var strength: Double = 1
    public func body(content: Content) -> some View {
        content
            .foregroundStyle(skeu.material.shifted(bri: -0.10))
            .overlay {
                content.foregroundStyle(skeu.edgeLight.opacity(0.45 * strength))
                    .offset(y: 1).blendMode(.overlay).mask(content)
            }
            .shadow(color: skeu.shadow.opacity(0.22 * strength), radius: 0.5, y: -0.5)
    }
}
```

Use on: the `$102,400` balance, watermark logos. **Never on body copy.**

### 9.10 Stacked card wallet

The green wallet in the reference, texture-free version:

- Back plate: `RoundedRectangle(xxl)` · Depth `e3` · seam inset 8, dashed off.
- Cards: `RoundedRectangle(md)` · Depth `e2` · each offset `y: -22 * index`
  and `scaleEffect(1 - 0.03 * index)` behind the front pocket.
- Front pocket: same shape as back plate, clipped to the lower ~55%, Depth `e3`,
  drawn **after** the cards so it overlaps them.
- Pocket top edge gets a strong rim light (`0.55`) — it is the closest edge to
  the light.

```
ZStack(alignment: .bottom) {
    backPlate
    ForEach(cards.indices.reversed()) { i in card(i).offset(y: -CGFloat(i) * 22) }
    pocket   // last → on top
}
```

### 9.11 Badge / counter

`Capsule()` · Depth `e1` · Height 22 · Horizontal padding 8 ·
`caption.monospacedDigit()` in `inkMuted`. Accent-tinted when it represents
an unread/active count.

### 9.12 Sheet / modal

Shape: top corners `xl` (28), bottom 0 · Depth `e5` · Canvas fill = `canvasAlt`.
Backdrop: `Color.black.opacity(0.28)` + `.ultraThinMaterial` **only here**.
Grabber: 36 × 5 capsule, `recess` fill, `e1`, centered, 8pt from top.

### 9.13 Tab bar

Floating capsule bar (§9.5) pinned with `.safeAreaInset(edge: .bottom)`,
16pt horizontal margin, 12pt bottom margin. Never a full-width opaque bar —
the object must float above the canvas so its shadow is visible.

---

## 10. Iconography

- **SF Symbols only**, weight `.medium` or `.semibold`, never `.bold`.
- Hierarchical rendering (`.symbolRenderingMode(.hierarchical)`) with `ink`
  is the default; palette rendering only for status.
- Icons never receive shadows or bevels — only the *object containing them* does.
- Optical sizes: 15pt inline, 17pt in rows/buttons, 20pt in toolbars,
  28pt+ for feature glyphs.
- A feature glyph inside a raised tile may use the deboss treatment (§9.9).

---

## 11. Accessibility

Non-negotiable, checked before merge:

1. **Contrast.** `ink` on `material` ≥ 7:1. `inkMuted` ≥ 4.5:1.
   `inkOnAccent` on `accent` ≥ 4.5:1. `inkFaint` is ≥ 3:1 and may only carry
   decorative or duplicated information.
2. **Depth is never the only signal.** A selected segment is recessed *and*
   tinted *and* has `.accessibilityAddTraits(.isSelected)`.
3. **Increase Contrast** (`@Environment(\.colorSchemeContrast)`): when `.increased`,
   raise all rim alphas by 0.15, darken `inkMuted` to `ink`, and add a 1pt
   `edgeShade` border to every `e2`+ surface.
4. **Reduce Transparency**: replace the sheet's `.ultraThinMaterial` with
   `canvasAlt` at full opacity.
5. **Reduce Motion**: see §8.5.
6. **Dynamic Type**: all recipes must survive `.accessibility3`. Fixed heights
   in §9 become minimums (`.frame(minHeight:)`) when
   `dynamicTypeSize >= .accessibility1`.
7. Every icon-only control has an `.accessibilityLabel`.

---

## 12. File structure

```
Sources/SkeuKit/
├── Theme/
│   ├── SkeuPalette.swift         // §2.2 struct + presets
│   ├── SkeuPalette+Derived.swift // §2.3 derivation math
│   ├── Environment.swift         // §2.6 injection
│   └── Color+Utils.swift         // §2.7
├── Tokens/
│   ├── SkeuRadius.swift
│   ├── SkeuSpace.swift
│   ├── SkeuFont.swift
│   └── SkeuMotion.swift
├── Depth/
│   ├── SkeuDepth.swift           // §4.1 + §4.4 numbers
│   ├── SkeuSurface.swift         // §4.5 the core modifier
│   ├── InnerShadow.swift
│   └── Seam.swift                // §4.6
├── Components/
│   ├── SkeuCard.swift
│   ├── SkeuButton.swift
│   ├── SkeuRow.swift
│   ├── SkeuSegmentedBar.swift
│   ├── SkeuField.swift
│   ├── SkeuToggleStyle.swift
│   ├── SkeuBadge.swift
│   └── SkeuSheet.swift
└── Effects/
    └── Deboss.swift
```

Every component file ends with `#Preview` blocks for: `.cream`, `.creamDark`,
`.moss`, and `.accessibility3` Dynamic Type. A component without all four
previews is incomplete.

---

## 13. Pre-merge checklist

- [ ] No hex literal outside `Theme/`.
- [ ] No `Image` used as a surface fill; no noise/grain/texture asset anywhere.
- [ ] Every surface goes through `skeuSurface`, not a raw `.background` + `.shadow`.
- [ ] Every radius comes from `SkeuRadius`; nested radii follow the nesting law.
- [ ] Every shadow color is `skeu.shadow`, never `.black`/`.gray`.
- [ ] All corners `.continuous`.
- [ ] Interactive elements use `SkeuPressStyle` or replicate all six states.
- [ ] Tap targets ≥ 44×44.
- [ ] Previews exist for cream, creamDark, moss, accessibility3.
- [ ] Swapping the palette to `.slate` produces a coherent screen with zero
      component edits. **This is the acceptance test for theming.**

---

## 14. Anti-patterns (reject on sight)

| Anti-pattern | Why it breaks the system | Do instead |
|---|---|---|
| Flat `.fill(Color)` on a card | violates Law 3 | `skeuSurface` |
| `.shadow(color: .black.opacity(0.2))` | untinted shadow | `skeu.shadow` |
| Symmetric double shadow (light top-left + dark bottom-right at equal strength) | that's neumorphism | asymmetric per §4.4 |
| `cornerRadius:` without `style: .continuous` | wrong corner curve | `.continuous` |
| Same radius on parent and child | breaks concentricity | `nestedRadius` |
| Any texture/noise/grain image | explicitly forbidden | gradient + rim + shadow |
| Glow (`.shadow(color: .white)`) | Law 2 | gradient stroke |
| Opacity-only press state | Law 5 | depth + scale |
| Full-width opaque tab bar | kills the floating read | capsule with margins |
| Text with a drop shadow | reads as 2008 | `Deboss` on numerals only, never body |
| More than one accent on screen | destroys hierarchy | one accent, one primary action |
| `.bold` SF Symbols | too heavy for soft material | `.medium` / `.semibold` |
| Hardcoded `Color.white` for rim | breaks dark themes | `skeu.edgeLight` |

---

## 15. Rules block — copy into `CLAUDE.md`

```markdown
## Design system rules (SkeuKit — soft skeuomorphism)

Read `SKEUOMORPHIC_DESIGN_SYSTEM.md` before writing any view code.

**Hard rules — never violate:**

1. NO textures. No image fills, noise, grain, leather, fabric or paper assets
   used as surfaces. Depth comes only from gradients, rim strokes and shadows.
2. NO hardcoded colors outside `Sources/SkeuKit/Theme/`. Read colors via
   `@Environment(\.skeu)`. Never write `Color.white`, `.black`, `.gray` or a
   hex literal in a component.
3. Every visible object uses `.skeuSurface(...)`. Never a bare
   `.background(Color…)` + `.shadow(...)`.
4. Every radius comes from `SkeuRadius` and uses `style: .continuous`.
   Nested children use `nestedRadius(parent, inset: padding)`.
5. Shadows use `skeu.shadow` (a tinted brown), never black or gray.
6. One light source: top, slightly left. Highlights on top edges, shadows below.
   Never invert per component.
7. Pick exactly one depth from the ladder (`carved · recessed · flush · raised ·
   floating · overlay`). No custom in-between shadow values.
8. Interactive elements use `SkeuPressStyle` (scale 0.97 + one step down the
   depth ladder + `SkeuMotion.press`). Never opacity-only.
9. Tap targets ≥ 44×44. Icon-only controls need `.accessibilityLabel`.
10. The default theme is `.cream` (cream canvas, light-brown material, caramel
    accent). It must remain swappable: any screen must re-skin correctly by
    changing only `.skeuTheme(...)`.

**When adding a component:**
- Start from the closest recipe in §9 of the design system doc.
- Define all six states from §5.2.
- Add four previews: `.cream`, `.creamDark`, `.moss`, `.accessibility3`.
- Run the §13 checklist before declaring it done.

**When unsure about a visual decision:** re-read §1 "Physics Contract".
It resolves the question. Do not invent a new value — ask, or reuse the
nearest token.
```

---

## 16. Appendix — quick reference card

```
LIGHT        top, 10 o'clock, vector (-0.25, -1.0)
RADIUS       8 · 12 · 16 · 22 · 28 · 40 · pill        (always .continuous)
SPACE        2 · 4 · 8 · 12 · 16 · 20 · 28 · 40
DEPTH        carved · recessed · flush · raised · floating · overlay
DEFAULT      raised (e3) for objects, recessed (e1) for inputs
PRESS        scale 0.97 + depth.pressed + spring(0.26, 0.68)
SHADOW       skeu.shadow, tinted, ambient + contact, never black
RIM          light on top (≤0.60α), shade on bottom (≤0.28α)
TEXT         ink / inkMuted / inkFaint — never on a shadow
ACCENT       one per screen, on the single primary action
THEME        SkeuPalette.cream (default) · .clay · .moss · .slate · .ember
FORBIDDEN    textures · glow · flat fills · circular corners · black shadows
```
