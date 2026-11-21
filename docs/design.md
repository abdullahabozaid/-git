# Tawfeeq: NFC focus blocker for iPhone (design v0.2)

The app works like Brick, but uses NFC stickers you already own and adds the features below. Bundle ID `uk.tawfeeq.app`, App Group `group.uk.tawfeeq`, tag links on `tawfeeq.uk`. The evidence behind each decision is in [research.md](research.md).

## 1. What you asked for (interview summary)

| Area | Decision |
|---|---|
| Platform | iPhone only. You have a Mac and a paid Apple Developer account. |
| Tag | Blank NTAG stickers or cards. One is fixed to the desk; spares are at home. |
| Tap behaviour | **Toggle.** Tap the desk tag to start a session; tap the same tag again to end it. |
| What gets blocked | **Specific apps you pick**, plus an **allowlist** of apps that are never blocked. |
| Emergency override | **Temporary pass**, inside the app. Unlimited, but each pass lasts only **5 minutes**, then blocking re-applies automatically. Every pass is logged. Taking passes back-to-back shows a warning in stats. |
| Strictness | **Moderate.** Cheating is possible with effort, but it's visible in stats and to your partner. |
| Wake-up | You set the timings in the app. **Alarms** are built in, and fully dismissing one requires the desk tag. |
| Stats | Screen time, focus time, streaks, passes, morning check-ins. |
| Accountability | A **partner** sees your focus sessions, passes, morning routine and daily screen time, in an app on **their own iPhone**. |

## 2. Lessons from existing projects

