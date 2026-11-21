# Tawfeeq

An iPhone focus blocker that works like Brick. Tap the NFC sticker on your desk to start a focus session that blocks your distracting apps. Tap it again to end the session.

- **Phases 1–2 (code written, not yet built on a Mac):**
  - Screen Time blocking, tag enrollment, tap to toggle
  - custom block screen, self-healing shields
  - 5-minute passes, with a button on the block screen
  - Shortcuts NFC trigger
- **Next:** night lock with tag-to-dismiss alarms, stats page, accountability partner

| Doc | |
|---|---|
| [docs/setup.md](docs/setup.md) | Build and run on your iPhone, plus a test checklist |
| [docs/design.md](docs/design.md) | App design and build plan |
| [docs/research.md](docs/research.md) | Research on existing open-source blockers, iOS Screen Time, Core NFC, AlarmKit and tag types |

## Layout

```
project.yml                 XcodeGen spec (run `xcodegen generate`)
App/                        SwiftUI app: AppModel, NFC TagScanner, views
Shared/                     Code shared with extensions: models, store, Blocker, EventLog
Extensions/ShieldConfiguration/   Custom "you're focusing" block screen (+ pass button)
Extensions/ShieldAction/          Handles the block screen's "5-minute pass" button
Extensions/DeviceActivityMonitor/ Re-blocks when a pass ends
web/.well-known/            apple-app-site-association for tawfeeq.uk tag links
```
