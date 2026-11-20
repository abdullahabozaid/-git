# NFC "tap to focus" phone blockers: research report for a DIY build (iPhone-first)

Research date: 2026-11-20. Evidence labels used throughout:
- **[src]**: I read it in cloned source code (repos were cloned and read during research)
- **[doc]**: official Apple or Google documentation, fetched for this report
- **[web]**: forums, reviews or vendor pages. These are anecdotal or marketing.
- **[inf]**: my inference or general platform knowledge, not checked for this report

---

## 1. Open-source landscape

| Repo | Stars / last push | Platform, license | Mechanism (summary) |
|---|---|---|---|
| [awaseem/foqos](https://github.com/awaseem/foqos) | 939 / 2026-11-14 | iOS (Swift; also macOS), MIT | Screen Time APIs, NFC/QR/timer strategies, emergency unblocks, App Intents. **Best reference.** [src] |
| [OzTamir/broke](https://github.com/OzTamir/broke) | 213 / 2025-02 | iOS, Apache-2.0 | `NFCNDEFReaderSession`. The tag stores the text `BROKE-IS-GREAT`, so any tag with that text unlocks. [src] |
| [BuckDenver/Locked](https://github.com/BuckDenver/Locked) | 12 / 2026-01 | iOS, Apache-2.0 | Broke fork that adds a timer and a custom shield. [src README] |
| [fjenn/open-blocker](https://github.com/fjenn/open-blocker) | 7 / 2026-11-04 | iOS (App Store) + Android alpha, MIT | Cross-platform NDEF tag spec, UID fallback, two-tap UID stability check, 5 emergency unblocks every 6 months. [src] |
| [cajdata/TapBlok](https://github.com/cajdata/TapBlok) | 54 / 2026-07 | Android, Apache-2.0 | UsageStats polling every 1 s plus a full-screen block activity, MIME NDEF tag, strict mode, boot persistence. [src] |
| [curbox-app/curbox-android](https://github.com/curbox-app/curbox-android) (formerly Digipaws) | 1554 / 2026-11-15 | Android, GPL-3.0 | AccessibilityService blocker with an NFC unlock requirement on the warning screen. Anti-uninstall uses Device Admin plus Accessibility, and Shizuku re-enables the service. [src] |
| [blokapp-web/blok](https://github.com/blokapp-web/blok) | 3 / 2026-08 | Android, GPL-3.0 | Accessibility service on `TYPE_WINDOW_STATE_CHANGED`, `NDEF_DISCOVERED` tags, notification hiding, emergency unlocks. [src] |
| [NathanLenias/lock-app](https://github.com/NathanLenias/lock-app) | 10 / 2026-11-18 | Android, MIT | The Android NFC blocker that the Foqos README recommends. Not read. |
| [QuestPhone/questphone](https://github.com/QuestPhone/questphone) | 135 | Android, GPL-3.0 | Blocks apps until you prove a task is done. Not NFC-based, but a useful bypass-design idea. |
| Smaller iOS clones: [Microck/ancla](https://github.com/Microck/ancla), [RayanStha/NFCLocker](https://github.com/RayanStha/NFCLocker), [jeffreydyao/block](https://github.com/jeffreydyao/block), Foqos Android ports ([Elias02345/Foqos-Android](https://github.com/Elias02345/Foqos-Android)) | 0–7 | — | Not read. |
| [magrinj/expo-screen-time](https://github.com/magrinj/expo-screen-time) | 41 | React Native, MIT | Screen Time API wrapper, useful if you don't want to write Swift. |
| AlarmKit + NFC: [Akeboshiwind/touchstone](https://github.com/Akeboshiwind/touchstone) (MIT), [DanielBordencea/PuckAlarm](https://github.com/DanielBordencea/PuckAlarm), [MaxMaeder/SureAlarm](https://github.com/MaxMaeder/SureAlarm), [Cizzuk/Alare](https://github.com/Cizzuk/Alare) (16★, MIT) | 0–16 / 2026 | iOS 26+ | Alarms that only stop when you scan an NFC tag (see §8). [src for the first three] |

### Foqos internals [src]
- **Blocking.** Uses one named `ManagedSettingsStore("foqosAppRestrictions")`.
  - Sets `shield.applications` and `shield.applicationCategories` (`.specific` or `.all(except:)` for allow-list mode).
  - Sets `shield.webDomains` and `webContent.blockedByFilter`.
  - Strict mode is just `store.application.denyAppRemoval = true`. It also offers `denyAppInstallation`.
  - Ending a session nils every setting and calls `clearAllSettings()`.
- **NFC.** `NFCTagReaderSession(pollingOption: [.iso14443, .iso15693])`.
  - For MiFare and ISO15693 tags it tries `readNDEF`. It accepts a URL only if it is `https://foqos.app/...`. Otherwise it falls back to `tag.identifier` (the UID) as hex.
  - ISO7816 tags use the UID only.
  - Writing uses `NFCNDEFReaderSession` with a well-known URI record.
  - Entitlement: `com.apple.developer.nfc.readersession.formats = [TAG]` plus `applinks:foqos.app`. That makes a tapped `https://foqos.app/profile/<UUID>` tag a universal link that opens the app.
- **Unlock rules.** Stopping a session requires the same tag string as the one that started it, unless the profile lists "physical unblock items", in which case only those tags work.
- **Emergency unblocks.** Defaults to 3 per reset period (4 weeks by default, user-configurable). The counter lives in `@AppStorage`, so a reinstall resets it.
- **Strategies.** Manual, NFC, NFC+manual, NFC+timer, pause-timer, and "soft unblock".
  - In soft unblock, the ShieldAction extension issues a time-limited grant when the shield's primary button is pressed, then schedules a DeviceActivity interval to re-shield.
- **Timers.** Use the DeviceActivity extension (see §8d for the 15-minute workaround).
- **App Intents.** Start, stop, pause and break intents, all `openAppWhenRun = false`, so they work from Shortcuts and Siri. The README documents a Shortcuts NFC personal automation that toggles a profile.
- **Known issues.** Taken from the Foqos issue tracker:
  - The "update" button bypassed an active block ([#119](https://github.com/awaseem/foqos/issues/119)).
  - Users edit the schedule before it starts, and ask for a partner password ([#600](https://github.com/awaseem/foqos/issues/600)).
  - On iOS 27.2 the Screen Time authorization button can be unresponsive ([#630](https://github.com/awaseem/foqos/issues/630)).
  - Website over-blocking ([#463](https://github.com/awaseem/foqos/issues/463)).

### Best Android references [src]
- **TapBlok.**
  - A foreground service (`specialUse`) polls `UsageStatsManager` every 1000 ms and starts a `singleInstance` blocking activity.
  - Needs `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW`.
  - Tags carry a MIME record `application/vnd.com.cj.tapblok`, so an `NDEF_DISCOVERED` filter launches a translucent handler even when the app is closed.
  - Strict mode: a scan on the block screen gives a temporary per-app unlock, and a scan only ends the session if TapBlok is in the foreground.
  - Also: a `BOOT_COMPLETED` restart, and an emergency hold-to-stop button (30 s to 15 min, can be disabled).
- **open-blocker.** Filters `NDEF_DISCOVERED`, `TECH_DISCOVERED` and `TAG_DISCOVERED` so that arbitrary cards are accepted by UID. Its accessibility service listens for window, content and text events, and reads browser URL bars.
- **Curbox.** `AntiUninstallBlocker` bounces the user out of `DeviceAdminAdd` and out of the accessibility settings screens while locked. With Shizuku, it rewrites `enabled_accessibility_services` to self-heal.

---

## 2. iOS mechanics

### Frameworks
- **FamilyControls**
  - `AuthorizationCenter.requestAuthorization(for: .individual)`. For an individual, the system authorizes with Face ID or Touch ID [doc].
  - Apple's doc says that after an individual authorizes, "the system removes any restrictions that prevent the user from bypassing parental controls so the user can delete an authorized app or sign out of iCloud" [doc].
  - In other words, `.individual` is self-control by design. The user can always revoke it in Settings → Screen Time [inf].
  - The strongest available lock is a **Screen Time passcode that another person holds**. open-blocker's docs point users to this [src].
- **FamilyActivityPicker / FamilyActivitySelection**
  - Returns opaque `ApplicationToken`, `ActivityCategoryToken` and `WebDomainToken`. Your app never sees bundle IDs or names [doc].
  - Tokens can be encoded and stored in an App Group [src Foqos].
- **ManagedSettings**
  - "Your app can shield up to **50 application tokens** at once" [doc]. Categories: up to 50 category tokens plus 50 app exceptions. Web domains: also 50 [doc].
  - Above 50, a forum report says the store fails silently and shields nothing ([thread](https://developer.apple.com/forums/thread/733361)) [web].
  - Workarounds: category tokens, or `.all(except:)` allow-list mode.
  - Settings persist in the system after the app is killed. That is why the extensions can work without the app running [inf; consistent with Foqos design].
  - Apple: "The system doesn't guarantee that the settings you specify govern the device's behavior" [doc].
  - Reported bugs: shields stuck as an hourglass after unblocking, unreliable `clearAllSettings()`, and about a 1-minute gap after reboot ([742622](https://developer.apple.com/forums/thread/742622), [744157](https://developer.apple.com/forums/thread/744157), [Apple Community](https://discussions.apple.com/thread/255240135)) [web].
- **ShieldConfiguration extension.** Customizes the shield's title, subtitle, icon and button labels. **ShieldAction extension**: handles primary and secondary button taps and returns `.close`, `.defer` or `.none` [doc].
  - It cannot launch your app directly [inf]. The usual workaround is a local notification that the user taps.
  - Foqos uses the primary button to grant a short temporary pass [src].
- **DeviceActivity monitor extension.** `intervalDidStart`, `intervalDidEnd`, warnings, and `eventDidReachThreshold` [doc]. See §8 for limits.

### Entitlements and accounts
Apple's capability table [doc, [supported-capabilities-ios](https://developer.apple.com/help/account/reference/supported-capabilities-ios)]:
- **Family Controls (development)**: paid Apple Developer Program only, development only. Not available to free accounts or Enterprise.
- **NFC Tag Reading** and **Associated Domains**: paid ADP or Enterprise only.
- A free Personal Team cannot build this app at all. App Groups is the only relevant capability available free.

To distribute: "When you submit your app to TestFlight and the App Store, request permission… If your app includes a Screen Time API app extension, submit the same request for the extension" [doc]. Once approved, the entitlement covers development, Ad Hoc and App Store profiles. Requests are reportedly answered in about 2 weeks to over a month ([forum](https://developer.apple.com/forums/thread/806301)) [web].

**For personal use**, a paid account plus Xcode development signing is enough, and needs no approval [doc + inf].

### Core NFC
- **`NFCNDEFReaderSession`.** Gives you NDEF messages only, with no UID. This is what Broke uses.
- **`NFCTagReaderSession`** [doc].
  - Gives you the UID (`identifier`) and raw access to ISO7816, ISO15693, FeliCa and MIFARE tags.
  - Needs the `formats=TAG` entitlement and `NFCReaderUsageDescription`.
  - ISO7816 needs an AID list (`select-identifiers`). Payment AIDs are not allowed.
  - FeliCa needs explicit system codes, or every session fails ([touchstone design.md](https://github.com/Akeboshiwind/touchstone)) [src].
  - Only one session can run system-wide.
- Both session types need the app **in the foreground** and show the system "Ready to Scan" sheet.
- **Background tag reading** (iPhone XS and later) [doc].
  - The system looks only for the **first URI record**. It needs a universal link (Associated Domains plus an AASA file on your domain) or a built-in scheme. Custom URL schemes are **not** supported.
  - It shows a notification that the user must tap. If the phone is locked, the user must unlock first.
  - It is unavailable when the device has never been unlocked, during a Core NFC session, while Wallet or the camera is in use, or in airplane mode.
- **Shortcuts personal automation, NFC trigger.**
  - Works with any tag, matched by its identifier, and needs no writing ([GoToTags](https://gototags.com/articles/use-nfc-tags-with-iphone-shortcuts-app), [MacRumors](https://forums.macrumors.com/threads/read-nfc-tags.2231461)) [web].
  - Can "Run Immediately" since iOS 17 [web].
  - It can call your App Intent in the background, as Foqos does [src].
  - **Caveat** [inf]: the shortcut is not told which tag fired it, and the user can run the same shortcut by hand. Use it to **start** a session or open the scan screen, never as proof for **stopping**.
- **Identifying a specific tag.** Pair by UID through `NFCTagReaderSession`. Optionally also write an NDEF record holding a random 128-bit ID and/or a universal link. open-blocker does both, and requires **two matching UID reads** at enrollment to reject cards whose UID rotates [src].

---

## 3. Android mechanics (for reference)

- **Detecting the blocked app.**
  - An AccessibilityService on `TYPE_WINDOW_STATE_CHANGED` reacts in under about 100 ms (Blok, Curbox, open-blocker).
  - Alternatively, `UsageStatsManager` polling plus `SYSTEM_ALERT_WINDOW` gives about 1 s latency (TapBlok) [src].
- **Device Owner** (`adb shell dpm set-device-owner`).
  - Lets you call `setPackagesSuspended()`, which is a true OS-level block [doc: [DPC security](https://developer.android.com/work/dpc/security)].
  - Setup fails if the device has accounts, and only one owner is allowed ([OwnDroid](https://github.com/BinTianqi/OwnDroid)) [web].
- **VPN web blocking.** Through `VpnService` [inf].
- **NFC** [doc: [developer.android.com NFC](https://developer.android.com/develop/connectivity/nfc/nfc)].
  - Phones normally scan only when **the screen is unlocked**.
  - Dispatch priority is NDEF > TECH > TAG.
  - An AAR launches your app. Foreground dispatch or reader mode overrides it.
  - **Android 16:** http(s) tags fire `ACTION_VIEW` instead of NDEF. Users get a "Launch via NFC" allow-list.
  - **Android 17:** NFC activities need `DISPATCH_NFC_MESSAGE`, and `TAG_DISCOVERED` is deprecated.
  - Prefer an external-type or MIME record plus an AAR.
  - The UID comes from `Tag.getId()`.
- **Policy.**
  - Google Play requires an Accessibility declaration, a prominent disclosure and affirmative consent. App blockers are not "accessibility tools" ([policy](https://support.google.com/googleplay/android-developer/answer/10964491)) [doc].
  - Sideloaded apps hit "Restricted settings" from Android 13, widened in 15 to cover usage access and overlay. Users must allow them per app [web].
  - The Android 17 Advanced Protection mode blocks non-tool accessibility apps [web].

---

## 4. How commercial products design bypass

- **Brick** [web, [getbrick.com/pages/emergency-unbricks](https://getbrick.com/pages/emergency-unbricks)]
  - Magnetic NFC puck, roughly $59.
  - **5 Emergency Unbricks**. Once used, you reset them through a support form ("within 2 business days").
  - Strict Mode blocks deleting the app during a session.
  - Reviews say turning off Screen Time is detected and counts as an unbrick, and that Strict Mode removes the emergency option.
- **Bloom** [web, competitor-written comparison]: $39 card, 3 emergency exits, 5-minute breaks with limits, optional Strict Mode. Deleting the app unblocks.
- **Unpluq** [web]: you choose a "barrier" before blocked apps open: walk, shake, random tap pattern, charge the phone, or tap the Tag. Includes scheduled tag access.
- **Foqos** [src]: 3 emergency unblocks per N weeks, breaks, pause timer, limited soft opens, and tag-specific stop.
- **Open-source variants** [src]:
  - open-blocker: 5 per 6 months.
  - TapBlok: hold-to-stop for 30 s to 15 min.
  - Touchstone: an escape pledge that grows longer with each use in the last 30 days.
- **Friction research**: one sec's breathing delay ([PNAS 2023, doi 10.1073/pnas.2213114120](https://doi.org/10.1073/pnas.2213114120)). Coverage cites 36% of opens abandoned and about 37–57% fewer attempts [web].

**Takeaways for the design**
- Prefer escalating cost over a hard lockout:
  - a time delay;
  - a typed pledge;
  - a count limit with a long reset period, kept somewhere a reinstall can't reset it (iCloud KVS or Keychain) [inf].
- Lock the profile and schedule editors while a session is running, and for N minutes before a schedule starts (Foqos #600, #119).
- Make Strict mode use `denyAppRemoval`.
- Ask a partner to set the Screen Time passcode.

---

## 5. Common complaints a custom build can fix

- **Brick** [web]:
  - unbricking freezes;
  - scheduling rarely works;
  - login and verification problems;
  - emergency unbricks run out and the reset is slow;
  - a puck kept beside you defeats the purpose.
- **Bloom** [web]:
  - failed first NFC taps on Android;
  - apps sometimes don't re-lock until the app is reopened;
  - deleting the app is a bypass.
- **Unpluq** [web, [App Store reviews](https://appshunter.io/ios/app/1673743726/reviews)]: blocks remained after uninstalling. That matches the platform's stuck-shield bugs.
- **Platform-level** [web]:
  - stuck hourglass shields;
  - the monitor extension silently not firing;
  - the 6 MB memory cap on extensions;
  - the 50-token cap failing silently.
- **What your build can fix**:
  - No account and no cloud dependency.
  - Several tags with roles: the desk tag stops a session; a spare tag sealed in a drawer is the emergency key.
  - Validate the token count (50 or fewer) in the UI.
  - Self-healing: when the app comes to the foreground, re-apply the shield from saved state; on stop, nil every setting.
  - A history of bypass use.

---

## 6. NFC tags and cards

- **NTAG213, 215 and 216** (NFC Forum Type 2).
  - User memory is 144, 504 and 888 bytes. The 144-byte figure for the 213 is verified in the open-blocker spec; the others are [inf].
  - 7-byte fixed UID. Full read and write on iPhone.
  - **This is the ideal choice, and it is what the user has.**
- **MIFARE Classic** (many hotel keys and older transit cards).
  - `NFCTagReaderSession` often doesn't detect it, though `NFCNDEFReaderSession` sometimes does ([forum](https://developer.apple.com/forums/thread/123137)) [web].
  - open-blocker advises "Avoid MIFARE Classic (poor iPhone Core NFC support)" [src].
  - On Android it needs an NXP-chipset phone [inf].
- **Ultralight and DESFire** (transit cards, work badges): readable by UID on iOS [web, src Touchstone].
- **FeliCa** (Suica): needs system-code entitlements [src].
- **Bank cards and phone wallets**: "Many bank cards and phone wallets show a new ID on each tap" [src open-blocker]. Payment AIDs are not selectable [doc]. **Don't use them.** There's no benefit, and they encourage carrying a payment card around for no reason.
- **How to check what a card is**: NXP **TagInfo** or **NFC Tools** show the chip type, UID and NDEF status [inf]. Or test with your own app's two-tap enrollment.
- **Security**:
  - UIDs can be cloned with "magic" cards, and NDEF payloads can be copied by any phone.
  - Treat the tag as friction, not security. open-blocker: "a key for honesty, not security" [src].
  - NTAG 424 DNA (SUN authentication) is the anti-clone option [src open-blocker spec].

---

## 7. Recommended iOS architecture (inference, built from the sources above)

**Targets**
- The app.
- Extensions: DeviceActivityMonitor, ShieldConfiguration, ShieldAction, DeviceActivityReport.
- A Widget extension (needed for an AlarmKit countdown).
- One App Group for shared state.

**Start a session**
- Option 1: open the app, which runs an `NFCTagReaderSession` and checks the UID against the enrolled list.
- Option 2: a Shortcuts NFC automation starts it through a `LiveActivityIntent`.

**Stop a session**
- Require an in-app UID scan of a tag that matches an allowed role.
- Optionally write a universal-link URL to the desk tag. Background reading then opens the app straight to the scan screen with one tap on the notification. This needs a domain with an AASA file.

---

## 8. Additional scope

### (a) AlarmKit (iOS 26+)
- **What it can do** [doc]:
  - Alarms "override both a device's focus and silent mode".
  - Alarms persist through reboots, force-quits and crashes ([AlarmKit FAQ](https://developer.apple.com/forums/thread/797158)).
- **Authorization** [doc]:
  - `AlarmManager.requestAuthorization()` plus `NSAlarmKitUsageDescription`. Without that key, nothing schedules.
  - The docs mention no special entitlement or approval. AlarmKit isn't in the capability list [inf].
  - The number of alarms is limited by the device (`maximumLimitReached`) [doc FAQ].
- **Buttons** [doc]:
  - **Stop**: system-handled.
  - **Secondary** (`AlarmPresentation.Alert`):
    - `.countdown` acts as snooze/"Repeat" and re-alerts after `postAlert`.
    - `.custom` runs `secondaryIntent`. With `openAppWhenRun = true` it opens your app.
  - `stopIntent` and `secondaryIntent` are `LiveActivityIntent`s.
  - If you use a countdown presentation, AlarmKit expects a widget extension, "Otherwise, the system may unexpectedly dismiss alarms".
- **What it can't do**:
  - You cannot remove Stop. Since iOS 26.1 the system draws slide-to-stop ([touchstone](https://github.com/Akeboshiwind/touchstone), citing the AlarmKit swiftinterface) [src].
  - Physical buttons stop alerting alarms [doc FAQ].
  - `stopIntent` isn't called for some dismissals, such as the power button on a locked phone ([DTS](https://developer.apple.com/forums/thread/807710), [852856](https://developer.apple.com/forums/thread/852856)) [web].
- **NFC-to-dismiss pattern** (Alarmy style), as used by Touchstone, PuckAlarm and SureAlarm [src]:
  - The secondary button "Scan tag" (`.custom`) opens the app straight into `NFCTagReaderSession`.
  - `stopIntent` re-arms a new alarm 10–60 s later unless a tag was scanned.
  - **Pre-scheduled "chaser" alarms** every minute for about 15 min cover the cases where `stopIntent` is skipped.
  - A matching scan cancels the pending alarms.
  - Escape hatches: Touchstone uses backup tags plus a pledge that grows with use, and stops re-arming after 1 hour.
  - Deleting the app always defeats it.

### (b) DeviceActivityReport extension
- **Sandbox** [doc]: the report "runs in a sandbox. This sandbox prevents your extension from making network requests or moving sensitive content outside the extension's address space." Your app embeds `DeviceActivityReport(context, filter:)` as a view, but **cannot read the numbers**.
- **Available metrics** [doc]:
  - Per segment (hourly, daily or weekly): `totalActivityDuration`, `firstPickup`, `longestActivity`, `totalPickupsWithoutApplicationActivity`, and categories.
  - Per app: `totalActivityDuration`, `numberOfPickups`, `numberOfNotifications`.
  - Web domain activity.
  - Inside the extension you can show app names and icons [inf].
- **Screenshots**: nothing documented prevents the user from taking a screenshot and sharing it manually [inf].
- **New in iOS 26.4** [doc]: `DeviceActivityData.activityData(filteredBy:using:)` exports usage to the app. It requires:
  - the `com.apple.developer.family-controls.app-and-website-usage` entitlement;
  - `approvedWithDataAccess` status;
  - **customer devices in the EU** (DMA). Development works in any region.

### (c) Scheduled blocking (e.g. 22:00–07:00, then stays blocked until an NFC tap)
- **API** [doc]:
  - `DeviceActivitySchedule(intervalStart:intervalEnd:repeats:warningTime:)`.
  - Errors: `excessiveActivities`, `intervalTooShort`, `intervalTooLong`.
  - "Attempting to monitor too many activities or activities that are too tightly scheduled can cause this method to throw … consider using the `warningTime`."
- **Limits** [web, forum quoting docs]:
  - At most **20 monitored activities** per app and extensions.
  - **Minimum interval 15 min.** Maximum about 1 week.
- **Overnight pattern** [inf]:
  - `intervalDidStart` applies the shield.
  - `intervalDidEnd` does **nothing**, so the block persists until a tag scan clears it in the app.
  - When the app comes to the foreground, reconcile the expected state, because callbacks are reported as unreliable ([736682](https://developer.apple.com/forums/thread/736682), [751597](https://developer.apple.com/forums/thread/751597)).
  - The extension has a **6 MB memory cap** ([735454](https://developer.apple.com/forums/thread/735454)) [web].
  - Foqos had a cross-midnight schedule issue that is now closed. Test 22:00 → 07:00 explicitly.

### (d) 5-minute temporary pass
- **Foqos's method** [src: `SoftUnblockGrantScheduler`, `DeviceActivityCenterUtil.getTimeIntervalStartAndEnd`]:
  - Remove the shield right away, from the app or from the ShieldAction extension.
  - Start a **non-repeating** schedule from **00:00 today** to **now + 5 min**. The total interval is over 15 min, so it isn't rejected as too short.
  - `startMonitoring` may call back at once because the interval is already in progress [doc]. Then `intervalDidEnd` fires at now + 5 min and re-applies the shield.
  - Edge case: Foqos caps the end at 23:59:59, so a pass near midnight is cut short.
- **Belt and braces** [inf]:
  - Also store `passExpiresAt` in the App Group.
  - Re-shield when the app foregrounds.
  - Optionally show a Live Activity countdown.
- **Alternative**: `warningTime` on a 15-minute interval gives a callback 5 min in [doc]. This is less direct.

### (e) Accountability partner (~400 words)
- **What can't be shared** [doc]:
  - The report extension can't send per-app usage off the device.
  - Tokens are opaque. Apple says FamilyActivitySelection tokens identify apps only across devices in the same Family Sharing group.
  - App Store guideline 5.1.2 still requires consent before any personal data is shared [doc].
- **What can be shared freely**, because it is your own app's data:
  - session start and end times, durations, which tag ended the session, NFC versus emergency stop;
  - pass timestamps and counts, breaks;
  - schedule adherence (started on time, or edited or cancelled before start);
  - streaks;
  - edits to the profile or schedule;
  - Screen Time access revoked or the app reinstalled (detectable at next launch) [inf].
- **Coarse usage workaround** [doc + web]:
  - Daily repeating schedule, `DeviceActivityEvent` thresholds of 1h, 2h, 3h and 4h over *all activity* (empty token sets mean all) or over the selected tokens.
  - `eventDidReachThreshold` writes "crossed at T" to the App Group, and the app syncs it.
  - This is the documented purpose of events.
  - Events per activity: no limit documented. The 20-activity cap applies.
  - Reported bugs: thresholds firing early, firing at interval boundaries, or "instantly breached" ([769310](https://developer.apple.com/forums/thread/769310), [726331](https://developer.apple.com/forums/thread/726331)). Use `includesPastActivity` deliberately and label the data "approximate".
- **Backend: CloudKit `CKShare`** fits "partner has an iPhone with the same app".
  - Each participant needs an active iCloud account. Up to 100 participants per share [doc via search].
  - Put the events in a custom zone, share the zone, and the partner reads it from their shared database.
  - Pushes: database subscriptions plus a local notification on the partner's phone. Silent pushes are best-effort, so alerts like "3rd pass today" may be delayed [inf].
  - Firebase or Supabase plus APNs is more reliable and enables a web dashboard, but needs a server and accounts [inf].
- **Existing apps** [web]:
  - Covenant Eyes on iOS: screenshots blurred by AI, and only for Safari content.
  - Accountable2You: VPN-logged URLs, and tells users to pair it with Screen Time.
  - Screen Freedom: pairs friends and notifies the friend when you break your goal.
  - Opal and ScreenZen friend features were not verified.
  - Monitoring-heavy tools (screenshots, URL logs) are reported as invasive. Event summaries plus override alerts match "commitment device" use better.
  - **Recommendation**: share events only, with an in-app "what my partner sees" screen and an optional real-time alert on overrides.

### (f) Getting the app onto the partner's iPhone
- **TestFlight and Ad Hoc** use distribution profiles. These need the **Family Controls (Distribution) approval**, requested per bundle ID **including each extension**. Waits reported: about 2 weeks to over a month ([766923](https://developer.apple.com/forums/thread/766923), [781828](https://developer.apple.com/forums/thread/781828)) [doc + web].
- **Development build on the partner's device** [web + inf]:
  - Register their UDID (100 iPhones per membership year; disabling a device doesn't free its slot).
  - Regenerate the profile, then install via Xcode or a development-signed IPA. Developer Mode must be on (iOS 16+) [inf].
  - It stops launching when the profile expires, roughly 1 year [web].
- **Better: a separate companion app (own bundle ID) with no FamilyControls** [inf]:
  - It only reads the CloudKit share.
  - Both apps can use one iCloud container from the same team.
  - It goes through TestFlight without approval: as an **internal tester** if the partner is added as an App Store Connect user on your team, or as an **external tester** after Beta App Review (about 24–48 h).
  - TestFlight builds expire after **90 days** [web].
  - A single app that contains the entitlement can't avoid the approval for distribution, even if the partner never uses Screen Time features.

---

## Key sources
- Apple docs: [ShieldSettings.applications (50 tokens)](https://developer.apple.com/documentation/managedsettings/shieldsettings/applications-swift.property), [requestAuthorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)), [Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls), [Background tag reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading), [NFCTagReaderSession](https://developer.apple.com/documentation/corenfc/nfctagreadersession), [DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport), [DeviceActivityData.activityData](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata(filteredby:using:)), [startMonitoring](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:)), [AlarmKit sample](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)
- Android: [NFC basics](https://developer.android.com/develop/connectivity/nfc/nfc), [Play Accessibility policy](https://support.google.com/googleplay/android-developer/answer/10964491)
- Repos: listed in §1 and §8a.
