# OnCue

A native macOS app (Swift / SwiftUI, macOS 14+, Apple Silicon) for scripting the camera shots of a live show and running that script on the switcher: concerts, TV-style music shows, esports and corporate shows, from 5 to 70+ cameras.

The product requirements are in the OnCue PRD. Phase 0 (this state) is the engineering foundation only: the app opens, creates, saves and reopens an empty show. There is no show engine or production interface yet.

## Project structure

```
oncue/
  project.yml                   XcodeGen spec: the source of truth for the Xcode project
  OnCue.xcodeproj               generated from project.yml (committed; CI keeps it in sync)
  OnCue/                        the Mac app target (thin shell)
    App/
      OnCueApp.swift            @main, DocumentGroup, Settings scene, MachineProfileModel
      ShowDocument.swift        FileDocument wrapper around OnCueCore's ShowCoding
      ShowWindow.swift          placeholder show window and This Mac settings (Phase 0 only)
      SmokeTest.swift           `--smoke-test <folder>` launch check used by CI
    Resources/
      Info.plist                file type (.oncue), local network / microphone / ATS keys
      OnCue.entitlements        hardened-runtime audio input (LTC)
  Packages/OnCueCore/           Swift package with all non-UI code, independently testable
    Sources/OnCueCore/
      Model/Model.swift         show model: cameras, switchers, outputs, items, sections, tracks, cues...
      Persistence/
        ShowCoding.swift        encode/decode, schema version check, migration, file IO, errors
        TolerantDecoding.swift  backward-compatible decoding (defaults for missing fields)
        MachineProfile.swift    per-Mac settings and their store
      Devices/                  switcher protocol + simulator, ATEM, Companion, OSC, PTZ, MIDI
    Tests/OnCueCoreTests/       model, persistence and machine-profile tests
      Fixtures/show-v0-golden.json   golden file in the original (schema 0) show format
  .github/workflows/build.yml   CI: generate project, run tests, build app, launch smoke test
```

## Architecture overview

- **OnCueCore** holds everything that does not need the UI: the show model, persistence and the device integrations. It has no external dependencies and is tested with `swift test`.
- **The app target** is a thin SwiftUI shell. It owns windows and documents and talks to OnCueCore only through its public API (`Show`, `ShowCoding`, `ShowFileIO`, `ShowFileError`, `MachineProfile`, `MachineProfileStore`). Most model and device types are still internal to the package; they become public when the engine and UI phases need them.
- **Show files** (`.oncue`, JSON) are portable between Macs. Each file carries `schemaVersion`. Older files are migrated in memory on open, missing fields get defaults, and unknown enum values from newer builds fall back safely. Files from a newer OnCue are refused with a clear message, and are never modified.
- **Machine profile** (`~/Library/Application Support/OnCue/MachineProfile.json`) holds this Mac's hardware settings: MIDI ports, LTC input, crew network interface, Companion address, backup role, log folder. Opening a show never changes it, and changing it never changes a show. An unreadable profile is kept as `MachineProfile.unreadable-<date>.json` and replaced with defaults.
- **Documents** use SwiftUI `DocumentGroup`, so autosave and macOS version history (File > Revert To) come from the system.

## Development environment

- macOS 14 or later on Apple Silicon.
- Xcode 16 or later.
- XcodeGen: `brew install xcodegen`, needed only when `project.yml` changes.

## Generate the project

```
xcodegen generate
```

Run this after editing `project.yml` or adding or removing files, and commit the result. CI regenerates the project on every push. If the committed project is out of date, CI commits the regenerated one to `main` after a successful build.

## Build and run

Open `OnCue.xcodeproj`, choose the **OnCue** scheme and press Run. From the command line:

```
xcodebuild -project OnCue.xcodeproj -scheme OnCue -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/OnCue.app
```

The app is ad-hoc signed by default, so it builds without an Apple developer team. For distribution, set your team and a "Developer ID Application" certificate (DMG packaging is a later phase).

## Tests

```
swift test --package-path Packages/OnCueCore
```

Launch smoke test, which runs the real app through create, save, close and reopen:

```
build/DerivedData/Build/Products/Debug/OnCue.app/Contents/MacOS/OnCue --smoke-test /tmp/oncue-smoke
```

CI (`.github/workflows/build.yml`) runs all of the above on a macOS runner for every push. It also publishes full logs to the `ci-results` branch: `LATEST.md` holds the latest summary, and `runs/<commit>/` holds the full logs.

## Temporary technical compromises

- **Swift 5 language mode** with minimal concurrency checking. The device classes use dispatch queues and non-Sendable closures. Moving to Swift 6 depends on the concurrency model decision (audit item C10).
- **Most OnCueCore types are internal.** Only what the app shell needs is public.
- **Schema 0 files lose their per-Mac settings on open**: MIDI ports, LTC device, crew interface and the like. This is deliberate, so a show from another Mac cannot overwrite this Mac's hardware setup. Re-enter them in Settings.
- **Machine-profile enums are stored as text** (`backupRole`, `companionVersion`) to keep the profile independent of the show model's enums.
- **The device integrations (ATEM, Companion, OSC, PTZ, MIDI) are unchanged** from the initial commit, apart from the compile fix in `SwitcherDevice.swift`. They are still untested on hardware, and audit items C7–C12 are not started.
- **Monitor configurations stay in the show file**, including their screen names, which are per-Mac. To revisit when operator monitors are built.
- **The Phase 0 window is a placeholder**, not the production interface.
