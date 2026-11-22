# Tawfeeq: UX spec (features, screens, flows)

This spec is distilled from [ux-research.md](ux-research.md), which covers Brick, Opal, one sec, ScreenZen, Forest, Foqos, Alarmy and Apple's HIG for iOS 26. Each feature lists the app it borrows from, the screen it lives on, and its build status.

## Principles

1. **The tag is the product.** One tap, instant feedback, and the app stays nearly invisible. (Brick)
2. **Calm, never shaming.** Gentle and dignified wording, with no red for "failure". (Brick, Forest)
3. **Honest friction.** Passes are unlimited, but each one is conscious, logged and slower than the last. (Opal, ScreenZen, one sec)
4. **State is readable everywhere.** The app, Live Activity, widgets, Control Center and the block screen all say the same thing. (HIG)
5. **Reliability is the brand.** Redundant scheduling and self-healing shields. (Brick and Opal complaints)
6. **Show progress gently.** Elapsed time rather than an anxious countdown. Streaks include grace days. (Brick review, Forest)
7. **Respect the platform.** System controls, Liquid Glass only for chrome, Dynamic Type, Reduce Motion. (HIG)

## Feature list

| # | Feature | Borrowed from | Where | Status (✅ built · ⏳ in progress) |
|---|---|---|---|---|
| 1 | Tap desk tag to start/stop (tag-verified stop) | Brick | Focus | ✅ |
| 2 | Hold-to-start ring (3 s, rising haptics) when the tag isn't handy | Brick | Focus | ⏳ |
| 3 | Remote start (Shortcut, Control Center, widget); stopping always needs the tag | Brick, Foqos | Shortcuts, Controls | ⏳ |
| 4 | Big rounded elapsed timer with rolling digits | Opal, Apple Clock | Focus | ⏳ |
| 5 | Home changes per state: idle, focusing, pass, night lock, morning | Opal | Focus | ⏳ |
| 6 | Mini-player above the tab bar on every tab | Opal 4.21, iOS 26 | All tabs | ⏳ |
| 7 | Session summary sheet on end ("52 minutes of focus") | Forest, Brick | Focus | ⏳ |
| 8 | Pass with an escalating breathing wait (5 s → 15 s → 30 s) | Opal, ScreenZen | Pass sheet, block screen | ⏳ |
| 9 | Intention chips before a pass (Message, Navigation, Work, Other) | Opal, one sec | Pass sheet | ⏳ |
| 10 | "Pass #3 today · last one 12 min ago", plus an amber back-to-back warning | one sec, Foqos | Block screen, pass sheet | ⏳ |
| 11 | Two-tap pass on the block screen (tap, breathe, tap again) | research §4.4 | Block screen | ⏳ |
| 12 | Rotating block-screen messages that name the blocked app | Foqos | Block screen | ⏳ |
| 13 | "1 minute left" and "Pass over, welcome back" notifications | research §4.4 | Notifications | ⏳ |
| 14 | Live Activity with per-state symbol and tint; "Return now" during a pass | Foqos, HIG | Lock Screen, Dynamic Island | ⏳ |
| 15 | Lock Screen widgets: focus ring vs goal, status line, streak | HIG | Lock Screen | ⏳ |
| 16 | Home Screen widgets: status + start, today + streak | HIG | Home Screen | ⏳ |
| 17 | Control Center controls: Start focus, Scan desk tag | Foqos | Control Center, Action button | ⏳ |
| 18 | Night lock with its own night theme on Home | research §4.5 | Focus | ⏳ |
| 19 | Morning check-in screen: warm, big scan button, time since the alarm | Alarmy, Apple Clock | Morning sheet | ⏳ |
| 20 | Alarm the tag must silence: Scan button, re-arm, chaser alarms | Alarmy, Touchstone | Alarm | ✅ |
| 21 | Travel mode: pause night lock and alarm for N days | Alarmy lesson | Settings | ⏳ |
| 22 | Block list only gets stricter during a session (add yes, remove no) | Opal exploit fix | Rules | ⏳ |
| 23 | Weekly hero: "Focus this week 14h 20m" plus change vs last week | Brick | Insights | ⏳ |
| 24 | Streak calendar (4-week grid) with a grace day per week | Foqos, Forest | Insights | ⏳ |
| 25 | Passes by intention, plus back-to-back count | Opal | Insights | ⏳ |
| 26 | Morning check-in strip | research §4.9 | Insights | ⏳ |
| 27 | Screen Time report: today, daily bars, pickups, top apps (display only) | Apple Screen Time | Insights | ✅ |
| 28 | One gentle suggestion from your own data ("Most passes happen 3–4 pm") | research §4.9 | Insights | ⏳ |
| 29 | Weekly summary notification on Sunday evening | research §4.9 | Notifications | ⏳ |
| 30 | Tags: roles, last scanned, add, remove | Foqos | Settings | ⏳ |
| 31 | "Lost your tag?" break-glass: 3 taps, then slide to end; logged | Foqos, Apple Clock | Settings, Focus | ⏳ |
| 32 | Guided onboarding: privacy-first permission, apps, tag, optional mornings | ScreenZen, Foqos | Onboarding | ✅ |
| 33 | Haptics for scan, start, end, warning and break-glass, with an off switch | HIG | Everywhere | ⏳ |
| 34 | Accountability partner | — | Settings | Later (phase 5) |

