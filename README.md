# OnCue

A native macOS app (Swift / SwiftUI, macOS 14+, Apple Silicon) for scripting the camera shots of a live show and running that script on the switcher: concerts, TV-style music shows, esports and corporate shows, from 5 to 70+ cameras.

The product requirements are in the OnCue PRD.

**Current state:** every V1 item in the PRD is built and covered by tests, but **none of it has been tested against real hardware yet**: ATEM, Companion, MIDI clock, LTC, PTZ, OSC and a second Mac have only been exercised against stand-ins (a simulated switcher, a stand-in ATEM on localhost, generated LTC and MIDI clock, local TCP and HTTP servers).

## Using the workspace

- **Running order** (left): songs and segments, each with a strip of its shots in camera colours. Drag to reorder; right-click to rename, duplicate or delete.
- **Header**: title, timing (bars and beats, seconds, or NEXT order), tempo, beats per bar, planned length and hard out, and the view switch: timeline, timeline and list, or list.
- **Timeline**: a shared ruler with the Sections, Vision (the main output's shots), Lyrics, Notes and FX tracks. Each camera has its own colour; a shot block shows the camera number, name, description, note and length, and a corner ramp when it mixes in. Double-click a track to add; drag a block to move it (snapped to the beat, half second or step); drag a shot's right edge to trim; double-click a block to edit it in place. Tracks can be hidden (their cues are kept) or locked. Left and right arrows step through the shots.
- **Shot list**: shots grouped by section. Drag to reorder within a section: the time slots stay and the shots move between them.
- **Camera keys** (bottom): red is the selected shot's camera, green is the next shot's camera. Click a key to set the camera on the selected shots; Option-click adds a new shot.
- **Inspector** (right): the selected shot or shots, lyric, note or FX cue, or the song or segment.
- **Cameras** (Production > Cameras): colour, number, name, the operator for this show, and the switcher input.

- **Live Mode** (⌘L or the Live button): the script as a gallery display. NOW (PGM) and NEXT (PVW) with camera, operator, description and note; the shots after next; the camera grid with labelled tally; section jumps and song changes. NEXT (Space or →) takes the next shot and back (←) steps back; the clock shows how long the shot has been on air and, where the script has timing, how long until the next is planned. Leaving Live Mode (⌘L or Exit) selects the shot that was on air; Esc is panic, not exit.

### Show engine (Live Mode)

- **Switcher mode** (in Live Mode): **Display** shows the calls only; **Preview** puts the next shot's camera on preview and you cut; **Cut** cuts (or mixes) on the script and preloads the next shot. Live Mode always starts in Display, so nothing is sent until you choose.
- **Manual cut pauses automation**: in Cut mode, if the program changes to something OnCue did not send, automation pauses (amber banner) and OnCue keeps following the script without sending anything. **Resume** (R) puts the next shot on preview and carries on.
- **Timing per song or segment** ("Live follows" in the header): Section taps (T; OnCue runs at the tempo between taps), NEXT, MIDI clock (Ableton Start starts the song; Song Position is followed), LTC (an audio input; "LTC start" is the song's first frame, or empty for the first frame after GO), or OnCue's own clock from GO (Return).
- **Switchers** (Production > Show Setup…, ⌥⌘S): ATEM (IP address and M/E, UDP 9910), Companion, or the built-in simulator. Cameras reach the switcher on the inputs set under Cameras; cameras without an input are skipped.
- **This Mac** (Settings): MIDI clock source, LTC audio input and channel.

- **Several switchers and outputs** (Show Setup, ⌥⌘S): a main switcher, sub-switchers feeding it, separate outputs with their own shots track, aux buses, outputs mirroring the main one, and per-input Companion buttons for switchers OnCue can't talk to directly.
- **Cues**: FX (macros, DSK, keyers, fade to black), control (load next song, wait), OSC to Resolume, Disguise, CasparCG or a lighting desk, and PTZ presets (Panasonic, VISCA, ATEM macros or Companion).
- **Controls**: keyboard, Akai APC40 mkII (with pad tally), any MIDI controller by MIDI learn, Stream Deck through Companion (OSC in, custom variables out).
- **Free mode** (F), **loop a section** (L), **camera down** (move a dead camera's coming shots to another), **panic** (Esc: everything drops to display only).
- **Rundown timing**: songs and segments with a planned length or a hard out show elapsed, left or over, the hard out countdown, the show over or under, and whether the next hard out will be made.
- **Operator monitors** (Show Setup › Monitors): gallery, camera tally, shotlist and countdown views, full screen on the chosen displays while in Live Mode.
- **Backup Mac** (Settings › Backup): the main Mac serves its position and the show on TCP 9123; the backup follows without sending anything and can take over.
- **Switch log and report**: every cut and call is logged (with LTC when present) in `Documents/OnCue Logs`; leaving Live Mode shows Director Stats and scripted vs actual.

### Around the show

- **Crew page** (toolbar phone button): a page phones open on the local network (QR code). Operators pick their camera and see their tally, a countdown to their next shot and what's coming; outside Live Mode it's a script review where they can comment on shots.
- **Pre-show check** (⌥⌘K): switchers answer and have every camera's input, every shot has a camera, timing and controller devices are connected, PTZ heads answer, the log folder is writable. Picture on each input isn't reported by switchers, so it isn't claimed.
- **Camera plot** (⌥⌘P): cameras placed and turned on an imported venue plan or a grid, with position names and lenses; export as PNG.
- **Exports** (⇧⌘E): camera script PDF, call sheets per camera PDF, script CSV, shot markers EDL for Resolve. From a show report: program cuts as an EDL for conforming ISO recordings, and the switch log as CSV.
- **Draft script** from a switch log or an EDL: new songs next to the originals with the cuts as shots.
- **Media under the timeline**: song audio or a PGM recording with its waveform; scrub, play (⌥Space), set where the song starts, float the video.
- **Tour**: name tonight; nights compared show-wide and per song from their logs, with who was on each camera.
- **Versions** inside the show file (named, and one each time Live Mode starts), plus copies to a backup folder (Settings).


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
| Live Mode on / off | ⌘L |
| Live: NEXT / back | Space or → / ← |
| Live: GO / stop, tap section, resume | Return, T, R |
| Show Setup | ⌥⌘S |
| Pre-show check / camera plot / export | ⌥⌘K / ⌥⌘P / ⇧⌘E |
| Play or pause media | ⌥Space |
| Live: free mode, loop, cut, auto, tap tempo | F, L, C, A, B |
| Live: camera to preview | its number |
| Live: panic (display only) | Esc |
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
    UI/                         design system (tokens, type scale, components), This Mac settings
    Resources/
      Info.plist                file type (.oncue), local network / microphone / ATS keys
      OnCue.entitlements        hardened-runtime audio input (LTC)
  Packages/OnCueCore/           Swift package with all non-UI code, independently testable
    Sources/OnCueCore/
      Model/Model.swift         show model: cameras, switchers, outputs, items, sections, tracks, cues...
      Editing/
        ShowEditing.swift       every edit the workspace makes (running order, sections, cameras, shots)
        TimelineEditing.swift   timeline spans, snapping, lyrics/notes/FX cues
        LiveCursor.swift        Live Mode position: NEXT, back, section jumps, song changes
      Engine/
        ShowEngine.swift        playhead, shot taking, Display/Preview/Cut, manual-cut pause
        Timing.swift            MIDI clock follower, internal clock, LTC follower
        LTC.swift               LTC decoder/encoder, audio input, input device list
        EngineController.swift  runs the engine: switcher, MIDI, LTC, clock, command order
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

The app is ad-hoc signed by default, so it builds without an Apple developer team.

## Packaging a DMG

```
scripts/package-dmg.sh            # Release build, ad-hoc signed, dist/OnCue-<version>-<build>.dmg
```

For a DMG that opens on any Mac, set `SIGN_IDENTITY` ("Developer ID Application: …") and `TEAM_ID`, plus notary credentials (`NOTARY_KEY_PATH`, `NOTARY_KEY_ID`, `NOTARY_ISSUER`, or `NOTARY_APPLE_ID` and `NOTARY_PASSWORD`); the script then signs with the hardened runtime, notarizes and staples. CI builds the DMG on every push (kept as a workflow artifact for 30 days) and, for a tag like `v0.2.0`, publishes a GitHub release with it. To sign in CI, add the repository secrets `DEVELOPER_ID_P12` (base64 of the exported certificate), `DEVELOPER_ID_P12_PASSWORD`, `SIGN_IDENTITY`, `TEAM_ID`, `NOTARY_APPLE_ID` and `NOTARY_PASSWORD`.

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
- **The device integrations (ATEM, Companion, OSC, PTZ, MIDI, LTC) are untested on hardware.** They are tested against stand-ins only.
- **Monitor configurations stay in the show file**, including their display names, which are per-Mac. A monitor whose display isn't connected opens as an ordinary window.
- **Plan images and named versions are stored inside the show file**, so a show with many versions or a large plan grows (plans are scaled to 2400 px JPEG; versions are compressed).
