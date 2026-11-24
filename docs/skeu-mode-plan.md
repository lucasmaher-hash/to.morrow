# Skeu-Modus — Umsetzungsplan

Ein Schalter in den Einstellungen wechselt den kompletten Look der App zwischen
**Win95** (bestehend) und **Skeu** (soft skeuomorphism nach
`~/TEMP/SKEUOMORPHIC_DESIGN_SYSTEM.md`). Referenz: Figma "Skeuomorphic UI Pack".

## Beschlossen (2026-08-13)

- **Struktur:** gleiches Skelett, neu bezogen. Kopfzeile (Workspace ▼ · Tag ·
  Einstellungen), Liste, Tab-Leiste unten als schwebende Segment-Pille (§9.5).
  Alle Gesten, Menüs, Funktionen bleiben 1:1.
- **Schrift:** SF Pro / New York als Skeu-Standard (§6); der bestehende
  Typeface-Schalter bietet W95FA weiterhin an.
- **Dark Mode:** eigener Schalter Hell / Dunkel / System. Er ist **global**,
  nicht Skeu-only — der Win95-Look bekommt in Schritt 8 dunkle Paletten, dann
  wirkt derselbe Schalter auf beide Designs.
- **Einstellungen:** drei Schalter untereinander — Schrift · Design ·
  Hell/Dunkel.
- **Persistenz:** `designMode` zunächst lokal in UserDefaults (wie Textgröße).
  Sync über `AppPreferences` ist ein möglicher Folgeschritt — CloudKit-
  Schemaänderung, bewusst nicht in v1.

## Architektur

- Neues Verzeichnis `shove95/shove95/SkeuKit/` (Theme, Tokens, Depth,
  Components) — 1:1 nach §12 des Design-Systems. Win95-Dateien bleiben
  unangetastet.
- `AppSettings.design: DesignMode` (.win95 / .skeu) +
  `AppSettings.skeuAppearance` (.light / .dark / .system) +
  `AppSettings.skeuPalette` (cream / clay / moss / slate / ember).
- `RootView` verzweigt: `.skeu` → `SkeuRootView` (nutzt denselben TaskStore,
  dieselben Koordinatoren), sonst der bestehende Baum.
- Farben nur über `@Environment(\.skeu)`; Tiefe nur über `.skeuSurface(...)`;
  Press-States über `SkeuPressStyle` (Regeln aus CLAUDE.md gelten strikt).

## Schritte (je Schritt ein Go)

1. **Fundament + Toggle** — SkeuKit-Dateien (Palette, Ableitung, Environment,
   Radius/Space/Motion/Font, Depth/Surface/InnerShadow/Seam, PressStyle),
   Settings-Eintrag "Design" mit Win95/Skeu-Schalter, Persistenz, Verzweigung
   in RootView. Skeu-Seite zeigt zunächst eine minimale, lauffähige Fassung.
2. **Hauptscreen: Chrome** — Canvas, Kopfzeile, schwebende Tab-Pille,
   Status-/Undo-Panel als floating panel (e4).
3. **Hauptscreen: Task-Rows** — erhabene Slats (§9.6, 56pt, 10–12pt Lücke),
   Checkbox, Datums-Chips, Add-Row als recessed Feld (§9.7), Fotos, Row-Menü,
   Swipe-Feedback.
4. **Settings in Skeu** — Palette-Picker (Swatches), Hell/Dunkel/System,
   Typeface-Wahl, Tab-Namen, Workspaces, Data — alles als Skeu-Rezepte
   (Cards, Felder, Toggle §9.8).
5. **Overlays** — Workspace-Dropdown und Row-Menü als floating panels (e4),
   Springs aus §8.2.
6. **Nebenscreens** — Archive, About, LaunchCover.
7. **Politur** — creamDark über alle Screens, Reduce Motion, Haptik (§8.4),
   A11y-Kontraste, Pre-Merge-Checkliste §13.
8. **Win95 Dark** — dunkle Variante jeder der fünf Win95-Paletten, damit der
   globale Hell/Dunkel-Schalter auch im Windows-Look greift. Bevel-Struktur
   bleibt unverändert; nur die sechs Farben kippen.

## Nicht verhandelbar (aus dem Design-System)

Keine Texturen · keine Hex-Werte außerhalb Theme · eine Lichtquelle (-0.25, -1)
· sechsstufige Tiefenleiter, keine Zwischenwerte · getönte Schatten, nie
schwarz · `.continuous`-Radien, konzentrische Verschachtelung · Press = Skala
0.97 + eine Stufe runter, nie nur Opacity.
