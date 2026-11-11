# OnCue Phase 0: Implementation report

Phase 0 is complete. The app builds, launches, creates, saves, closes and reopens a show. All 34 OnCueCore tests pass. All of this comes from CI on a macOS runner, not from reading the code.

Scope was audit items C1–C6. C7–C12, the show engine, timing, LTC, the production UI, the crew server, backup, analytics and exports were not touched.

## Acceptance criteria

| # | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| 1 | Xcode project exists and is committed | Met | `OnCue.xcodeproj`, generated from `project.yml` by CI and committed in `53c3ea7`. The next run reports "Committed OnCue.xcodeproj matches project.yml." |
| 2 | App builds | Met | `** BUILD SUCCEEDED **` (Xcode 16.4, Swift 6.1.2 toolchain in Swift 5 mode, macOS 15.8.2 runner, arm64) |
| 3 | App launches | Met on CI runner | Smoke test: `app launched (pid …)` |
| 4 | Show created, saved, closed, reopened | Met on CI runner, through `NSDocumentController` (the system DocumentGroup uses) | Smoke test log below |
| 5 | Schema migration tests pass | Met | 17 `PersistenceTests` passed |
| 6 | Machine profile tests pass | Met | 8 `MachineProfileTests` passed |
| 7 | OnCueCore tests pass | Met | `Executed 34 tests, with 0 failures` |
| 8 | GitHub Actions build and test succeed | Met | Run [43086711709](https://github.com/nishan6/oncue/actions/runs/43086711709), commit `accb2b0`, job conclusion `success` |
| 9 | Integrations not rewritten unnecessarily | Met | ATEM, Companion, OSC, PTZ and MIDI files are pure moves (0 changed lines). `SwitcherDevice.swift`: 2 lines changed (the C3 compile fix) |

## Build evidence

From `ci-results/runs/accb2b0/` (full logs on the `ci-results` branch):

```
Committed OnCue.xcodeproj matches project.yml.
Executed 34 tests, with 0 failures (0 unexpected) in 0.031 (0.033) seconds
** BUILD SUCCEEDED **
[smoke] app launched
[smoke] machine profile created at /Users/runner/work/_temp/smoke/profile/MachineProfile.json
[smoke] new show opened (type com.nishanpani.oncue.show, windows: 1)
[smoke] saved to /Users/runner/work/_temp/smoke/smoke.oncue
[smoke] window closed
[smoke] saved file verified: format 1, 1 item(s), 4 camera(s)
[smoke] reopened smoke.oncue (windows: 1)
[smoke] PASS: create, save, close and reopen all succeeded
```

Compiler warnings: none from OnCue code. The one warning in the app build log is Xcode's App Intents metadata tool, which notes the app does not use App Intents.

CI history:

| Commit | Result | Notes |
| --- | --- | --- |
| `6a114b3` | Job failed; build, tests and smoke test all passed | The "commit generated project" step could not push because `main` had moved on (`fb11bc0` was pushed during the run). Fixed in `accb2b0`. |
| `fb11bc0` | Success | Committed the generated project (`53c3ea7`) |
| `accb2b0` | Success | Project confirmed in sync; all checks green |

## Tests executed

| Suite | Tests | Covers |
| --- | --- | --- |
| PersistenceTests | 17 | New show round trip; save, reopen on disk; every field survives a round trip; golden schema-0 file opens and re-saves; missing fields get defaults; unknown enum values fall back safely; a newer schema is refused with a clear message and the file is untouched; empty, non-JSON, wrong-shape and wrong-type files give understandable errors; corrupt files on disk are not modified; missing file |
| MachineProfileTests | 8 | Missing profile created; changes persist across launches; opening a show from another Mac does not touch the profile; show files carry no per-Mac settings; profile changes do not change shows; corrupt profile kept as a backup with defaults used; newer-format profile not overwritten; missing profile fields get defaults |
| ModelTests | 9 | Starter show; camera labels and renaming; bars, seconds and order positions; sections; tempo conversion; timecode helpers; a shots track per output |

## Files created

- `project.yml`, the XcodeGen spec
- `OnCue.xcodeproj/`, generated and committed by CI
- `OnCue/App/OnCueApp.swift`, `ShowWindow.swift`, `SmokeTest.swift`
- `OnCue/Resources/Info.plist`, `OnCue.entitlements`
- `Packages/OnCueCore/Package.swift`
- `Packages/OnCueCore/Sources/OnCueCore/Persistence/ShowCoding.swift`, `TolerantDecoding.swift`, `MachineProfile.swift`
- `Packages/OnCueCore/Tests/OnCueCoreTests/PersistenceTests.swift`, `MachineProfileTests.swift`, `ModelTests.swift`
- `Packages/OnCueCore/Tests/OnCueCoreTests/Fixtures/show-v0-golden.json`
- `.github/workflows/build.yml`
- `docs/PHASE0_REPORT.md` (this file)

## Files modified

| File | Change |
| --- | --- |
| `Model/Model.swift` (moved into the package) | `Section` renamed `SongSection` (C4). `Show` made public, with `schemaVersion`, `cameraCount` and `itemCount`. Per-Mac fields removed from `ShowSettings` (C6). |
| `Devices/SwitcherDevice.swift` (moved) | Overlapping `swap` replaced with a tuple assignment, 2 lines (C3) |
| `ShowDocument.swift` (moved to `OnCue/App/`) | Encoding and decoding now delegate to OnCueCore's `ShowCoding` |
| `README.md` | Structure, environment, generation, build, test, architecture, compromises |
| `.gitignore` | CI log folder |
| `ATEMSwitcher.swift`, `CompanionClient.swift`, `OSC.swift`, `PTZService.swift`, `MIDIManager.swift` | Moved into the package only; no content changes |

## Architectural changes

- **App and core are split.** A thin SwiftUI app target sits on the `OnCueCore` Swift package. The package contains the model, persistence, machine profile and devices, and has no external dependencies.
- **Versioned show files.** `schemaVersion` is now 1, and files without it are read as schema 0 and migrated in memory. Decoding is tolerant: missing fields get defaults, and unknown enum values fall back safely. A newer schema is refused. Reading never writes, and saving is atomic.
- **Machine profile** at `~/Library/Application Support/OnCue/MachineProfile.json`, separate from shows. An unreadable or newer profile is moved aside rather than overwritten.
- **App configuration:** macOS 14, arm64, Swift 5 mode with minimal concurrency checking, default actor isolation set to nonisolated, hardened runtime with the audio-input entitlement, no sandbox, ad-hoc signing. Info.plist declares the `.oncue` file type and the local-network, microphone and App Transport Security keys.
- **CI** builds, tests and smoke-tests every push, and publishes logs to the `ci-results` branch.

## Known limitations

- **Launch, save and reopen have only been proven on a CI runner.** They have not run on Nishan's Mac, and the smoke test drives the document system from code, not through menu clicks. Recommended: one manual check (File > New, Save, close, File > Open).
- **Nothing has touched real hardware.** The device integrations are unchanged and untested against equipment.
- **Schema 0 files drop their per-Mac settings** on open, by design. They have to be re-entered in Settings.
- **Monitor configurations still live in the show file**, including their screen names, which are per-Mac.
- **The app is ad-hoc signed only.** Developer ID signing, notarization and the DMG are not set up.
- **The Phase 0 window and Settings form are placeholders.**
- **Swift 5 language mode**: the Swift 6 move waits on the concurrency decision.

## Remaining work (needs separate approval)

1. Decide the concurrency model (audit, before C10).
2. Device hardening, C7–C12: ATEM delivery tracking and resend, codec split, one connection per ATEM, device events and capabilities, simulator failure injection, MIDI by unique ID. Each with protocol and transport tests.
3. Timing layer: clocks, MIDI tempo follower, LTC decoder.
4. Show engine, then production UI, crew server, backup, stats and exports.
5. Developer ID signing, notarization and DMG packaging.
6. Hardware validation sessions.
