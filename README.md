# Tawfeeq

An iPhone focus blocker that works like Brick. Tap the NFC sticker on your desk to start a focus session that blocks your distracting apps. Tap it again to end the session.

- **Phase 1 (code written, not yet built on a Mac):** Screen Time blocking, tag enrollment, tap to toggle, custom block screen, self-healing shields
- **Next:** 5-minute passes, night lock with tag-to-dismiss alarms, stats, accountability partner

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
Extensions/ShieldConfiguration/   Custom "you're focusing" block screen
web/.well-known/            apple-app-site-association for tawfeeq.uk tag links
```
