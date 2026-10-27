# Product Vision — shove.95

> ⚠️ **Superseded, 2026-09-03.** The Windows 95 pixel interface described
> throughout this document (bevels, taskbar navigation, 2× pixel-unit
> derivation, W95FA as the interface font, "Windows 95 rebuilt at 2× pixel
> scale") was fully removed from the app on 2026-08-22 and replaced by
> **SkeuKit**, a soft-skeuomorphic design system (`shove95/shove95/SkeuKit/`,
> `docs/SKEUOMORPHIC_DESIGN_SYSTEM.md`). The four buckets are now three —
> Today, Tomorrow, and Soon (renamed from General; Week was cut 2026-08-17)
> — plus a separate Live panel. W95FA survives only as an optional "Retro"
> chrome typeface, not the app's identity.
>
> The problem statement, personas, JTBD, and swipe-gesture value proposition
> below are still substantially accurate. The **visual-design claims, brand
> personality, messaging framework, and elevator pitches are not** — they
> were written for the Windows 95 aesthetic specifically and have not been
> rewritten for SkeuKit, since that's a brand-voice decision for the founder
> to make, not one to invent here. Treat any passage below that describes
> *how the app looks* as historical, not current.

## 1. Vision & Mission

### Vision Statement

A day plan you can trust, because changing it costs nothing.

### Mission Statement

shove.95 reduces rescheduling a task to a single thumb flick, so the list in front of you is always an honest picture of what you intend to do — not an aspirational one you stopped maintaining at 11am.

### Founder's Why

Lucas is a designer, not a Swift developer. Everything he has shipped so far has been visual — Figma work, Blender scenes, TouchDesigner patches — and none of it has ever been installed on a stranger's phone. shove.95 exists first as a deliberate act of finishing: a project small enough in concept to complete alone, opinionated enough in execution to be worth completing, and grounded in an annoyance observed daily for years rather than a market hypothesis invented for the occasion.

The annoyance is specific and honest. He keeps three parallel lists — today, tomorrow, and a general someday pile — and the categorisation always collapses, because moving an item between them costs more than rewriting it. So everything ends up in Today, Today becomes a lie by mid-morning, and the general list becomes a graveyard. He is not guessing at this user; he is this user, and has the failed workflow to prove it.

The second reason is strategic and worth stating plainly, because it is the part most first-time builders get wrong. The to-do category is unwinnable on features — it is saturated with well-funded, well-built apps, and Apple ships a competent one for free on every device. It is not saturated on *craft*. A complete, systematically derived Windows 95 interface, built at 2× pixel scale with real bevels, a taskbar for navigation and a status bar carrying undo, is a thing almost nobody attempts and almost nobody could execute. That is Lucas's actual advantage, and shove.95 is built to spend it.

### Core Values

**Rescheduling is the primary gesture, not a secondary one.** Every other task app treats creating a task as the cheap operation and moving it as the expensive one. Here it is inverted: one swipe, no detail view, no date picker, no confirmation. When a feature would add a tap to the act of moving something, that feature loses.

**The interface commits fully or not at all.** A half-observed Windows 95 aesthetic reads as generic "retro"; a fully observed one reads as intentional. Every metric derives arithmetically from the original 1995 spec at a fixed 2× scale — bevels, checkbox sizes, control heights, the 4px grid. No value is eyeballed, and no modern convention is imported because it would be easier.

**The app never tidies up behind you.** Placement rules run once, at the moment a task arrives or changes state. After that, position is yours. Nothing re-sorts itself, nothing springs back, nothing moves while you are looking away.

**Motion describes position, never appearance.** Things that move, move continuously. Things that appear or disappear do so instantly. This single rule resolves the tension between "smooth" and "period-accurate," and it is why the image viewer pops open with no transition while a deferred task slides off the edge of the screen.

**Ship the thing, then use the thing.** Success is a finished, approved, installed app that replaces the founder's existing system — not downloads, ratings, or a launch post.

### Strategic Pillars

**The wedge is movement; everything else is deliberately ordinary.** Capture, editing, completion and archiving should be competent and unremarkable. Design effort concentrates on the swipe, the context menu, the reorder drag, and the confirmation in the status bar. Any hour spent making task *creation* novel is an hour stolen from the thing that makes this app exist.

**Craft is the moat, not features.** The app will never out-feature Things or Todoist and should not try. It wins on execution quality in a dimension those apps have conceded entirely. When trading scope against polish, polish wins.

**Correct by construction, not by maintenance.** Tasks store dates; tabs are filters over those dates. There is no rollover job, no midnight timer, no migration step that can silently fail. The app is right after three days of not being opened, on a plane, in a different timezone, because there is no state to drift.

**Learning value counts as product value.** This is a first native app. Where two approaches are close, prefer the one that teaches the standard pattern — the one used by apps that ship — over the clever shortcut.

### Success Looks Like

Twelve months out: shove.95 is on the App Store, approved and updated at least twice. Lucas has used it as his only to-do list for the better part of a year and has not once opened Notes to make a parallel list — the real test, and the one that cannot be faked. A macOS build shares the same iCloud data, drag-and-drop and ⌘←/⌘→ standing in for the swipe, running on a teal desktop with a genuinely floating window. A short write-up of the interface — how the 1995 spec was translated to a 2× pixel unit, why the taskbar makes a better tab bar than a tab bar — has circulated in design and retro-computing communities, and a few thousand strangers have installed it because of how it looks and kept it because of how it works. Most importantly, the question "have you ever shipped anything?" now has a one-word answer.

-----

## 2. User Research

### Primary Persona

**Lucas, 22–26, design student and freelance designer, Munich.** Tech-comfortable and tool-curious — fluent in Figma, Blender and TouchDesigner, builds software with AI agents rather than by hand, and reads a spec more happily than a tutorial. His work is project-shaped but his *planning* is day-shaped: he does not think "portfolio project, phase two," he thinks "what am I doing today, what slips to tomorrow, what is genuinely not this week."

His current system is three lists in a notes app. Each morning he reads yesterday's, mentally sorts what survived, and rewrites the list. Items he keeps deferring get rewritten every day until the shame of retyping them either forces the task or kills it. The "general" list is opened perhaps twice a month and is functionally a graveyard — including things he genuinely intends to do, like building his portfolio, which sit there for weeks until a free day arrives and he has to remember they exist.

Emotionally, the relationship is one of low-grade distrust. He knows the list is not accurate, so he does not fully rely on it, so he maintains it less carefully, so it becomes less accurate. He has downloaded and abandoned at least three task apps; in every case the abandonment point was the same — the friction of moving something to a different day, hit for the fourth or fifth time in a week.

What would make him switch: the ability to defer a task without opening it. Genuinely just that. Everything else he already has.

### Secondary Personas

**The morning re-copier.** Uses Apple Reminders, Notes, or paper, and rewrites unfinished items each morning as a ritual. Believes the rewriting is a feature — a daily review — and is half right; the reflection is valuable, the transcription is not. They will find shove.95's swipe replaces the transcription while keeping the review, but they need to experience it before they will believe the daily rewrite was overhead.

**The retro-computing enthusiast.** Downloads shove.95 because a screenshot of the taskbar appeared in their feed. They arrive for the interface and will judge it forensically — wrong bevel order, an antialiased glyph, a modern spring animation and they will say so publicly. If the execution is faithful, they become the app's only meaningful distribution channel. They may never use it as a task manager, and that is fine.

**The lapsed task-app user.** Has tried Things, Todoist, and TickTick, and bounced off all three for being heavier than their life warrants. They want four lists and a way to move things between them. They are the closest thing to a real addressable market here, and reaching them is explicitly not a goal for v1.

### Jobs To Be Done

**Functional — when I realise I won't get to something today, I want to move it to tomorrow without breaking my train of thought,** so that my list stays accurate and I don't have to rebuild it in the morning.

**Functional — when I finally have a free day, I want to pull a long-deferred task into today in one action,** so that my "someday" list is a real source of work rather than a place things go to die.

**Functional — when I open the app, I want to see immediately which tasks I've already failed to do,** so I can decide whether to commit to them or admit they aren't happening.

**Emotional — I want to feel that my list is honest,** so I can trust it enough to stop keeping a second one in my head.

**Emotional — I want deferring something to feel like a decision, not a defeat.** The interface should be matter-of-fact about it: a task moved is a plan updated, not a failure logged.

**Social — I want to have shipped something.** For the founder specifically, the app existing on the App Store does a job that no feature of the app does.

**Social — I want to show people something I made that is obviously made by a designer.** The interface is the portfolio; the task management is the excuse.

### Pain Points

**1. Rescheduling costs more than the decision it represents.** *Severity: high. Frequency: multiple times daily.* Deciding "not today" takes half a second; executing it takes four taps through a detail view and a date picker. Users respond by not doing it — which is the root cause of every other problem here. Consequence: the list stops matching reality within hours.

**2. The single-bucket collapse.** *Severity: high. Frequency: continuous.* Because moving is expensive, everything gets created in Today. Today becomes a mix of genuine commitments and vague intentions, so it stops being useful for deciding what to actually do next.

**3. Deferred items become invisible.** *Severity: medium-high. Frequency: weekly.* Anything pushed to a "someday" list requires a deliberate act of remembering to retrieve. Real intentions — build the portfolio — sit unread for weeks. Current workaround: none. They surface by accident.

**4. Daily manual re-copying.** *Severity: medium. Frequency: daily.* Five minutes each morning transcribing yesterday's survivors. Genuinely annoying, but honestly the *least* severe item on this list — it is a symptom of 1 and 2, and fixing those fixes this. Worth naming precisely so it doesn't get mistaken for the core problem.

**5. Category sameness.** *Severity: low for the user, high for the founder.* No user abandons a task app because it looks like other task apps. But it is the entire reason shove.95 has any chance of being noticed, so it earns its place here.

### Current Alternatives & Competitive Landscape

**Apple Reminders.** Free, preinstalled, syncs perfectly, and has genuinely good natural-language date entry. Falls short on exactly the target behaviour: rescheduling means opening the item's detail view and operating a date control. Its list structure is also project-shaped rather than day-shaped. Switching cost is near zero, which cuts both ways — nothing holds users in, and nothing stops them drifting back.

**Things 3.** The craft benchmark, with a genuinely excellent Today/Upcoming/Someday model that is conceptually close to shove.95's four buckets. It is a paid app (per platform), heavier than a four-list app needs to be, and its rescheduling still routes through a date picker. Anyone who has paid for Things is not switching, and shove.95 should not try to make them.

**Todoist / TickTick.** Cross-platform, feature-dense, projects and labels and filters and collaboration. Overwhelming for the target use case; the daily-planning user is paying a complexity tax for capability they never touch. Their strength is the thing shove.95 explicitly refuses to compete on.

**Apple Notes or paper — a single rewritten list.** By far the most common real alternative and the most honest competitor. Zero friction to create, complete freedom of structure, no sync anxiety. Its weakness is that it does not move anything; it only accumulates, and is maintained by rewriting. Switching requires believing that a structured app can stay as fast as a blank page — which is precisely the bet shove.95 makes.

**Do nothing.** Keep the list in your head. Works fine for four items, fails silently at ten. This is what the target user falls back to when a task app becomes too tedious, and it is the state shove.95 must beat on effort, not on capability.

### Key Assumptions to Validate

**We assume the swipe is fast enough to change behaviour, because the cost of deferring drops from four taps to one.** *To validate:* after two weeks of daily use, count deferrals per day. If the founder still rewrites his list in Notes, or defers fewer than a few items a day, the friction was never the real blocker and the premise is wrong.

**We assume the four buckets are the right four.** Today, Tomorrow, Week, General is the founder's existing mental model, not a researched one. *To validate:* track how much traffic the Week tab actually gets after a month. If Week is empty or ignored, the app is really a three-bucket app with a decorative fourth, and the line-based swipe model gets simpler.

**We assume overdue tasks resurfacing in Today is motivating rather than demoralising.** *To validate:* watch what happens to the top of the Today list after a bad week. If the overdue block grows past five or six items and the founder starts avoiding the app, the design needs an explicit "give up on this" affordance that isn't Delete.

**We assume free manual reordering coexists peacefully with automatic placement tiers.** This is the least-tested interaction decision in the spec. *To validate:* build it early — it's in Phase 3, deliberately — and live with it for a week before building anything on top of it.

**We assume photo attachment will actually get used.** It is the single most expensive feature in v1 and was retained against a recommendation to cut it. *To validate:* count attached photos after a month of use. Fewer than a handful means the cost was misallocated, and it should be quietly removed in v2 rather than extended.

**We assume the Windows 95 aesthetic reads as deliberate craft rather than a gimmick.** *To validate:* post a screen recording of the taskbar and swipe to a design community before the app is finished. The reaction to the *motion*, not the static screenshot, is the real signal.

**We assume gesture disambiguation between long-press-menu and long-press-drag can be made reliable.** This is the highest technical risk in the build and it sits on the app's second-most-important interaction. *To validate:* prototype it in isolation, first, before any styling exists.

**We assume the app can be built at this scope by a first-time Swift developer.** The founder chose full scope over a reduced v1 with eyes open. *To validate:* Phase 2 should complete within its estimate. If it runs 50% over, cut photos before cutting polish.

### User Journey Map

**Awareness.** For the founder, there is no awareness stage — he is building it. For everyone else, it is a screenshot or a five-second screen recording of a task sliding off a Windows 95 list. The emotion is recognition and mild delight; the friction is the immediate suspicion that it is a toy.

**Consideration.** They open the App Store page. The screenshots have to do two contradictory jobs: prove the aesthetic is complete (so it isn't a filter over a generic app) and prove it is a real task manager (so it isn't a novelty). A short video of the swipe does both at once and should be the first asset.

**First use.** The app opens to Today, empty: a sunken white well containing `(empty)`, a taskbar with four buttons, a title bar reading `Today - shove.95`. There is no onboarding, no account, no permission prompt — the emotional note is *this thing is ready immediately*. The friction is that the swipe is undiscoverable; nothing on screen suggests it. This is the single biggest first-run risk, and the mitigation is the status bar: the first time a task is swiped, the bar says exactly what happened.

**Magic moment.** Day two. Four tasks are in Today, one of them from yesterday with a `Mon` chip. The user flicks the one they aren't going to do — thumb only, without reading it carefully, without opening anything — and it slides off the edge. The status bar says `Repair bike → Tomorrow`. The gap closes. Total elapsed time under a second, and the plan is now honest. The feeling to engineer for is not delight but *relief*: this was supposed to be easy and it finally is.

**Habit formation.** Weeks one to three. The habit forms not at creation but at review — opening the app, seeing three overdue items at the top, and clearing them in three flicks instead of a five-minute rewrite. The risk in this window is trust: a single sync failure, a lost task, or an accidental swipe with no recovery breaks the habit permanently. This is precisely why the status bar carries a persistent undo rather than a three-second toast.

**Advocacy.** Around week four, if the app has held up, the founder posts the interface rather than the product — the translation of the 1995 spec, the taskbar-as-tab-bar decision, the pixel-snapped motion. The audience that responds is a design audience, and what they share is the craft. Task-management word-of-mouth, if it ever comes, arrives second and much later.

-----

## 3. Product Strategy

### Product Principles

**A move must never require opening a task.** The moment a gesture routes through a detail view, the product's reason for existing is gone. This is the principle that most often says no.

**Every visual value derives from the 1995 spec at 2×.** Bevel widths, control heights, grid spacing, checkbox dimensions are arithmetic, not taste. When something looks wrong, the fix is to check the derivation, not to nudge the number.

**Placement happens once; position belongs to the user.** Tiers decide where a task *lands*. Nothing re-sorts afterward. If the list looks untidy after a week of dragging, that is the user's list, correctly preserved.

**Motion for position, never for appearance.** Movement is continuous and snapped to the pixel grid. Appearance and disappearance are instant. No fades, no scale transitions, no dissolves — anywhere.

**No modal interrupts the list.** No dialogs, no confirmation sheets, no bottom sheets for creating or editing. Adding happens in a row of the list; editing happens in place; the only overlay in the app is the photo window.

**Colour carries exactly one meaning.** Red means important. Nothing else in the app is red. Every other distinction — overdue, completed, dragging — uses a different channel entirely (a chip, grey, navy inversion).

### Market Differentiation

The to-do category competes almost exclusively on capability: more views, more integrations, more natural-language parsing, better collaboration. That competition is settled, and it is settled by companies with teams. Entering it is how a first app dies.

shove.95 competes on a dimension those products have collectively abandoned — the cost of *changing your mind*. Every major task app optimises the moment of capture, because capture is what demos well and what onboarding measures. None optimises the moment three hours later when the plan is already wrong. That moment happens far more often, and the friction there is what drives users back to a rewritten Notes list. Making it a single thumb flick is a small idea, but it is a small idea aimed precisely at the point where the category actually fails its users.

This is defensible in a specific and limited sense. It is not defensible technically — any competitor could add a swipe gesture. It is defensible *structurally*: adding one-flick day-shifting to Todoist would mean picking four canonical buckets and privileging them above the project hierarchy the app is built on, which contradicts their entire model. The feature is cheap; the commitment it requires is not. Incumbents can copy the gesture but not the constraint.

The second differentiator is craft, and it should be understood as a distribution strategy rather than a product feature. A complete Windows 95 interface — not a theme, but the whole system derived from the original spec — is the reason anyone outside the founder will ever see this app. It buys attention that a free personal task app could never otherwise earn, and it is defensible for the ordinary reason that most teams will not spend weeks on a bevel.

### Magic Moment Design

**The moment:** a task is flicked from Today to Tomorrow with the thumb, without being opened, and the status bar confirms where it went.

For this to happen reliably, four things must be true. The user must have at least two tasks in Today, at least one of which they aren't going to do — meaning the moment cannot occur on day one, only on day two or later. The swipe must be discoverable without a tutorial. It must be forgiving, so that a mis-flick doesn't cost anything. And the result must be confirmed, so the user learns what the gesture did without having to check another tab.

The spec addresses each. Overdue roll-forward guarantees that by the second day Today contains something deferrable without the user having to plan for it. The status bar makes every move self-documenting, converting the first accidental swipe into the tutorial. Rubber-banding at the ends of the line means an over-swipe is inert rather than destructive. Persistent undo, rather than a timed toast, removes the cost of being wrong.

The shortest path from install to magic moment is therefore roughly 24 hours, and it is gated on the user adding tasks on day one. That is the correct thing to optimise: the first-run experience should make *adding several tasks quickly* effortless, because that is what loads the gun. The permanent inline add row — which keeps the keyboard up and commits on return — is what makes entering five tasks feel like writing a list rather than operating an app, and it is more strategically important than it looks.

The magic moment is fully achievable in the MVP. No scope adjustment is needed.

### MVP Definition

**Four date-derived tabs.** Today (dated today or overdue), Tomorrow, Week (rest of the calendar week, rolling to next week from Saturday), General (dateless). Tabs are filters over a stored date, never storage themselves. *Essential because* it is what makes the app correct without maintenance. *Done when* leaving the app closed for three days and reopening it shows the right tasks in the right tabs with no migration step.

**Swipe to move one step.** Left defers, right pulls forward, along `Today → Tomorrow → Week → General`. Rubber-band with haptic at both ends. *Essential because* it is the magic moment. *Done when* a task can be deferred one-handed in under a second, and over-swiping at Today does nothing.

**Long-press context menu.** Delete, Important, and contextual Move-to entries for non-adjacent buckets only (`<` nearer, `<<` further). *Essential because* it covers the long jumps the swipe is worst at — specifically General → Today, the founder's own stated use case. *Done when* the menu's contents differ correctly per tab as specified.

**Long-press-drag to reorder.** Free placement, disambiguated from the context menu. *Essential because* the placement tiers are only a starting point and the user owns the order. *Done when* dragging and menu-opening are reliably distinguishable without conscious effort.

**Add and edit in place.** Permanent add row at the bottom of the list that stays focused for consecutive entry; tap text to edit inline. *Essential because* it loads the app with enough tasks for the magic moment to occur. *Done when* five tasks can be entered without the keyboard dismissing.

**Completion and archive.** Tick strikes through, greys, and drops to the bottom; untickable at any time; archived at end of day (24h after completion for General). *Essential because* without it the list only grows. *Done when* a completed task never reappears as overdue.

**Photos.** One optional photo per task, thumbnail beneath the text, tap to open a Windows 95 window viewer, tap outside to close instantly. *Retained against advice* — the founder chose full scope deliberately. *Done when* a photo survives a sync round-trip to a second device.

**The full Windows 95 interface.** 2× pixel unit, taskbar navigation with pressed active state, title bar with settings control, status bar with persistent undo, sunken list well, W95FA type, stepped Dynamic Type at 2×/3×/4×. *Essential because* it is the distribution strategy. *Done when* every metric traces to the spec table in `docs/design.md`.

**SwiftData + CloudKit sync.** Silent, account-free, across the user's devices. *Essential because* it is the foundation the macOS build depends on and cannot be retrofitted. *Done when* a task created on one device appears on another without any user action.

**Settings.** Archive, sync status, About with privacy policy link. *Essential because* the archive is specified and the privacy policy is an App Store requirement. *Done when* App Store submission has a live policy URL.

### Explicitly Out of Scope

**Dark mode.** ~~Excluded because Windows 95 has no dark equivalent and inventing one is fan-fiction — a dark bevel system is a different design, not a variant. *Reconsider:* probably never.~~

**Reversed and shipped, 2026-08-14.** The founder called it: the app did look wrong at night, and that mattered more than the purity argument. The escape hatch written into the original entry is exactly the one taken — it is *not* a dimmed version of the light design. Each of the five schemes got a hand-built dark twin that keeps the bevel STRUCTURE intact (the light→dark ramp keeps its order, so a raised control still reads raised) while dropping the six colours. Red stays red. Title bars keep their hue and lose brightness. See `design.md` §1.

The honest caveat: this is an invention, not a restoration. Windows 95 had no dark mode, and this is fan-fiction by the original standard — it is just fan-fiction that obeys the source's own physics.

**Notifications and daily reminders.** Tempting because every task app has them. Excluded because they bring permission prompts, scheduling, background delivery and a whole class of bugs, for an app the user opens manually every morning anyway. *Reconsider:* v1.1 — it is the single most valuable deferred feature.

**The macOS app.** Tempting because the founder wants it and CloudKit already makes the data available. Excluded from v1 because the core gesture does not exist on a desktop — the Mac needs its own interaction model (drag-and-drop plus ⌘←/⌘→), which is a design project of its own, not a port. *Reconsider:* immediately after v1 ships. The shared Swift package exists from day one specifically to make this cheap.

**Multiple photos per task.** Tempting once single-photo works. Excluded because a gallery means a carousel, reordering, and per-image deletion — a photo manager inside a to-do app. *Reconsider:* only if single-photo attachment proves heavily used.

**Recurring tasks, subtasks, tags, projects, search, collaboration.** Tempting individually, fatal collectively — each one pushes the app toward the feature competition it cannot win. Excluded permanently unless daily use proves a specific one indispensable. *Reconsider:* case by case, with a high bar, after six months of real use.

**Statistics, streaks, and productivity scoring.** Excluded on brand grounds. The app has no opinions about productivity and does not congratulate the user. The raw archive is available; interpretation is not the app's business.

**Data export.** Excluded for v1 as unnecessary for a personal app. Worth adding before any meaningful external user base exists, on principle.

### Feature Priority (MoSCoW)

**Must Have** — Four date-derived tabs with overdue roll-forward; calendar-week logic with weekend rollover; swipe one step with rubber-band ends; long-press context menu (Delete, Important, contextual Move-to); long-press-drag reordering; placement tiers on arrival; inline add row; inline edit; completion with strikethrough and drop-to-bottom; end-of-day archiving; the complete Windows 95 visual system at 2×; taskbar navigation; title bar; status bar with persistent undo; SwiftData + CloudKit sync; Settings with Archive, sync status, and About; privacy policy.

**Should Have** — Photo attachment with Windows 95 window viewer; stepped Dynamic Type at 2×/3×/4×; the taskbar clock/date well; haptics on swipe commit and rubber-band. *(Both of the first two were offered as cuts and deliberately kept; if the schedule slips badly, they are the first things to move to v1.1.)*

**Could Have** — App icon refinements; empty-state character beyond `(empty)`; a Windows 95 boot or splash flourish; archive grouped by week rather than day.

**Won't Have (this time)** — ~~Dark mode~~ (shipped 2026-08-14, see above); notifications; the macOS app; multiple photos; recurring tasks; subtasks; tags; projects; search; sharing; collaboration; statistics; streaks; export; widgets; Apple Watch; Siri and Shortcuts integration.

### Core User Flows

**Flow 1 — Defer a task (the magic moment).**
*Trigger:* the user is looking at Today and recognises something they won't get to.
*Steps:* thumb-swipe the row left → the row slides off the screen edge → the rows below close the gap → the status bar updates to `Repair bike → Tomorrow` with an Undo button.
*Outcome:* the task's date is now tomorrow; it appears in the Tomorrow tab, placed at the bottom of that list.
*Success criteria:* under one second, one hand, no visual confirmation needed beyond the status bar, and fully reversible from the status bar until the next action.

**Flow 2 — Retrieve a long-deferred task.**
*Trigger:* a free day; the user remembers a task parked in General.
*Steps:* tap `General` on the taskbar → find the task → long-press → the context menu shows `< Tomorrow` and `<< Today` → tap `<< Today` → the row leaves the list → status bar confirms.
*Outcome:* the task is dated today and, being Important or not, placed by tier at the top or bottom of Today.
*Success criteria:* two gestures, no date picker, no detail view. This flow is why the contextual Move-to menu exists at all.

**Flow 3 — Morning review.**
*Trigger:* first open of the day.
*Steps:* the app opens on Today → an overdue block sits at the top, each row carrying a trailing date chip (`Mon`, `2d`) → the user ticks what's done, flicks what's slipping, and leaves what stands.
*Outcome:* Today reflects a real plan within about fifteen seconds.
*Success criteria:* no transcription, no rewriting, and no list maintained anywhere else. Whether this flow works is the single clearest measure of whether the product succeeded.

### Success Metrics

**Primary metric — days of exclusive use.** The number of consecutive days the founder uses shove.95 as his only to-do list, with no parallel list in Notes or on paper. *Good:* 14 days. *Great:* 90 days. Everything else on this list is a leading indicator for this one.

**Secondary — deferrals per active day.** How many tasks get moved between buckets daily. *Good:* 3+. *Great:* 6+. If this number is near zero while the app is otherwise in use, the wedge failed and the app is just another list.

**Secondary — Week tab utilisation.** Tasks residing in Week at any given time. *Good:* consistently non-empty. *Great:* the destination for a meaningful share of deferrals. If it stays empty, the four-bucket model was really a three-bucket model.

**Secondary — shipped and approved.** Binary. App Store approval on or before the target date, with at least one post-launch update shipped. *Good:* approved. *Great:* approved on first submission.

**Leading indicator — time from open to first action.** Should be under three seconds on a morning review. If the user has to read carefully before acting, the overdue block or the tiering is not doing its job.

**Leading indicator — undo usage.** *Good:* occasional. *Great:* rare. Frequent undo means the swipe is too easy to trigger accidentally and the commit threshold needs raising. Zero undo across weeks of use may mean the status bar isn't being noticed.

### Risks

**Scope exceeds a first-time Swift developer's capacity.** *Likelihood: high. Impact: high.* Full scope was chosen over a reduced v1, and it contains three genuinely hard pieces — a custom swipe gesture, gesture disambiguation, and a hand-built visual system — none of which lean on stock components. *Mitigation:* the roadmap front-loads the hard interaction work into isolated prototypes before any styling exists. If Phase 2 overruns by more than half, cut photos and fix Dynamic Type at 2×; do not cut polish, which is the differentiator.

**Gesture disambiguation proves unreliable.** *Likelihood: medium. Impact: high.* Long-press-hold and long-press-drag share a starting point; getting the thresholds wrong makes both the menu and reordering feel broken, on the app's second-most-used interaction. *Mitigation:* prototype in isolation first. If it cannot be made reliable, move reordering to an explicit edit mode rather than shipping an ambiguous gesture.

**CloudKit is harder than expected.** *Likelihood: medium. Impact: high.* SwiftData + CloudKit imposes model constraints (optional or defaulted properties, no unique constraints) that are cheap to design for and expensive to retrofit, and photo assets add sync failure modes. *Mitigation:* apply the constraints from the very first model definition, and test two-device sync with a photo before building anything on top of it.

**The Apple Developer account blocks the build.** *Likelihood: low. Impact: high.* CloudKit does not function on a free account, and approval can take days. *Mitigation:* purchase before the data layer, not before submission. This is the only hard external dependency in the plan.

**The overdue block becomes demoralising.** *Likelihood: medium. Impact: medium.* A bad fortnight produces a wall of chipped tasks at the top of Today, and the honest response is to stop opening the app. *Mitigation:* watch for it in the first month. The fix is not to hide overdue items but to add a low-friction way to send something back to General — an admission of "not now" that isn't deletion.

**Photo attachment turns out to be dead weight.** *Likelihood: medium. Impact: medium.* It is the most expensive v1 feature and the least connected to the wedge. *Mitigation:* count usage after a month. If it's near zero, remove it in v2 rather than extending it — and note that the decision to keep it was made knowingly.

**The aesthetic reads as a gimmick.** *Likelihood: low-medium. Impact: medium.* A half-executed Windows 95 look would undermine both the product and its distribution. *Mitigation:* full derivation from the spec, no eyeballed values, and an early screen recording posted to a design community to test the reaction to motion rather than to a screenshot.

**Trade dress and asset infringement.** *Likelihood: low. Impact: high if realised.* The aesthetic is fine; Microsoft's icon artwork, logo, Start button, and the "Windows" name are not. *Mitigation:* all glyphs drawn from scratch, the name `shove.95` carries no Microsoft mark, and no original assets ship in the binary. W95FA is SIL OFL and explicitly safe to embed.

-----

## 4. Brand Strategy

### Positioning Statement

For people who plan their work by day and abandon task apps because rescheduling is tedious, shove.95 is a to-do app where moving a task between days takes one thumb flick. Unlike Reminders, Things, and Todoist — which make capture cheap and rescheduling expensive — shove.95 treats changing your mind as the primary gesture, and dresses it in a Windows 95 interface built pixel by pixel from the original spec.

### Brand Personality

shove.95 is a well-built utility from 1995 that somehow ended up on your phone. If it were a person: competent, terse, faintly amused, and entirely uninterested in your feelings about productivity. It tells you what happened and gets out of the way.

It talks the way system software talked before software learned to be encouraging — in statements of fact. `Repair bike → Tomorrow`. `(empty)`. `iCloud: synced 2 min ago`. It never uses an exclamation mark, never celebrates, never uses the word "just," and would rather show you a number than a mood.

It would wear grey. It would never wear a gradient, except the one on its own title bar, which it did not choose. It has a dry sense of humour about deferral — the name is a joke about what you actually do with your tasks — but it makes the joke once, in the name, and then never mentions it again. It does not have a mascot. It does not have an onboarding carousel. It has never asked anyone to rate it on the App Store.

What it would never do: gamify anything, award a streak, congratulate the user for completing a task, use an emoji, apologise, or describe itself as "beautifully designed."

### Voice & Tone Guide

The voice is constant: factual, terse, system-flavoured. Tone shifts only in register, never in warmth.

| Context | DO | DON'T |
|---|---|---|
| **First run / onboarding** | *(nothing — the app opens to an empty list and a taskbar)* | "Welcome to shove.95! Let's get you set up 👋" |
| **Empty state** | `(empty)` | "Nothing here yet — add your first task to get started!" |
| **Task moved (status bar)** | `Repair bike → Tomorrow` | "Nice, moved to tomorrow! ✅" |
| **Task completed** | *(nothing — it strikes through and drops)* | "Great job! One down." |
| **All tasks done** | `(empty)` | "You're all caught up 🎉" |
| **Sync status** | `iCloud: synced 2 min ago` / `iCloud: offline` | "Everything's backed up and safe!" |
| **Error — sync failed** | `iCloud: not signed in` | "Oops! Something went wrong. Please try again." |
| **Archive header** | `Completed — 12 items` | "Look at everything you've accomplished!" |
| **Delete confirmation** | *(none — Delete is immediate, Undo is in the status bar)* | "Are you sure you want to delete this task?" |
| **App Store description** | "Four lists. One swipe to move between them. Built like it's 1995." | "The revolutionary productivity app that will transform how you work." |

### Messaging Framework

**Tagline:** Shove it to tomorrow.

**App Store subtitle:** Four lists. One swipe.

**Homepage / listing headline:** Your plan changes. Changing it shouldn't cost anything.

**Value propositions:**

*One flick to reschedule.* Every other task app makes you open the item and operate a date picker. Here, a swipe moves a task one day further away — or one day closer. That's the whole app.

*A list that's always correct.* Tasks carry dates; the four tabs are just filters over them. Nothing rolls over, nothing migrates, nothing drifts. Close the app for a week and it's still right.

*Built like it's 1995.* Not a retro theme over a modern app — a complete Windows 95 interface derived from the original spec and rebuilt at double scale. Taskbar navigation, real bevels, a status bar that tells you what just happened.

**Feature descriptions:**

*Four buckets:* Today, Tomorrow, Week, General. Anything you don't finish shows up tomorrow with a date chip, so nothing disappears quietly.
*Swipe:* Left pushes a task further away. Right pulls it closer. That's it.
*Long-press:* Delete, mark important, or jump straight across to a bucket the swipe can't reach in one step.
*Photos:* One picture per task, if a picture is faster than a sentence.
*iCloud:* Syncs across your devices. No account, no login, nothing leaves your iCloud.

**Objection handlers:**

*"There are already a thousand to-do apps."* There are, and they're all better than this one at capture. None of them are good at the moment three hours later when your plan is already wrong.
*"Isn't the Windows 95 thing a gimmick?"* It would be, if it were a skin. It's the actual interface — the taskbar is the navigation, the status bar carries undo, every dimension comes from the 1995 spec.
*"Why no dark mode?"* — retired 2026-08-14; the app ships one. If asked now: Windows 95 didn't have one, so this is an invention rather than a restoration — but it is built to the original's own bevel physics rather than being a dimmed copy of the light theme.
*"Where's my data?"* In your private iCloud. There's no server, no account, no analytics, and no third party involved.

### Elevator Pitches

**5 seconds:** A to-do app with four day-buckets where one swipe moves a task between them — built to look exactly like Windows 95.

**30 seconds:** Every task app makes it easy to add a task and annoying to reschedule one — you have to open it and use a date picker. So people stop rescheduling, everything piles into Today, and the list becomes fiction. shove.95 has four buckets — Today, Tomorrow, Week, General — and moving between them is a single thumb flick. The whole thing is built as a pixel-accurate Windows 95 interface: taskbar navigation, real bevels, a status bar that shows what just happened and lets you undo it.

**2 minutes:** *Problem.* Most people plan by day, not by project. They keep a list for today, a list for tomorrow, and a vague someday pile — and it collapses every time, because moving something between them takes four taps through a detail view and a date picker. Deciding "not today" takes half a second; executing it takes ten. So nobody does it. Everything ends up in Today, Today stops being true by mid-morning, and the someday list becomes a graveyard that contains things you genuinely intend to do.

*Solution.* shove.95 makes rescheduling the primary gesture. Four tabs in a line — Today, Tomorrow, Week, General. Swipe left, the task moves one step further away. Swipe right, one step closer. Long-press for the longer jumps. Tasks store real dates and the tabs are just filters, so unfinished work rolls forward automatically with a small date chip showing how long you've been avoiding it. There's no rollover logic to break and nothing to maintain.

*Why now.* SwiftData and CloudKit mean a solo developer can ship a synced, account-free, server-free app — no backend, no login, no infrastructure bill. That was a team's worth of work five years ago.

*Why us.* This is a designer's app, built by someone whose own workflow is the problem being solved. The differentiator isn't features — it's execution: a complete Windows 95 interface derived from the original 1995 specification and rebuilt at double pixel scale, in a category where every app looks identical. It's a small idea, aimed precisely at where the category actually fails, and dressed in something nobody else is willing to build.

*Ask.* Try it for two days. The moment it makes sense is the second morning, when yesterday's leftovers are sitting at the top of the list and you clear them in three flicks.

### Competitive Differentiation Narrative

The to-do category has spent fifteen years competing on capability. Todoist and TickTick race on integrations, filters, and natural-language parsing. Things competes on refinement within a project-shaped model. Apple gives Reminders away with the operating system. Every one of them has optimised the same moment — capture — because capture is what demos well and what onboarding funnels measure. Not one of them has optimised the moment that actually happens more often: three hours later, when the plan is already wrong and you need to move something.

That moment costs four taps in every major app on the market. It costs one flick in shove.95, and that single difference is what stops the daily collapse into one dishonest Today list. The gesture itself is trivial to copy — but the constraint behind it isn't. Adding one-flick day-shifting to Todoist would mean elevating four canonical time buckets above the project hierarchy their entire model rests on. Incumbents can afford the feature and can't afford the commitment.

The second half of the argument is craft, and it is unapologetically a distribution strategy. shove.95 is a complete Windows 95 interface — not a retro filter over a modern app, but the taskbar as navigation, the status bar as the undo mechanism, every dimension derived arithmetically from the 1995 specification and doubled for a retina display. In a category where every product is a white list with a tinted accent colour, this is the only reason a stranger will ever look twice. It buys attention that a free personal task app has no other way to earn, and it is defensible for the most ordinary reason there is: almost nobody else will spend a fortnight getting a bevel right.

-----

## 5. Visual Design

Visual design tokens (colors, typography, spacing, components, motion) live in `docs/design.md`. That file was generated directly from the design decisions made during the planning interview and contains the full Windows 95 derivation — palette, bevel construction, the 2× pixel unit, control metrics, type, and motion rules. It is the authority for every visual value in the PRD and roadmap.
