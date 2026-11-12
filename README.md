# OnCue

A native macOS app (Swift / SwiftUI, macOS 14+, Apple Silicon) for scripting the camera shots of a live show and running that script on the switcher: concerts, TV-style music shows, esports and corporate shows, from 5 to 70+ cameras.

The product requirements are in the OnCue PRD.

**Current state (Phase 1):** a working show scripting workspace. Create a production, build the running order of songs and segments, add sections, configure cameras, and script shots with timing, transitions and notes. Everything saves to the show file, and each show reopens where you left it. There is no live show engine yet: OnCue does not drive switchers, follow MIDI or LTC, or serve the crew page.

## Using the workspace

- **Running order** (left): songs and segments, each with a strip of its shots in camera colours. Drag to reorder; right-click to rename, duplicate or delete.
- **Header**: title, timing (bars and beats, seconds, or NEXT order), tempo, beats per bar, planned length and hard out, and the view switch: timeline, timeline and list, or list.
- **Timeline**: a shared ruler with the Sections, Vision (the main output's shots), Lyrics, Notes and FX tracks. Each camera has its own colour; a shot block shows the camera number, name, description, note and length, and a corner ramp when it mixes in. Double-click a track to add; drag a block to move it (snapped to the beat, half second or step); drag a shot's right edge to trim; double-click a block to edit it in place. Tracks can be hidden (their cues are kept) or locked. Left and right arrows step through the shots.
- **Shot list**: shots grouped by section. Drag to reorder within a section: the time slots stay and the shots move between them.
- **Camera keys** (bottom): red is the selected shot's camera, green is the next shot's camera. Click a key to set the camera on the selected shots; Option-click adds a new shot.
- **Inspector** (right): the selected shot or shots, lyric, note or FX cue, or the song or segment.
- **Cameras** (Production > Cameras): colour, number, name, the operator for this show, and the switcher input.

FX cues are part of the script only; they run on the switcher once the show engine is built.

| Action | Keys |
| --- | --- |
| New song / new segment | ⌥⌘N / ⌥⇧⌘N |
| New section | ⌥⌘E |
| New shot | Return (shot list selected) or ⌘Return |
| Set camera of selected shot | Type its number (e.g. 1, 2 for camera 12) |
| Duplicate shot | ⌘D |
| Move shot up / down | ⌥⌘↑ / ⌥⌘↓ |
| Switch cut or mix | ⌥⌘T |
| Delete shot or cue | Delete or ⌘Delete |
| Previous / next song | ⌘[ / ⌘] |
| Cameras / inspector | ⌥⌘C / ⌥⌘I |
| Timeline / timeline and list / list | ⌘1 / ⌘2 / ⌘3 |
| Zoom in / out / actual size | ⌘= / ⌘- / ⌘0 |
| Previous / next shot (timeline) | ← / → |
| Undo / redo | ⌘Z / ⇧⌘Z |

## Project structure

```
oncue/
  project.yml                   XcodeGen spec: the source of truth for the Xcode project
  OnCue.xcodeproj               generated from project.yml (committed; CI keeps it in sync)
  OnCue/                        the Mac app target (thin shell)
    App/
      OnCueApp.swift            @main, DocumentGroup, menus, Settings scene, MachineProfileModel
      ShowDocument.swift        FileDocument wrapper around OnCueCore's ShowCoding
      SmokeTest.swift           `--smoke-test <folder>` launch check used by CI
      ScreenshotRun.swift       `--screenshots <folder>` window images used by CI
    Workspace/                  the scripting workspace (views + WorkspaceModel)
    UI/                         gallery theme and shared components, This Mac settings
    Resources/
      Info.plist                file type (.oncue), local network / microphone / ATS keys
      OnCue.entitlements        hardened-runtime audio input (LTC)
  Packages/OnCueCore/           Swift package with all non-UI code, independently testable
    Sources/OnCueCore/
      Model/Model.swift         show model: cameras, switchers, outputs, items, sections, tracks, cues...
      Editing/
        ShowEditing.swift       every edit the workspace makes (running order, sections, cameras, shots)
        TimelineEditing.swift   timeline spans, snapping, lyrics/notes/FX cues
        SampleShow.swift        sample production used by tests and CI screenshots
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
- **The app target** is SwiftUI. Views never change the show directly. Every edit goes through `WorkspaceModel.edit`, which applies an OnCueCore editing operation (`ShowEditing.swift`) to the document as one undoable step. Device types in OnCueCore stay internal until the engine phase.
- **Workspace state** (selected song and shots, inspector) is kept per show on this Mac, keyed by the show's id, and restored when the show reopens. It never marks the show as edited.
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
- **Device types in OnCueCore are internal.** The model and editing API are public.
- **Schema 0 files lose their per-Mac settings on open**: MIDI ports, LTC device, crew interface and the like. This is deliberate, so a show from another Mac cannot overwrite this Mac's hardware setup. Re-enter them in Settings.
- **Machine-profile enums are stored as text** (`backupRole`, `companionVersion`) to keep the profile independent of the show model's enums.
- **The device integrations (ATEM, Companion, OSC, PTZ, MIDI) are unchanged** from the initial commit, apart from the compile fix in `SwitcherDevice.swift`. They are still untested on hardware, and audit items C7–C12 are not started.
- **Monitor configurations stay in the show file**, including their screen names, which are per-Mac. To revisit when operator monitors are built.
