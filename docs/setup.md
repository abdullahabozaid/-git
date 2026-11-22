# Setting up and running Tawfeeq (phases 1–3)

What's included:
- **Phase 1**:
  - Screen Time permission
  - pick apps to block, plus an allowlist
  - register your desk tag
  - **tap to start blocking, tap again to stop**
  - a custom block screen
- **Phase 2**:
  - **5-minute passes**, from the block screen or the app; apps re-block automatically
  - a pass counter with back-to-back warnings
  - a Shortcuts NFC automation, so tapping the desk sticker starts a session
- **Phase 3**:
  - **night lock**: apps lock automatically at bedtime and stay locked until you tap the desk tag
  - **wake alarm**: rings through Silent mode and only fully stops when you tap the desk tag (the morning check-in)

Every push is compiled automatically on a GitHub-hosted Mac (`.github/workflows/ios-build.yml`). A green tick on the branch means the code builds.

## You need

- A Mac with **Xcode 26** or later
- An iPhone on **iOS 26** or later, with **Developer Mode** on (Settings → Privacy & Security → Developer Mode)
- Your **paid** Apple Developer account, signed in to Xcode (Xcode → Settings → Accounts)
- [Homebrew](https://brew.sh)

The iOS Simulator can't do Screen Time blocking or NFC, so test on the real phone.

## 1. Generate the Xcode project

```sh
brew install xcodegen
git clone https://github.com/abdullahabozaid/-git.git tawfeeq
cd tawfeeq
git checkout claude/nfc-focus-blocker-research-clrflu
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
```

Edit `Configs/Local.xcconfig` and put in your Team ID. You'll find it at developer.apple.com → Account → Membership details.

```sh
xcodegen generate
open Tawfeeq.xcodeproj
```

Run `xcodegen generate` again whenever `project.yml` changes or files are added.

## 2. Build to your phone

1. Plug in your iPhone and select it as the run destination.
2. Press **Run**.
   - Automatic signing registers the App ID `uk.tawfeeq.app`, the App Group `group.uk.tawfeeq`, and these capabilities: Family Controls (Development), NFC Tag Reading and Associated Domains.
   - If Xcode reports a signing error about a capability, open **Signing & Capabilities** on that target and click **Try Again**.
3. On first launch, tap **Allow Screen Time access** and confirm with Face ID.

## 3. Try it

1. **Block list**: choose the apps to block, and optionally your always-allowed apps.
2. **Tags** → **+**:
   - Name it "Desk", set the role to **Desk tag**, then tap **Scan**.
   - Hold the top back edge of the iPhone on the sticker. Tap twice: the first tap reads the tag, the second confirms it and writes the link.
3. **Focus** → **Tap desk tag to start** → scan the sticker. Blocked apps now show the Tawfeeq screen.
4. Tap **Tap desk tag to end** → scan the sticker. The apps are unblocked.

### Phase 1 test checklist

- [ ] Blocked apps show the Tawfeeq shield and allowed apps open normally.
- [ ] Scanning an **unregistered** card shows "That tag isn't registered".
- [ ] The Block list and Tags screens are locked during a session.
- [ ] With "Prevent deleting apps" on, you can't delete apps during a session.
- [ ] Force-quit Tawfeeq during a session: apps stay blocked.
- [ ] Reboot the phone during a session: apps stay blocked (there may be a short gap after boot), and opening Tawfeeq repairs it.
- [ ] Register a **spare** tag: it can also end a session.

### Phase 2 test checklist

- [ ] During a session, open a blocked app and tap **Take a 5-minute pass** on the block screen. The app opens.
- [ ] About 5 minutes later the app is blocked again, *without* opening Tawfeeq.
- [ ] Take a pass from the Focus tab. The circle turns orange with a countdown. **Re-block now** blocks again immediately.
- [ ] Take two passes within 2 minutes of each other. The Focus tab shows "1 back-to-back" in orange.
- [ ] End the session with the desk tag while a pass is running. Everything unblocks and stays unblocked.
- [ ] Take a pass and leave Tawfeeq closed for 10+ minutes. Apps are blocked again. If they aren't, opening Tawfeeq fixes it; please tell me, because that means the background re-block didn't fire.

### Phase 3 test checklist

- [ ] **Routine → Test alarm.** Lock the phone. The alarm rings and shows **Scan desk tag**.
- [ ] Set the wake alarm for 2–3 minutes from now and save. When it rings, press **Stop**. It rings again about 30 s later, and backup alarms keep coming every minute.
- [ ] Press **Scan desk tag** on the alarm, or open Tawfeeq, and scan the desk tag. Everything goes quiet and nothing rings again that morning.
- [ ] Night lock: set it to start in 20 minutes, with the wake time an hour later. At the start time, apps lock. The Focus tab shows "night lock".
- [ ] After the wake time passes, apps are **still** locked until you scan the desk tag.
- [ ] Scanning the desk tag in the morning checks in and ends the night lock in one tap.



1. Open **Shortcuts** → **Automation** → **+** → **NFC**.
2. Tap **Scan**, hold the phone on your desk sticker, and name it "Desk".
3. Choose **Run Immediately**.
4. Add the action **Desk Tag Tapped** (from Tawfeeq).

Now a single tap on the desk sticker does one of two things:
- **Not focusing**: Tawfeeq opens and the session starts.
- **Focusing**: Tawfeeq opens on the scan sheet. Tap again to end. Ending always needs the real scan, because a shortcut can be run by hand.

## 4. Optional: tap the sticker without opening the app first (tawfeeq.uk)

Every tag gets `https://tawfeeq.uk/t/<secret>` written to it. With the domain set up, tapping the sticker while your iPhone is unlocked shows a notification, and tapping that opens Tawfeeq:

- **Not focusing**: the session starts straight away.
- **Focusing**: the scan sheet opens. Ending a session always needs a real scan, because a link can be opened without the tag.

To enable this:

1. Replace `TEAMID` in [`web/.well-known/apple-app-site-association`](../web/.well-known/apple-app-site-association) with your Team ID.
2. Host it at `https://tawfeeq.uk/.well-known/apple-app-site-association`:
   - over HTTPS, with **no redirects**;
   - with `Content-Type: application/json`;
   - with no `.json` extension.
3. Check it with `curl -i https://tawfeeq.uk/.well-known/apple-app-site-association`.
4. Apple's CDN caches this file. While testing, you can temporarily change the entitlement to `applinks:tawfeeq.uk?mode=developer` and turn on **Settings → Developer → Associated Domains Development**.

Where is tawfeeq.uk hosted (Vercel, Netlify, Cloudflare, cPanel…)? Tell me and I'll give you the exact steps for that host.

## If something goes wrong

- **Apps stay blocked after ending**: open Tawfeeq. It re-checks and clears stale blocks every time it comes to the foreground.
- **Desk tag lost or broken during a session**:
  - use your spare tag;
  - from phase 2 on, the 5-minute pass;
  - last resort: Settings → Screen Time → Apps with Screen Time Access → turn off Tawfeeq. This is logged.
