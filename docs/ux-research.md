# Tawfeeq: UX research and design direction

Researched 2026-11-22. **[V]** means verified from a cited source or from code I read. **[I]** means my own inference or recommendation. Most App Store, press and community claims are developer-supplied or anecdotal, and are labelled that way.

---

## 0. What the competitors actually do (condensed evidence)

| App | Verified UX facts | Source |
|---|---|---|
| **Brick** (NFC puck, $59) | **[V]** Tap the phone on the puck to lock it and tap again to unlock. You can also start remotely by press-and-holding a virtual Brick in the app for 5 s, but unbricking still needs the physical tap. You get 5 Emergency Unbricks, and once they are gone you have to email support. Up to 10 modes or schedules, each blocking all apps, selected apps, or all except selected ones. Strict Mode stops you deleting the app or changing settings mid-session. "Weekly Activity" shows time gained. While bricked, reaching for a blocked app shows the Brick image and the elapsed time. One tester found the elapsed timer anxiety-inducing ("made her think about what she was missing"), and another found it raised awareness. Schedules are the #1 complaint in App Store reviews because they are unreliable. Copy is calm and anti-shame: "Reclaim your time, Brick by Brick", "No overrides or workarounds, just uninterrupted time until you're ready to reconnect." Reviewers call it "less intrusive and non-judgmental" than Opal. | [NBC Select](https://www.nbcnews.com/select/shopping/brick-phone-app-blocker-review-rcna259740), [App Store](https://apps.apple.com/us/app/6448794069), [getbrick.com](https://getbrick.com/), [search summary incl. Android Authority/Fox](https://cellphoneplans.androidauthority.com/CellPhones/Guides/brick-for-phone-limits-app-review) |
| **Bloom** (NFC card) | **[V]** Tap the card to block and tap again to unblock. Optional strict mode stops you deleting the app during a session. Up to **3** emergency exits that work without the card. Schedule glitches show up in reviews. | [App Store](https://apps.apple.com/app/id6736728158) |
| **Unpluq** (NFC keychain tag) | **[V]** Besides the Tag, it offers other "barriers": tap patterns, shaking, scrolling blank space, a random barrier, or a QR scan. A student reviewer found it easy to get around because "there's no barrier to requesting more time". | [The Tech](https://thetech.com/2025/10/16/unpluq-review), [TrendHunter](https://www.trendhunter.com/trends/unpluq-tag) |
| **Opal** (ADA 2025 Social Impact finalist) | **[V]** Onboarding runs about 24 steps: a quiz, then a personalised "Focus Report" projecting your lifetime phone hours (e.g. "9 years+ reclaimed"), a fist-bump commitment animation, a soft paywall with a 7-day trial and a before/after chart, then a "First Gem" unlock. Contextual tooltips on Home instead of a tutorial. Sessions run for a set duration or are "Always On". Breaks go: pick an app, write an intention, set a timer. A **Waiting Room** comes before unblocking, with "Resistance" set to Standard or Increasing (each unblock waits longer). Hard/Deep Focus mode can't be bypassed. Block screens are customisable (AI personalities from "Shrek" to "Brutal Insults"). There's an Opal Score (Focus/Sleep/Rest), gems, streaks and a leaderboard. Recent versions added a Home "mini player" for the active rule, today's top 3 distracting apps, Live Activities, timer and rules widgets, tinted-widget support, and an option to remove the "Open Opal" shortcut from block screens. Complaints: gem themes are hard to notice, rules turn on at odd times and don't sync with Focus modes, users park the waiting room or edit it mid-countdown, and the community reports that "pause is one tap". | [screensdesign teardown](https://screensdesign.com/showcase/opal-screen-time-control), [App Store](https://apps.apple.com/us/app/opal-screen-time-for-focus/id1497465230), [opalapp.com](https://opalapp.com/), [Opal help: waiting room](https://help.opalapp.com/article/how-to-choose-your-waiting-room), [community thread](https://community.opalapp.com/t/make-it-impossible-to-change-your-waiting-room-while-in-the-waiting-room/10994), [Apple Newsroom ADA 2025](https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/) |
| **one sec** | **[V]** A full-screen breathing pause (black screen, "take a deep breath"), then a confirmation asking whether you still want to open the app. It may ask why. Re-intervention kicks you out after N minutes. Interventions include breathing, 4-7-8, mirror camera, rotate phone, type random text, journaling, conversational reflection and "U sure bout that?". Reviewers highlight the count of opens in the last 24 h and the time since last open. Widgets and Live Activities can start a block session. Supports Reduced Motion and VoiceOver. Built on a Shortcuts automation that is now importable. The cited PNAS 2023 study reports 57% fewer openings (co-authored by the developer). Users say the effect fades over weeks. | [one-sec.app](https://one-sec.app/), [App Store](https://apps.apple.com/app/id1532875441), [Bustle](https://www.bustle.com/wellness/one-sec-app-review-lowering-screen-time) |
| **ScreenZen** | **[V]** Shows a delay screen with a reflective prompt. The wait can increase with each open. Limited opens per day. Onboarding has 5 steps: "Choose your apps, Limit your screen time, Schedule blocks, Use your apps mindfully, Track your wins". One user said a limited number of opens "makes me cherish each one". Critics say friction fades once tapping through becomes its own reflex. | [screenzen.co](https://www.screenzen.co/), [App Store](https://apps.apple.com/app/screenzen-screen-time-control/id1541027222), [lifestack review](https://lifestack.ai/blog/screenzen-review) |
| **Foqos** (open source, NFC, code read) | **[V, from code]** The shield shows random paired copy (emoji, title, subtitle, button), e.g. "🧠 Brain check / Do you actually want {app}… or was it autopilot? / Return" and "🫶 Be kind to you / No shame. Just a gentle nudge back to what matters." Shield colour is the user's theme colour with a dark blur. On the soft-unblock shield, the primary button reads "Open for 5m" and the subtitle shows "{app} (2/3)" plus allowance and reset lines. Once exhausted it reads "You used all 3 opens for this session." Emergency Access has a limited count with a reset interval measured in weeks ("Next reset: …"). **BreakGlassButton**: a frosted-glass overlay you tap 3 times; cracks render at each tap point with light-impact haptics, then it shatters with a success haptic. The permission screen reads "One Last Step", with a pulsing shield and the copy "No account required. No tracking." The Live Activity has a timer that swaps to a ☕ symbol on breaks and a ⏸ symbol on pauses, and tints the keyline with the theme colour. Control Center has a Profile toggle and a Break toggle. Stopping from a control is refused when a profile disallows background stops, with the message "Background stops are disabled for this profile. Stop it in Foqos." The timer uses `.contentTransition(.numericText())`. There's a 4-week heatmap, a habit tracker and weekly/monthly charts. Tags are identified by NFC UID. | [github.com/awaseem/foqos](https://github.com/awaseem/foqos) (files: `FoqosShieldConfig/ShieldConfigurationExtension.swift`, `Foqos/Components/Common/BreakGlassButton.swift`, `Foqos/Views/EmergencyView.swift`, `FoqosWidget/*`) |
| **Forest** | **[V]** Plant a tree as the timer, and leaving the app withers it. Dead trees stay in your forest as an honest record. Deep Focus: "Give Up" kills the tree. The forest is the stats view. Tone: "no shame, no preaching", "encouraging when you're close and gentle when you're not." | [forestapp.cc](https://www.forestapp.cc/) |
| **Structured** | **[V]** Praised for an uncluttered timeline, Live Activities and interactive widgets. Sync is the main complaint. | [AppleInsider](https://forums.appleinsider.com/discussion/230281) |
| **Alarmy** | **[V]** Barcode or QR mission: you register an object, and the alarm keeps ringing until you scan it. Pain points: the registered object gets lost or thrown away, or you travel. Users have to remember to turn the sound on. Heavy upsell. | [search summary incl. Bustle](https://www.bustle.com/wellness/alarmy-app-review-sleep-hack), [App Store](https://apps.apple.com/app/1163786766) |
| **Apple Clock (iOS 26.1+)** | **[V]** iOS 26 enlarged Stop and Snooze. 26.1 switched Stop to **Slide to Stop** to prevent half-asleep dismissal, with an accessibility opt-out ("Prefer Single-Touch Actions"). | [MacRumors](https://www.macrumors.com/2025/10/08/ios-26-1-beta-stop-silencing-alarms-accident/), [9to5Mac](https://9to5mac.com/2025/12/11/ios-26-1-makes-alarms-use-a-slider-heres-how-to-get-stop-button-back/) |

**Platform constraints that shape the design (verified):**
- **AlarmKit:** "The system provides a stop button automatically." The custom `stopButton` init is **deprecated**, and the only option you control is a secondary button (`.countdown` = Repeat, or `.custom` = open the app via an App Intent). **You cannot make an alarm that can only be stopped by NFC.** Developer forums also report that `stopIntent` does not fire on every dismissal path, for example when the power button is pressed on a locked screen. [Alert docs](https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct.md), [sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit), [forum 815064](https://developer.apple.com/forums/thread/815064). AlarmKit expects a widget extension if you use a countdown presentation.
- **DeviceActivityReport is display-only.** Its sandbox blocks writes and network, and Apple DTS confirmed this is intentional. Screen-time totals **cannot** be put into your own charts, streak logic or partner sharing. [forum 818174](https://developer.apple.com/forums/thread/818174), [817516](https://developer.apple.com/forums/thread/817516)
- **Live Activities** suit activities up to 8 h. Custom animations max out at 2 s. Use a single interactive element where possible. End the activity immediately and set a dismissal of about 15–30 min. Compact and minimal views must fit a 28 pt circle at limited width. Show a timer in the minimal view instead of a logo. [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- **Controls:** provide symbols for both on and off states, animate the state change, set a tint, add Action-button hint text with a verb, and refresh state after actions. [HIG Controls](https://developer.apple.com/design/human-interface-guidelines/controls)
- **Liquid Glass** is for the navigation and control layer only. Don't use it in the content layer, use it sparingly on custom controls, and use standard materials for content. [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- **Shortcuts NFC automations** can "Run Immediately" with "Notify When Run" off. [Apple Shortcuts guide](https://support.apple.com/guide/shortcuts/apd602971e63/ios), [iMore](https://www.imore.com/shortcuts-beta-adds-notify-when-run-toggle-hide-automations-summary-view)
- **Short passes:** a `DeviceActivitySchedule` normally needs at least 15 min. Foqos works around this for a 5-minute grant by starting the interval at **start of day** and ending it at the grant's expiry, so `intervalDidEnd` re-shields on time. **[V, code]** `SoftUnblockGrantScheduler.swift`.

---

## 1. UX principles for Tawfeeq (ranked)

1. **The tag is the product, so the app should feel almost invisible.** Brick's praise centres on one physical gesture and on its friction being physical rather than willpower-based ("couldn't be bothered to walk to the garage"). Starting and stopping must be a single tap with instant, multi-sensory confirmation, and should never need the app opened. [V Brick reviews; I]
2. **Calm, no shame.** The best-reviewed products (Brick, Forest, Foqos copy) reject guilt. Opal's insults and leaderboards divide people. For an app named "divine facilitation", the voice should be gentle, dignified and encouraging. [V tone sources; I]
3. **Honest friction, not fake walls.** Unlimited passes are a deliberate choice. Make each one *conscious* (a visible count, a wait, an intention), *logged* and *escalating* (Opal's "Increasing" resistance, ScreenZen's growing wait), rather than impossible. [V; I]
4. **State is legible everywhere, at a glance.** Show whether a session is on, for how long, whether a pass is running and how much is left, consistently across app, Live Activity, Lock Screen widget, Control Center and shield. [V HIG; I]
5. **Reliability is the brand.** Brick's and Opal's worst reviews are about schedules misfiring. Night lock and alarm must be dependable, with redundant scheduling and clear recovery. [V]
6. **Show progress gently.** Use elapsed focus rather than a looming countdown by default, since one Brick tester found the timer anxious. Let users hide the timer. [V NBC; I]
7. **Celebrate consistency, not perfection.** Streaks with grace days, and honest records (Forest keeps dead trees) rather than punitive resets. [V Forest; I]
8. **Respect the platform.** Use Liquid Glass chrome only, system controls, SF Symbols, Dynamic Type and Reduced Motion. [V HIG]

---

## 2. Patterns to copy

| # | Pattern | Source | Why it works / how to adapt |
|---|---|---|---|
| 1 | **One tap toggles; the remote start is allowed but stopping requires the tag** | Brick [V] | Starting is low-risk and stopping is the commitment. Tawfeeq: let Control Center, a widget or Siri *start* a session, but *ending* it needs a desk-tag scan (or a pass). Foqos does the same with its "background stops disabled" rule [V code]. |
| 2 | **Press-and-hold (5 s) to start from the app** | Brick [V] | Deliberate and resistant to accidental taps. Use a hold-to-start ring that fills, with escalating haptic ticks. |
| 3 | **Allowance shown on the shield: "Open for 5m · 2/3"** | Foqos [V] | Puts the cost in front of you at the moment of temptation. For unlimited passes, show "Pass #4 today" instead of a quota. |
| 4 | **Escalating wait ("Increasing resistance")** | Opal, ScreenZen [V] | Unlimited but not free. Example: pass 1 = 5 s breath, pass 2 = 15 s, pass 3+ = 30 s plus typed intention. Opal's bug history shows you must stop waits being "parked" or edited mid-countdown [V]. |
| 5 | **Intention prompt before a break** | Opal ("write an intention"), one sec ("why?") [V] | Logs *why*, which feeds stats ("Most passes: 'reply to message'"). Offer one-tap chips (Message, Navigation, Work, Other). |
| 6 | **Count of opens plus time since last open** | one sec [V reviews] | Reviewers cite it as the most effective number. On the pass screen: "3rd pass in 40 min." This is also the back-to-back warning. |
| 7 | **Break-glass emergency affordance** | Foqos BreakGlassButton [V code] | Tactile and memorable. Taps crack the glass with haptics, which adds a moment of thought without being punitive. Use it for "End without tag" (if offered) and for "I lost my tag". |
| 8 | **Rotating, paired shield copy with the app name interpolated** | Foqos [V code] | Avoids banner blindness. Write a Tawfeeq set (see §5). |
| 9 | **Honest history (dead trees stay)** | Forest [V] | Sessions ended early or long passes appear in the record, rendered neutrally rather than in red. |
| 10 | **Contextual tooltips instead of a tour** | Opal [V teardown] | Teach "Tap your desk tag to begin" on Home at the right moment. |
| 11 | **Mini-player for the active session on Home** | Opal 4.21 [V] | Use the iOS 26 tab-bar bottom accessory (`tabViewBottomAccessory`) to show the session or pass status app-wide. [I, matches HIG "attached accessory"] |
| 12 | **"Weekly Activity: time gained"** | Brick [V] | One headline number per week, and positive. |
| 13 | **Slide to stop** | Apple Clock 26.1 [V] | For any destructive in-app end ("End session early", "Stop alarm without check-in"), use a slider rather than a button. |
| 14 | **Live Activity swaps symbol by state (timer / ☕ / ⏸) and tints the keyline** | Foqos [V code] | Recognisable at a glance. Apply it to pass mode. |
| 15 | **Privacy reassurance at the permission step** | Foqos "One Last Step… No account required. No tracking." [V code] | Reduces fear of the Screen Time prompt. |
| 16 | **Barcode/scan-to-dismiss alarm mission** | Alarmy [V] | Desk-tag check-in is the same idea with an NFC tag. Learn from its pain point: always provide a spare-tag path and a traveling mode. |

---

## 3. Information architecture

Use an iOS 26 floating Liquid Glass tab bar with **4 tabs** plus a bottom accessory. [I; HIG: fewer tabs, single-word labels, filled SF Symbols]

1. **Focus** (`circle.circle.fill` or custom tag glyph). This is the home screen.
   - *Idle:* a large calm "desk" illustration with the tag glyph and "Tap your desk tag to begin". A secondary hold-to-start button. Today strip: focus time, sessions, passes, streak flame. Next scheduled event ("Night lock at 23:00").
   - *In session:* the whole canvas shifts to the session colour. A big elapsed timer (numericText transition) with optional "ends at". A ring for planned duration if one is set. Blocking summary ("14 apps · 3 categories blocked"). Pass counter today. Primary action: "Tap desk tag to finish". Secondary: "Take a pass".
   - *Pass running:* a countdown ring "4:12 left", the pass number, and "Return now" to end the pass early, which earns a small positive acknowledgement.
   - *Night lock:* a dark nocturne theme, "Resting until your morning check-in", wake time, and the alarm status.
2. **Rules.** These are the configuration surfaces.
   - Block list (FamilyActivityPicker), with summary chips for apps, categories and sites.
   - Allowlist ("Always available": Phone, Messages, Maps…).
   - Passes: length (5 min fixed), escalation on/off, back-to-back threshold, intention prompt on/off.
   - Night lock: bedtime, days, and a separate block list if different.
   - Morning: alarm time, sound, check-in required, grace snoozes.
3. **Insights.**
   - Week selector. Hero card: "Focus this week 14h 20m" with delta.
   - Focus-time bar chart by day. A streak calendar heatmap (Foqos-style 4-week grid).
   - Passes: count per day, intentions breakdown, back-to-back incidents.
   - Check-ins: on-time morning check-ins (dots on a week strip, with the time each was checked in).
   - Screen Time: an embedded `DeviceActivityReport` card (display only; see §7).
   - Later: a shareable weekly summary for the accountability partner.
4. **Settings** (or **You**).
   - Tags: desk tag(s), spare tags, last scanned, add/rename/retire.
   - Shortcuts automation setup guide.
   - Accountability partner (future), appearance, haptics/sounds, strictness, help, privacy.

**Bottom accessory:** the active session or pass mini-player, visible on every tab. **[I]**

---

## 4. Key flows

### 4.1 First-run onboarding (target 6–8 screens, under 2 minutes) [I, informed by ScreenZen's 5 steps and the Opal teardown]
1. **Welcome:** "Tawfeeq" in Arabic calligraphy and Latin script, with "Focus with intention. Tap to begin." One CTA.
2. **How it works:** a 3-panel animated card stack: *Tap the desk tag → apps rest → tap again to finish*. Use a looping 3D tag animation.
3. **Your why** (optional, a single choice): Work / Study / Worship and reflection / Family / Sleep. This tunes the copy only. Skip the 24-step Opal-style quiz and lifetime-years scare.
4. **Screen Time permission:** a pre-prompt with a shield illustration and the copy "Tawfeeq uses Apple's Screen Time to rest the apps you choose. Your data stays on this iPhone." Then `AuthorizationCenter.requestAuthorization(for: .individual)`. If denied, show a recovery card with a Settings deep link.
5. **Choose distractions:** FamilyActivityPicker with suggested categories pre-explained ("Most people start with Social and Entertainment"). Then the "Always available" allowlist.
6. **Register your desk tag:** "Hold the top of your iPhone to the tag." Use a Core NFC session and confirm with a success haptic and a tag "lights up" animation. Name it ("Desk"). Offer a spare tag (optional, "Keep a spare in a drawer").
7. **Make it one tap (optional):** a Shortcuts NFC automation guide with Run Immediately and Notify When Run off, shown as an animated step list. A Skip option.
8. **Notifications and alarm** (deferred): don't ask now. Ask when the user turns on Night lock or Morning check-in. **[I: ask in context]**
9. **First session prompt:** "Try it now — tap your desk tag." The first session start fires a gentle celebratory moment (no paywall interruption).

### 4.2 Start session
Tag tap (Shortcuts intent, or in-app scan, or hold-to-start, or Control) → apply shields → `.success` haptic plus an optional soft chime → Home transitions to session colour (a 0.6 s fluid fill expanding from the tag glyph) → Live Activity starts (elapsed timer) → Control toggles refresh. When started from the Shortcut in the background, a banner reads "Focus started · 14 apps resting".

### 4.3 End session
Tag tap → "End focus?" is **not** asked, because the tag *is* the confirmation → shields removed → summary sheet: "52 minutes of focus. 1 pass." A streak tick animation, then the Live Activity ends with a 15-minute summary dismissal. When ending without a tag (if permitted, e.g. a lost tag): break-glass (3 taps) → slide to end → logged as "Ended without tag". **[I]**

### 4.4 Take a pass (from the shield)
1. Open a blocked app and the shield appears. Its title rotates. Subtitle: "Pass #3 today · last pass 12 min ago." Primary: **"Return"**. Secondary: **"Take a 5-min pass"**.
2. The secondary button runs in ShieldActionExtension. It cannot show UI, so the safest pattern is: record the pass, then return `.close` and deep-link through a notification ("Tap to start your pass"), or grant the pass directly from the extension. **[I, feasibility: ShieldAction can't present custom UI. Foqos grants directly from the extension and swaps shield copy.]**
3. Recommended: the first tap on the secondary button turns the shield into a **"waiting" shield**: "Breathe. Your pass unlocks in 10 s", which then needs a second tap to confirm. The escalating wait lives in the shield config re-render.
4. **Back-to-back warning:** if the previous pass ended less than 10 minutes ago, the subtitle switches to amber: "That's 3 passes in 30 min. Still worth it?"
5. A pass starts the Live Activity countdown "4:59", unshields for 5 min, and re-shields when the DeviceActivity interval ends. A notification at T-1 min reads "1 minute left on your pass." At the end a gentle haptic notification reads "Pass over. Welcome back."

### 4.5 Night lock
At bedtime the DeviceActivity schedule shields the night list. A notification reads "Night lock is on. Rest well." A dim Live Activity (Lock Screen / StandBy) shows "Resting · Alarm 6:30". **Live Activities cap at about 8 h, so start it at bedtime only if the night is ≤ 8 h, or start it with the morning countdown. [V limit; I]** Unlock happens only via a desk-tag scan in the morning, or after the alarm and check-in. Passes still work, but at night they follow the "Increasing" rule with a longer wait.

### 4.6 Morning alarm check-in (designed around AlarmKit limits)
- The system **always** shows Stop. Make the **secondary button the hero**: `AlarmButton(text: "Scan desk tag", systemImageName: "wave.3.right")` with `.custom` behaviour that opens the app straight into the scan sheet. **[V API]**
- **Re-arm chain [I, important]:** at bedtime, schedule the main alarm **plus 3–5 follow-up alarms** (e.g. +3, +6, +10, +15 min). A successful desk-tag check-in cancels all the remaining ones. Pressing Stop therefore only acts as a snooze. This doesn't rely on `stopIntent` firing, which forums report is unreliable [V].
- The check-in screen is full-screen, bright and warm: "Good morning. Tap your desk tag." Use a big NFC prompt and a time-since-alarm counter. On success: `.success` haptic, a sunrise animation, "Checked in at 6:34 — 4 min after your alarm." Night lock lifts and it counts toward the check-in streak.
- Failure paths: "Tag not working?" opens the spare tag, and then break-glass emergency, which is logged.
- Travel mode: skip check-in for N days, set the night before (Alarmy lesson [V]).

### 4.7 Adding a tag
Settings → Tags → "+ Add tag" → choose role (Desk / Spare) → scan → **verify by scanning again** → name and choose an icon → optionally write an NDEF URL (`tawfeeq://tag/<id>`) so background tag reading works without Shortcuts **[I; Foqos writes URL records, V code]** → show the Shortcuts automation step. Spares get a "keep it far away" hint.

### 4.8 Editing the blocklist
Rules → Block list → a summary card ("14 apps, 3 categories, 2 sites") → opens FamilyActivityPicker. **During an active session, edits that *loosen* the list are blocked** with the copy "You can add apps now; removing apps waits until your session ends." Tightening is allowed. **[I; prevents Opal's mid-countdown editing exploit, V]**

### 4.9 Stats review
A Sunday-evening notification "Your week with Tawfeeq" opens Insights for that week. The hero shows focus hours; then a streak calendar; passes with intentions; morning check-ins; then the embedded Screen Time report. End with one gentle suggestion ("Most passes happen 3–4 pm. Try a short walk then."). That suggestion is an **[I]** heuristic using only your own data.

---

## 5. Visual design direction

**Concept: "Desert dawn / ink and lamp."** Tawfeeq is a quiet blessing on effort, so aim for warmth, light and stillness rather than "productivity neon". **[I]**

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | Parchment `#F7F3EC` | Night ink `#0E1116` | App background |
| `surface` | `#FFFFFF` | `#171B22` | Cards (standard materials, not glass) |
| `accent` (focus) | Deep teal `#0F6E6A` | Teal glow `#3FB8AE` | Session state, primary buttons, tint |
| `gold` | Saffron gold `#C8902E` | `#E2B45A` | Streaks, check-ins, celebration (sparingly) |
| `pass` | Amber `#D9822B` | `#F0A04B` | Pass countdown, back-to-back warning |
| `night` | Indigo `#2B3A67` | `#7F8FD1` | Night lock theme |
| `text` / `secondary` | `#1C1B19` / `#6B665E` | `#ECE8E1` / `#9AA0A9` | |

- Never use red for "failure". Use amber for caution and neutral grey for "ended early".
- Optional geometric motif: a subtle 8-point star (khatam) used as the tag glyph and streak mark at low opacity, without overdoing ornament. **[I]**
- **Shield:** dark-blur style, accent background, white title. Use an SF Symbol as the icon (e.g. `leaf`, `moon.stars`) rather than emoji, for a more premium feel. **[I]**

**Voice and sample copy** [I]: warm, brief, second person, faith-friendly but not preachy. Optional gentle Arabic touches (e.g. "Bismillah" on start), with a setting to turn them off.
- Shield: "Not now / {App} will keep. Your time is yours on purpose." · "Steady / One more step on what matters, then decide." · "Breathe / Was that a choice, or a reflex?" Buttons: **Return** / **Take a 5-min pass**
- Back-to-back: "Third pass in 30 minutes. Still worth it?"
- Start: "Focus started. 14 apps are resting." End: "52 minutes of focus. Well done."
- Morning: "Good morning. Tap your desk tag to begin the day."

**Type scale** (SF Pro, plus SF Pro Rounded for numerals; support an Arabic face such as SF Arabic for bilingual use):
- Timer: 76 pt Rounded Semibold, monospaced digits, `.contentTransition(.numericText())`
- Large Title 34 / Title 1 28 / Title 2 22 / Headline 17 semibold / Body 17 / Callout 16 / Footnote 13 / Caption 12. Use Dynamic Type styles, not fixed sizes.
- Live Activity text: medium weight or heavier, per HIG [V].

**Motion:**
- Session start: a fluid colour fill from the tag glyph (about 0.6 s spring). Session end: the colour recedes, then a streak tick. Use `matchedGeometryEffect` for the timer moving between Home and the accessory.
- Pass: a ring countdown. Final 10 s: the ring pulses softly.
- Check-in: a sunrise gradient sweep (about 1.2 s). Respect Reduce Motion with cross-fades instead.

**Haptics** (`sensoryFeedback`):
- Tag scan success → `.success`. Session start → `.impact(weight: .medium)`. Session end → `.success` plus a soft chime.
- Hold-to-start → `.increase` ticks per 20%. Break-glass taps → `.impact(.light)`, shatter → `.success`.
- Back-to-back warning → `.warning`. Errors → `.error`.
- Keep them consistent and optional, per HIG [V].

**Sound:** optional, a single soft "oud pluck" or bell for start and end. **[I]**

---

## 6. iOS 26 surfaces and feasibility

| Surface | What to show | Feasibility |
|---|---|---|
| **Live Activity: session** | Compact: tag glyph plus elapsed timer (`Text(timerInterval:)`). Minimal: a timer, not a logo [V HIG]. Expanded: a "Take a pass" button (a `LiveActivityIntent`, one element only). Lock Screen: elapsed time, apps resting, passes today. | **High.** Start from an App Intent (the Shortcut tag tap) or in-app. Note the 8 h limit [V]: for long sessions, end and restart, or accept staleness. |
| **Live Activity: pass** | Same activity switching state: amber keyline, countdown "4:12", a "Return now" button. | **High.** Update the ContentState. The countdown is self-ticking. |
| **AlarmKit Live Activity** | Countdown and paused presentations for the alarm, plus the alert with a "Scan desk tag" secondary button. | **High.** Requires the widget extension [V]. Stop can't be removed [V], hence the re-arm chain. |
| **Control Center / Lock Screen / Action button control** | `ControlWidgetToggle` "Focus" with on/off symbols (`circle.dashed` ↔ `circle.circle.fill`) and teal tint. Turning it on starts; turning it off **refuses** (opens the app to scan) unless the user allowed control stops. A second control button: "Scan tag", which opens the app's scanner. | **High.** Foqos ships exactly this pattern [V code]. Add Action-button hint text "Start focus" [V HIG]. |
| **Lock Screen widgets** | Circular: a ring of today's focus vs goal. Rectangular: "Focusing · 42m · 1 pass" or "Next: Night lock 23:00". Inline: "🔥 12-day streak". | **High.** Must look good in vibrant monochrome [V HIG]. |
| **Home Screen widgets** (small/medium, interactive) | Small: status plus a hold-free "Start" button (`Button(intent:)`). Medium: today's stats plus a streak. Support clear/tinted Liquid Glass appearances [V HIG]. | **High** for focus/streak/pass data you store in the App Group. **Not possible** for Screen Time totals, which can't leave the report extension [V]. |
| **StandBy** | The night-lock Live Activity in red-tinted low light. | **Medium.** Bounded by the 8 h limit. |
| **App Shortcuts / Siri** | "Start focus with Tawfeeq", "How long have I focused today?", "Take a pass". | **High** (AppShortcutsProvider). |
| **Focus Filter** | Optionally sync with an iOS Focus (Opal users complain this is flaky [V], so make it one-way and optional). | **Medium.** |

**Security note [I]:** the Shortcuts tag automation calls an App Intent, and any Shortcut can call that intent without the tag. Treat intent-based *stop* as a convenience, and require an **in-app Core NFC scan that verifies the tag UID** for the strict paths: morning check-in, night-lock release, and strict-mode stop. Foqos identifies tags by UID [V code].

---

## 7. Anti-patterns to avoid

1. **Scare onboarding and long quizzes.** Opal's "35 years of your life" projection and 24 steps convert well but conflict with a calm, dignified brand. [V Opal teardown; I]
2. **Shaming or insulting copy, and leaderboards by default.** Brick is praised as "non-judgmental" in direct contrast to Opal [V]. If the accountability partner arrives, keep it consent-based and summary-only.
3. **One-tap bypass.** "Pause is one tap" is Opal's most-cited weakness [V]. Every bypass needs a wait, an intention and a log.
4. **Editable friction mid-wait.** Users park the waiting room or shorten it while counting down [V Opal community]. Lock settings during a pass or wait, and lock loosening edits during a session.
5. **Silent schedule failures.** These are Brick's and Opal's most common complaints [V]. Verify that the shield actually applied, show "Night lock armed ✓", and notify on failure.
6. **Promising an NFC-only alarm.** AlarmKit's system Stop always exists [V]. Be honest ("Stopping the alarm snoozes it until you check in") and use the re-arm chain.
7. **Charts that pretend to read Screen Time data.** You can only *display* `DeviceActivityReport` [V]. Don't build streaks, scores or partner sharing on numbers you can't access.
8. **Single point of physical failure.** Alarmy users get locked out by lost barcodes, and Brick requires emailing support [V]. Use a spare tag plus break-glass, both logged.
9. **Liquid Glass everywhere.** HIG says glass is for navigation and controls, used sparingly [V]. Keep cards on standard materials.
10. **Anxious countdowns as the default.** Default to elapsed time, with a "hide timer" option [V NBC tester].
11. **Gamification nobody notices.** Opal gem themes went unnoticed [V]. If you add rewards, make them visible (app icon or theme), or skip them.
12. **Paywall before the first tap.** Let the first session happen before any upsell. **[I]**
