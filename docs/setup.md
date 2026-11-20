# Setting up and running Tawfeeq (phase 1)

Phase 1 gives you: Screen Time permission → pick apps to block (+ allowlist) → register your desk tag → **tap to start blocking, tap again to stop**, with a custom block screen.

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
