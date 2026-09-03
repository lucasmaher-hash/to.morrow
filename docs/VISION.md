# Vision — shove.95

> Captured by the Product Planner skill. This file is the source of truth for
> generating product-vision.md, prd.md, and product-roadmap.md. Edit it directly
> and re-run the Product Planner to regenerate downstream documents.

> ⚠️ **Superseded, 2026-09-03.** Written before the 2026-08-22 pivot away
> from the Windows 95 pixel interface to **SkeuKit** (soft skeuomorphism,
> `shove95/shove95/SkeuKit/`), and before Week/General were replaced by a
> single "Soon" bucket (2026-08-17). "Four time buckets" and every Windows
> 95 specific below (2× pixel scale, taskbar-as-navigation, W95FA as *the*
> interface type) describe the old build. The core problem/audience/JTBD
> reasoning still holds; re-running the Product Planner against the current
> app would be the right way to regenerate this properly rather than
> hand-patching it here.

**Created:** 2026-08-03
**Updated:** 2026-08-03

## Founder

- **Name:** Lucas Maher
- **Expertise:** Industrial and interface design — Figma, Blender, TouchDesigner. Strong visual and interaction design; building software with AI coding agents rather than writing code by hand.
- **Background:** A designer who has repeatedly built visual and 3D work but never shipped a native app. shove.95 is the first — chosen deliberately as a learning project: small enough in concept to finish, opinionated enough in design to be worth finishing, and grounded in a personal daily annoyance rather than an imagined market.

## Purpose

- **Who you help:** Myself first — a designer who keeps three parallel to-do lists (today, tomorrow, general) and constantly needs to move items between them. Secondarily, anyone who plans by day rather than by project and abandons task apps because re-scheduling is tedious.
- **Problem you solve:** Task apps make *creating* a task cheap and *rescheduling* it expensive. Moving an item from today to tomorrow means opening it, finding a date picker, choosing a date, and saving — so people stop doing it. Every task collapses into one undifferentiated "today" list that is mostly lies by 11am.
- **Desired transformation:** Before: one bloated Today list you rewrite every morning, and a dead "someday" list you never open. After: tasks flow between four time buckets with a single flick, so the list you look at is always an honest picture of the day.
- **Why you:** This is my own broken workflow, observed daily for years, not a hypothesis. And the app's differentiator is craft — a complete, uncompromising Windows 95 interface built at 2× pixel scale — which is exactly the skill I have and most task-app builders don't.

## Product

- **Name:** shove.95
- **One-liner:** shove.95 is a to-do app with four time buckets where moving a task between days takes one swipe, wrapped in a pixel-faithful Windows 95 interface.
- **How it works:** Four tabs — Today, Tomorrow, Week, General — presented as a Windows 95 taskbar. Tasks carry a real date (or none), and the tabs are filters over that date, so the app is always correct without any rollover logic: an unfinished task from Monday simply keeps appearing in Today, marked with a date chip. Swiping a row left defers it one step along the line `Today → Tomorrow → Week → General`; swiping right pulls it forward. Long-pressing opens a context menu for Delete, Important, and direct jumps to non-adjacent buckets; long-pressing and dragging reorders the list freely. Tasks are added from a permanent row at the bottom of the list and edited by tapping their text. Ticking a task strikes it through and drops it to the bottom; at the end of the day it moves to an Archive in Settings.
- **Key capabilities:**
  - Four date-derived time buckets (Today / Tomorrow / Week / General) that never need manual rollover
  - One-swipe movement between adjacent buckets, with a context menu for longer jumps
  - Free manual reordering by long-press-drag, with automatic placement tiers on arrival only
  - One photo per task, viewed in a Windows 95 window
  - iCloud sync across devices with no account, no login, and no server