## Information architecture

```
Tab bar (iOS 26 Liquid Glass, minimises on scroll)
├── Focus      home; changes by state (idle / focusing / pass / night / morning)
├── Rules      block list · always allowed · passes · night lock · morning alarm
├── Insights   week hero · streak calendar · focus chart · passes · mornings · Screen Time
└── Settings   tags · one-tap Shortcut · daily goal · haptics · travel mode · lost tag · about
Bottom accessory: mini-player (session timer / pass countdown / next event)
```

## Key flows

- **Start:** tap the tag (or Shortcut, Control, hold-to-start) → shields on → success haptic → Home fills with the focus colour → Live Activity starts.
- **End:** tap the tag (the tag *is* the confirmation) → shields off → summary sheet ("52 min · 1 pass") → streak tick.
- **Pass (in app):**
  1. Take a pass.
  2. Choose an intention.
  3. Breathe for 5, 15 or 30 s; the wait can't be skipped.
  4. 5 minutes unblocked, with a countdown on Home, Live Activity and mini-player.
  5. Notification at 1 minute left.
  6. Auto re-block, then "Welcome back".
- **Pass (block screen):** "Take a 5-min pass" → the block screen says "Breathe. Tap again in 15 s" → tap again after the wait → the app opens, 5 min.
- **Night lock:** apps lock at bedtime → night theme → locked until a desk-tag scan in the morning.
- **Morning:**
  1. The alarm rings; "Scan desk tag" opens the morning sheet.
  2. Scan the tag.
  3. Sunrise animation, "Checked in at 6:34 — 4 min after your alarm".
  4. Night lock lifts.
- **Lost tag:** Settings → Lost your tag? → crack the glass (3 taps) → slide to end the session. Logged as "ended without tag".

## Visual design ("desert dawn / ink and lamp")

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `#F7F3EC` parchment | `#0E1116` night ink | app background |
| surface | `#FFFFFF` | `#171B22` | cards |
| focus (accent) | `#0F6E6A` | `#3FB8AE` | session, primary buttons |
| gold | `#C8902E` | `#E2B45A` | streaks, check-ins |
| pass | `#D9822B` | `#F0A04B` | passes, back-to-back warning |
| night | `#2B3A67` | `#7F8FD1` | night lock |
| text / secondary | `#1C1B19` / `#6B665E` | `#ECE8E1` / `#9AA0A9` | |

**Type:**
- Timers: SF Pro Rounded, monospaced digits, with a rolling number transition.
- Everything else: Dynamic Type styles.

**Motion:**
- Spring fills on start.
- Pass ring with a soft pulse in the last 10 s.
- Sunrise sweep on check-in.
- Cross-fades when Reduce Motion is on.

**Voice:**
- Block screen: "Not now / {App} will keep."
- Back-to-back: "Third pass in 30 minutes. Still worth it?"
- Start: "Focus started. 14 apps are resting."
- End: "52 minutes of focus. Well done."
- Morning: "Good morning. Tap your desk tag to begin the day."

## Platform limits we design around

- The **alarm Stop button can't be removed**. Stop works as a snooze: the alarm re-arms and the chaser alarms keep coming.
- **Screen Time numbers can't be read**, only displayed. Streaks, widgets and partner data use Tawfeeq's own event log.
- A **Shortcut can be run without the tag**, so it may *start* a session but never end one.
- **Live Activities last about 8 hours.** Night lock doesn't use one.