- **[Foqos](https://github.com/awaseem/foqos)** (MIT, ~940★, active) is the closest open-source match. We'll borrow its proven patterns rather than fork it. Its features are broad (QR, timers, macOS) and ours (alarms, partner) are new, so a focused codebase stays easier to own. Patterns we reuse:
  - One named `ManagedSettingsStore`, which is cleared completely on stop.
  - Tag pairing by UID through `NFCTagReaderSession`.
  - The **00:00 → now+5 min** DeviceActivity trick for the 5-minute pass, which gets around the 15-minute minimum interval.
  - App Intents so a Shortcuts NFC automation can trigger the app.
- **open-blocker** does a **two-tap UID check** at enrollment, so cards whose ID changes each tap are rejected. We'll do the same.
- **Touchstone, PuckAlarm and SureAlarm** show how to require an NFC tap to stop an AlarmKit alarm. iOS always keeps a Stop button, so these apps re-arm the alarm when it's stopped and schedule backup "chaser" alarms.
- **Known failure modes we design against:**
  - Shields stay stuck after unblocking.
  - Schedule callbacks are sometimes missed.
  - More than 50 app tokens fails silently, with nothing blocked.
  - Users edit the block list or schedule to escape a session (Foqos #119 and #600).
  - Emergency counters stored in local app storage reset when you reinstall.

## 3. How it works on iPhone

### 3.1 Building blocks

```
Tawfeeq (app, SwiftUI)
├── DeviceActivityMonitor ext  → applies/removes shields on schedule & pass expiry; records screen-time thresholds
├── ShieldConfiguration ext    → custom "You're in focus" screen
├── ShieldAction ext           → "Take 5-min pass" button right on the shield
├── DeviceActivityReport ext   → screen-time charts shown inside the Stats tab
├── Widget ext                 → Live Activity / Lock Screen timer + required by AlarmKit countdowns
└── App Group                  → shared state (session, passes, event log) between all of the above

Tawfeeq Partner (companion app, NO Screen Time entitlement)
└── reads your shared CloudKit zone, shows dashboard, gets alerts
```

### 3.2 The tag

- **Enroll**:
  1. Tap the tag twice. The UIDs must match.
  2. The app writes an NDEF record to the sticker that holds a random 128-bit ID.
  3. The tag is stored with a role.
- **Roles**:
  - `desk`: starts and stops sessions, and confirms the morning check-in.
  - `spare`: an optional backup kept in a drawer, which can also end a session. Use a spare sticker for it.
- **Fast trigger (optional)**: a Shortcuts personal automation, "When NFC tag *Desk* is scanned → Run *Tawfeeq Toggle*":
  - If no session is running, it **starts one in the background**, with no app opening.
  - If a session is running, it **opens the app on the scan screen**, and an in-app scan of the real tag ends the session. A shortcut is never trusted as proof for stopping, because you could run it by hand.
- Security note: a UID can be cloned. The tag adds friction for honesty; it isn't real security, and that's fine for this purpose.

### 3.3 Focus session (toggle)

```
idle ──tap desk tag──▶ focusing ──tap desk tag (in-app scan)──▶ idle
                          │  ▲
              take pass   │  │ 5 min later (auto)
                          ▼  │
                        on pass
```

- **Start**: apply shields to your picked apps.
  - If your list exceeds 50 apps, the UI warns you, because iOS fails silently above 50.
  - Optional `denyAppRemoval` during a session (on by default for "moderate"). It can't be bypassed in-session, but passes still work.
- **During a session**, the **block list, allowlist and schedules are read-only**. They're also locked for 30 minutes before a scheduled start (configurable). Any edit made outside those windows is logged.
- **Stop** clears every setting in the store, then the app checks that the shields are actually gone. This is our fix for stuck shields.
- **Self-heal**: whenever the app opens, it compares the expected state (in the App Group) with the real store and fixes any difference. This covers missed extension callbacks.

### 3.4 Temporary pass (emergency override)

- It's available from the **shield screen itself** (secondary button "5-minute pass") and from the app.
- On use:
  1. Unshield.
  2. Log the pass.
  3. Schedule a one-off DeviceActivity interval that ends at now + 5 min; `intervalDidEnd` re-shields.
  4. Also store `passExpiresAt`, so the self-heal check catches it if the callback is missed.
  5. A Live Activity shows the countdown.
- **Unlimited**, as you asked, but:
  - Stats show passes today and this week, plus "back-to-back" streaks (a new pass within 2 minutes of the last ending).
  - Your partner sees the count and can choose alerts like "3rd pass today".
- **Edge case to test**: a pass that crosses midnight. The fallback is the self-heal check plus a second monitor.

### 3.5 Schedules, night lock and alarms

You set the times in **Settings → Routine**:

- **Night lock** (e.g. 22:30 → morning). A repeating DeviceActivity schedule applies your "night" block list when it starts.
  - When it ends, **nothing happens**: the lock stays on until you **tap the desk tag** in the morning. That's what gets you out of bed.
  - Passes still work, since strictness is moderate.
- **Wake alarm** (AlarmKit, iOS 26+). It rings through Silent mode and Focus modes and survives reboots. The buttons:
  - **Stop**: iOS always shows it and we can't remove it. Stopping **re-arms the alarm about 60 s later** unless the desk tag has been scanned.
  - **"Scan desk tag"**: opens the app straight into the NFC scan. A good scan:
    1. cancels every pending alarm;
    2. ends the night lock;
    3. records your **morning check-in time**;
    4. optionally starts a morning focus session right away.
  - **Backup chaser alarms** every minute for 15 minutes cover the cases where iOS doesn't tell us about a Stop (e.g. the power button).
  - Re-arming gives up after 1 hour, a safety cap so you can't oversleep forever.
- **Scheduled focus blocks** (e.g. weekdays 9:00–12:00) start automatically; the desk tag ends one early. Limit: about 20 monitored activities in total, which is plenty.

### 3.6 Stats tab

| Section | Source | Notes |
|---|---|---|
| Screen time today/week, pickups, top apps, first pickup | `DeviceActivityReport` extension | Shown in-app only. iOS doesn't let these numbers leave the extension. |
| Focus time, sessions, streaks (days with ≥ X min focus) | Our own event log | Fully available. |
| Passes: count, times, back-to-back warnings | Event log | |
| Morning: alarm time vs check-in time, snoozes/re-arms | Event log | |
| Screen time milestones: "crossed 2h at 15:40" | `DeviceActivityEvent` thresholds (1h…8h) written by the monitor extension | Approximate. iOS is known to fire these early sometimes. Shareable with your partner. |

### 3.7 Accountability partner

- **What your partner sees**:
  - focus sessions (start, end, length, and whether they ended by **tag**, **spare tag** or something else);
  - every pass;
  - morning check-in vs alarm time;
  - daily screen time **milestones** (approximate), not exact per-app minutes. An in-app "share screenshot" button lets you send the exact chart manually.
- **Tamper signals** are also shared, for the moderate strictness level:
  - Screen Time permission revoked;
  - the app reinstalled;
  - the block list edited;
  - a schedule disabled.
- A **"What my partner sees"** screen shows exactly what's shared, so nothing is hidden.
- **Transport: CloudKit sharing (`CKShare`)**:
  - You invite your partner with an iMessage link. They need an iCloud account.
  - There's no server to run and no cost.
  - Alerts come from CloudKit subscriptions plus a local notification. They can arrive a few minutes late, which is acceptable for accountability.
- **Getting it onto their phone**: a separate **"Tawfeeq Partner"** companion app with no Screen Time entitlement.
  - It goes out through **TestFlight with no Apple approval needed**. Builds last 90 days; push a new one each quarter.
  - Two-way accountability (they block too) needs the full app on their phone, by one of:
    - a development build installed from your Mac (device registered, valid for about 1 year);
    - TestFlight after Apple approves the **Family Controls Distribution** entitlement, which can take 2 weeks to over a month. **Request it now in parallel**, for the app and every extension, if two-way matters.

## 4. Build plan

| Phase | Deliverable | You can test |
|---|---|---|
| 1. Core | Xcode project (XcodeGen), App Group, Screen Time authorization, app picker + allowlist, tag enrollment, toggle start/stop, custom shield | Tap the desk tag and apps are blocked; tap again and they're unblocked. |
| 2. Passes + robustness | ShieldAction pass button, 5-min auto re-shield, self-heal, editor locks, `denyAppRemoval`, Shortcuts toggle intent | Take a pass from the shield and see apps re-block after 5 min. |
| 3. Routine | Night lock, AlarmKit alarm with tag-to-dismiss and chasers, scheduled focus blocks | The alarm only fully goes away after tapping the desk tag. |
| 4. Stats | Event log (SwiftData), report extension, streaks, milestones | The Stats tab works. |
| 5. Partner | CloudKit share, companion app, alerts, "what my partner sees" | Your partner installs via TestFlight and sees your day. |
| 6. Polish | Live Activity/widget, onboarding, Lock Screen controls | |

I write the Swift code in this repo. You build and run it from Xcode on your Mac, because Screen Time and NFC only work on a real iPhone, not the simulator.

## 5. Decisions and open items

- ✅ iPhone on iOS 26+, so AlarmKit alarms are in.
- ✅ Name **Tawfeeq**. You own **tawfeeq.uk**, so tags carry `https://tawfeeq.uk/t/<secret>` links. Setup is in [setup.md](setup.md).
- ⏳ **Partner: not decided yet.** It stays optional, and the default is one-way via the companion app. We decide before phase 5. Until then, don't request the Family Controls Distribution entitlement.
- ⏳ Where tawfeeq.uk is hosted, so we can serve the `apple-app-site-association` file.

## 6. Status

- **Phases 1–2** (core, passes, Shortcuts trigger) are written but **not yet compiled or tested**: this was written in a Linux container with no Xcode. See [setup.md](setup.md) for how to build and the test checklist.
