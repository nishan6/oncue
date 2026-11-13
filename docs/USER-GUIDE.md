# OnCue user guide

OnCue is a shot-scripting and live show-control app for macOS 14 Sonoma or later (Apple Silicon
and Intel). You script every shot of a show against the music or the running order, then run it
live: OnCue calls, previews or cuts the shots on your switcher, drives tally, lighting, sound and
graphics cues, and keeps the crew on the same page.

> **Device status.** Every device adapter, ATEM included, is marked **Built**: written from the
> maker's protocol documents and tested against simulators, not yet on the real hardware. Try a
> device on the kit before a show, never for the first time during one. See
> [Device support](#device-support).

## Contents

1. [Install and update](#install-and-update)
2. [Projects, playlists and scenes](#projects-playlists-and-scenes)
3. [Scripting shots](#scripting-shots)
4. [Show setup: switchers, cameras and devices](#show-setup-switchers-cameras-and-devices)
5. [Live Mode](#live-mode)
6. [Triggers and timecode](#triggers-and-timecode)
7. [The crew: phones, iPads and monitors](#the-crew-phones-ipads-and-monitors)
8. [Backup Mac and backup switcher](#backup-mac-and-backup-switcher)
9. [After the show](#after-the-show)
10. [Settings for this Mac](#settings-for-this-mac)
11. [Device support](#device-support)
12. [Troubleshooting](#troubleshooting)

## Install and update

1. Open the DMG and drag **OnCue** to **Applications**.
2. The first launch asks for local network access (for switchers, tally and the crew page) and,
   if you use LTC or tap tempo from audio, the microphone. Allow both.
3. OnCue checks for a new version every 6 hours and asks before installing: **OnCue › Check for
   Updates…** checks now. It never checks, downloads or installs during Live Mode. An update is
   installed only if it's signed by the same developer and notarised by Apple; the old copy goes
   to the Trash. Turn checks off in **Settings › Updates**.

To try everything without kit: **Help › Open Sample Project**.

## Projects, playlists and scenes

- **Project Library** (⇧⌘L) lists your projects. A project holds the cameras, switchers and
  devices for a production, and one or more **playlists** (a night's running order).
- A playlist holds **scenes**: songs (timed in bars against the music) or segments (timed in
  seconds or just in order). Each has a number, artist, status and planned length.
- **Versions** keeps named copies of the script; one is saved automatically before every Live run.
  A backup folder (Settings › Backup) gets a copy a few seconds after each change.

## Scripting shots

- **Views:** Timeline (⌘1), Timeline and List (⌘2, the default) and List (⌘3). The ruler shows
  bars or time.
- **Add a shot:** Return. **Pick the camera:** type its number (two digits quickly for 10+).
  Arrow keys move between shots; ⌥⌘↑/↓ moves a shot.
- **Shot details** (inspector › Info): size, movement, framing, subjects, transition (cut, mix,
  dip, wipe, DVE, stinger or your own) with its length in frames, notes, and status. Statuses are
  Planned, Confirmed and Cut, plus your own; shots marked Cut stay in the script greyed out and are
  skipped in Live.
- **Project Properties** (⌥⌘,) holds the lists of sizes, movements, framings, cast and
  transitions, scene defaults, timecode and roles.
- **Tracks** besides shots: Cues (department calls with an optional role), Media Player Control,
  Device commands (lighting, sound, graphics, MIDI, HyperDeck and more) and the song's audio or
  PGM video.
- **Bulk edits:** quantise shots to a grid, Move All (shift everything after a point), and change
  many shots at once from the inspector.
- **Index** (inspector) lists every shot per camera; **Reviews** keeps rehearsal notes per shot.
- **Media Pool** links audio, video and stills where they are on disk; relink moved files; clear
  unused moves files to the Trash after asking.
- **Draft Script** builds a first script from a switch log or an EDL of a previous show.

## Show setup: switchers, cameras and devices

**Show Setup** (⌥⌘S) has tabs for Switchers, Outputs, Tally, Devices, OSC, PTZ, Monitors and
Controls. **Cameras** (⌥⌘C) sets each camera's number, name, operator, colour and switcher input.

- **Switchers:** add the main switcher (ATEM, Ross, Panasonic, Roland, vMix, OBS, Companion or the
  Simulator). A **parallel switcher** can mirror every command; set failover per switcher to
  *Automatic* or *Ask*, with a timeout (default 2 s).
- **Tally:** TSL UMD 3.1, 4.0 or 5.0 out over UDP or TCP, with camera names on the UMDs, and TSL in
  (OnCue follows a manual cut made on the desk).
- **Devices:** MIDI and MSC, TCP/UDP text, HTTP, serial, Art-Net and sACN (with fades), HyperDeck,
  and consoles: grandMA3, grandMA2, Avolites, Ross XPression, Resolume, X32/M32, WING, Yamaha (RCP),
  Allen & Heath (MIDI). Every device can be set to **Simulated** to rehearse without it.
- **Pre-show check** (⌥⌘K) tests connections, inputs, the script and devices.
- **Device Status** (⌥⌘D) shows every switcher, tally link, device and console, live.

## Live Mode

⌘L enters Live Mode on the selected scene. Nothing is sent to the switcher until you choose a mode:

- **Display:** OnCue only shows the calls.
- **Preview:** OnCue puts the next shot on preview; you cut.
- **Cut:** OnCue cuts on the script.

| Key | Does |
| --- | --- |
| Space or → | NEXT shot |
| ← | Previous shot |
| Return | GO / stop the song |
| 1–99 | Camera to preview |
| C / A | Cut / auto-mix preview to program |
| T / B | Tap the next section / the beat |
| L / F / R | Loop the section / free mode / resume |
| Esc | **Panic**: every output to Display |
| ⌘[ / ⌘] | Previous / next song |

Cutting by hand in Cut mode pauses automation; **R** resumes. The countdown shows the next cut
and section, with a standby flash for the next camera. Help › Keyboard Shortcuts (⌘/) lists every
key. While Live, the Mac doesn't sleep and OnCue keeps full timing even in the background.

## Triggers and timecode

- **Timing per song:** section taps, NEXT per shot, free run, MIDI clock, LTC, MTC or OSC
  position. If LTC or MTC drops out, OnCue freewheels to the end of the song (configurable).
- **Trigger Routes** (⌥⌘R): OSC, MIDI note/CC/program change, MSC and Art-Net can start songs,
  go to a song by number, fire NEXT/GO/panic, mark a note on the shot on air, and more. **Learn**
  fills a route from the next message received.
- **Stream Deck:** through Bitfocus Companion (OSC to OnCue, and OnCue's status back as Companion
  variables). See Settings › Companion and Stream Deck.

## The crew: phones, iPads and monitors

- **Crew page** (toolbar): operators scan the QR code. Each picks their camera once and sees their
  tally, a countdown to their next shot and what's coming. Outside Live they can comment on shots.
- **Viewer** (same popover): for iPads and the floor manager. **Multi View** (every camera's
  current and next shots side by side), **One camera** or **Whole script**, view only. Set a screen
  once with its address, e.g. `/view?mode=camera&cam=2` or `/view?mode=multi&cams=1,2,3&next=3`.
- **Monitors** (Show Setup › Monitors): full-screen views on this Mac's extra displays during Live:
  gallery, camera grid, shot list, big countdown, plot, Multi View and Full Page.

## Backup Mac and backup switcher

- **Backup Mac:** in Settings › Backup, set one Mac to *Main, with a backup following* and the
  other to *Backup* with the main Mac's address. The backup follows the show and can take over.
- **Backup switcher:** a parallel switcher mirrors the main one; failover is automatic or asks
  (⇧⌘F answers the prompt). Every failover is logged.

## After the show

Leaving Live Mode opens the **show report** from the switch log (saved in Documents/OnCue Logs or
the folder in Settings). **Tour mode** compares nights. **Export** (⇧⌘E): call sheets and camera
scripts (PDF), EDL markers, CSV.

## Settings for this Mac

**OnCue › Settings** (⌘,) holds what belongs to this Mac, not the show: MIDI and LTC devices,
Companion, the crew network, backup role and folder, **Accessibility** (text size; tally with
shapes and words, not only red and green) and **Updates**.

## Device support

| Device | Status |
| --- | --- |
| ATEM, Ross (RossTalk), Panasonic AV-HS410 / AV-UHS500 / AV-HS6000, Roland V-160HD / V-80HD / V-60HD, vMix, OBS | Built |
| For-A | Through Companion (direct adapter needs For-A's protocol document) |
| Roland V-1HD / V-8HD | Not yet (needs the MIDI implementation chart) |
| TSL 3.1 / 4.0 / 5.0 tally, GPI via ATEM GPI and Tally Interface | Built |
| grandMA3, grandMA2, Avolites, XPression, Resolume, X32/M32, WING, Yamaha, Allen & Heath | Built (Allen & Heath fader levels not yet) |
| DiGiCo | MIDI program change |
| Vizrt, disguise | Not yet (need their documentation) |

## Troubleshooting

- **A device won't connect:** check it in Device Status (⌥⌘D), then the address and port in Show
  Setup. macOS must allow OnCue on the local network (System Settings › Privacy & Security › Local
  Network).
- **Phones can't open the crew page:** they must be on the same network as the Mac; pick that
  network in the Crew page popover.
- **Automation stopped:** a hand cut in Cut mode pauses it; press R.
- **Something is wrong live:** Esc (panic) puts every output in Display; the switcher stays as it is.
