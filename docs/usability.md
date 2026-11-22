# Tawfeeq: usability audit and UX metrics

This is a flow-by-flow review of the app as built. It covers:
- taps, typing and decisions per task
- Nielsen's usability heuristics
- accessibility
- the metrics that tell us whether the app actually helps

Each problem has a fix, and every fix in the **Fix** columns is implemented.

## 1. Effort per core task

Physical NFC taps don't count as screen taps. A "decision" is any point where the user has to choose something.

| Task | Before: taps · typing · decisions | After | What changed |
|---|---|---|---|
| Start a session (Shortcut set up) | 0 · 0 · 0 | 0 · 0 · 0 | already ideal |
| Start a session (in app) | 1 · 0 · 0 | 1 · 0 · 0 | |
| End a session | 2 (scan + **Done** on summary) · 0 · 0 | **1** · 0 · 0 | summary auto-dismisses after 4 s; tap anywhere to close |
| Take a pass (app) | 4 (open, reason, breathe, unlock) · 0 · 1 | **3** · 0 · 1 | choosing a reason starts the breathing wait |
| Take a pass (block screen) | 2 + wait | 2 + wait | the friction is intended |
| Morning check-in | 2 (alarm button + **Done**) | **1** | auto-dismiss |
| Add a tag | 3 + **typing a name** | 2 · **0 typing** | name chips (Desk, Drawer, Bag, Car); typing is optional |
| Change wake time | 4 (Rules → row → picker → **Save**) | **3** · no Save | auto-save; nothing is lost if you leave the screen |
| Set daily goal to 4 h | **8 taps** on a 15-min stepper | **1** | preset chips: 1h, 2h, 3h, 4h, 6h |
| Edit always-allowed apps | 3 (Rules → Block list → button) | **2** | the Rules row opens the picker directly |
| First run to first session | ~11 taps, can't go back, dead end if permission is denied | ~11 taps, **Back** button, **skip tag**, Settings link if denied | |

**Typing:** none of Tawfeeq's normal tasks need the keyboard now. Naming a tag is optional and suggested. The only free text left is a custom tag name.

## 2. Heuristic review (Nielsen)

| # | Heuristic | Problem found | Fix |
|---|---|---|---|
| H1 | Visibility of system status | NFC failures showed generic alerts titled "Tawfeeq"; the block screen gave no live countdown | Error-specific titles and copy; the shield says exactly how many seconds are left after an early tap |
| H2 | Match with the real world | "Tags tab" in an error message (that tab no longer exists) | Copy now points to **Settings → Tags** |
| H3 | User control and freedom | Onboarding had no Back; the routine needed Save, so leaving the screen discarded changes | **Back** in onboarding; routine **auto-saves** |
| H4 | Consistency | Two Rules rows ("Block list", "Always allowed") opened the same screen | Each row goes to its own target |
| H5 | Error prevention | The goal stepper made it easy to overshoot; the empty block list only surfaced at start time | Goal presets; an inline **Choose apps** call-to-action on Focus before you can start |
| H6 | Recognition rather than recall | Tag names had to be typed | Name chips |
| H7 | Flexibility and efficiency | (already good) Shortcut, Control Center, widgets, Siri | — |
| H8 | Minimalist design | The summary sheet needed an extra tap every session | Auto-dismiss |
| H9 | Recover from errors | A denied Screen Time permission was a dead end; NFC errors had no retry | **Open Settings** and **Try again** buttons in the alerts |
| H10 | Help | The Shortcut guide and lost-tag help existed but were hidden in Settings | Onboarding's last step links the Shortcut guide; the error alert links lost-tag help |

## 3. Accessibility audit

| Area | Problem | Fix |
|---|---|---|
| Dynamic Type | Timer (56 pt) and dial (260 pt) were fixed sizes; the 4-chip today strip truncated at large sizes | `@ScaledMetric` timer and dial, capped; the strip becomes a 2×2 grid at accessibility sizes |
| VoiceOver | The dial was read as separate fragments that re-announced every second | One combined element: "Focusing, 42 minutes. 14 apps resting." |
| VoiceOver | Hold-to-start (a long press) is hard with VoiceOver | Named action "Start without tag" |
| VoiceOver | Today chips read "42m, today" | Labels like "42 minutes focused today" |
| Contrast | Amber text `#D9822B` on parchment is ~2.8:1 (fails AA) | Darker amber for text in light mode (`#A65E14`, ~4.7:1) |
| Motion | Pulse and breathing animations | Already respect Reduce Motion; the sunrise falls back to a fade |
| Haptics | — | Already have an off switch |

## 4. UX metrics (measured on-device, never sent anywhere)

All metrics come from Tawfeeq's own event log. The ones that matter to you are shown in Insights.

| Metric | Why it matters | How it's measured | Where you see it |
|---|---|---|---|
| **Changed my mind** (passes abandoned) | The best sign that friction works. one sec reports ~36% of opens abandoned. | `passSheetOpened` / shield first taps with no pass started | Insights → Passes |
| Passes per session, back-to-back passes | Shows whether a bypass is turning into a habit | `passStarted` with `backToBack` | Insights → Passes |
| Focus time vs goal, streak | The core outcome | `sessionEnded` | Insights, widgets |
| Minutes from alarm to check-in | Whether the morning routine works | `morningCheckIn.minutesFromAlarm` | Insights → Mornings |
| Alarm snoozes (Stop pressed) | Whether the re-arm chain is needed | `alarmStopped` | Insights → Mornings |
| NFC scan success rate | Reliability; a weak sticker position shows up here | `scanSucceeded` / `scanFailed` with reason | Settings → Diagnostics |
| Ended without tag | Escape-hatch use; should stay near 0 | `sessionEnded.endedBy = breakGlass` | Insights → Passes |
| Time to first session | How smooth onboarding is | `onboardingStarted` → first `sessionStarted` | Settings → Diagnostics |