- **Platform:** mobile
- **Market differentiation:** The to-do category is saturated with apps that are excellent at capture and bad at rescheduling. shove.95 inverts that: rescheduling is the primary gesture and everything else is deliberately ordinary. Its second differentiator is aesthetic — a complete, systematically derived Windows 95 interface at 2× pixel scale (taskbar navigation, bevelled controls, status bar with persistent undo, W95FA type), not a retro-tinted modern app.
- **Magic moment:** You flick a task you didn't get to from Today to Tomorrow with your thumb, without opening it, without a date picker, and without thinking — and the status bar quietly confirms where it went, with an undo you didn't need.

## Audience

- **Primary user:** Lucas — a design student and practitioner who plans in day-sized chunks, keeps parallel lists for today/tomorrow/eventually, and has abandoned several task apps because moving a task between days is more work than rewriting it.
- **Secondary users:**
  - Day-planners who use Apple Reminders or paper and re-copy their unfinished tasks each morning
  - Retro-computing and pixel-art enthusiasts who will download it for the interface first and keep it if it works
- **Current alternatives:** Apple Reminders, Things, Todoist, TickTick, Apple Notes, and paper. Most commonly: one long Notes list that gets rewritten.
- **Frustrations:** Rescheduling requires opening a detail view and operating a date picker — several taps for a decision that takes half a second to make. "Someday" lists become graveyards because there's no cheap way to pull something out of them. And nearly every app in the category looks identical.

## Business

- **Revenue model:** free
- **90-day goal:** Ship v1 to the App Store and use it daily myself as my only to-do list. Success is a finished, approved, installed app — not downloads.
- **6-month vision:** v1.1 with notifications and stepped refinements, plus a native macOS build sharing the same CloudKit data, with drag-and-drop and keyboard shortcuts in place of swipe. A shipped portfolio piece that demonstrates both interaction design and native craft.
- **Constraints:** Building part-time alongside study. First native app — no prior Swift or Xcode experience. Budget limited to the $99/year Apple Developer Program. Building with an AI coding agent rather than writing Swift by hand, so the specification has to carry more weight than usual.
- **Go-to-market:** None planned. Personal use first; the App Store listing exists to prove the project was finished. Optional later: post the interface on design and retro-computing communities, where the Windows 95 execution is the hook.

## Brand Voice

- **Personality:** A well-built 1995 utility. Blunt, fast, unsentimental, and quietly funny about how much you defer. It does not congratulate you, gamify you, or ask how you're feeling. It has no opinions about productivity.
- **Tone of voice:** Terse system language, lowercase-averse, no exclamation marks, no emoji. Copy reads like status output rather than encouragement. Examples — status bar: `Repair bike → Tomorrow`. Empty list: `(empty)`. Archive header: `Completed — 12 items`. Settings: `iCloud: synced 2 min ago`. Never: "Great job!", "You're all caught up 🎉", "Let's crush today."

> Visual identity (mood, anti-patterns, design tokens) is deliberately not
> captured here — it lives in docs/design.md, generated by the Design System
> skill from image references.

## Tech Stack

- **App type:** mobile
- **Frontend:** SwiftUI (iOS 26 SDK, Swift 6.3) — native, first-party, and the only sensible choice for an App Store iOS app with heavy custom gesture work; shared view code can be reused by a future macOS target
- **Backend:** None — the app is entirely on-device; CloudKit provides sync without any server to run, deploy, or pay for
- **Database:** SwiftData with CloudKit sync (`.private` database) — Apple's modern persistence layer, integrates directly with SwiftUI, and syncs across the user's devices with a single entitlement
- **Auth:** None — CloudKit uses the device's existing Apple Account silently; there is no login screen, no username, and no account to create
- **Payments:** None — the app is free, has no paid tier, and collects nothing
- **Analytics:** None — a private personal task app; no third-party SDK will see the user's tasks, and the privacy policy commits to this
- **Email:** None — the app sends no email; there are no accounts, resets, or notifications by email
- **Error tracking:** None for v1 — Xcode Organizer crash reports from App Store Connect cover a single-developer personal app; revisit if the user base grows

## Tooling

- **Coding agent:** Claude Code
