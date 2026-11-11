# OnCue

A native macOS app (Swift / SwiftUI, macOS 14+, Apple Silicon) for scripting the camera shots of a live show and running that script on the switcher: concerts, TV-style music shows, esports and corporate shows, from 5 to 70+ cameras.

The product requirements live in the OnCue PRD (Claude Doc / `OnCue — Product Requirements.pdf`).

## Current state: early work in progress

This is not a working app yet. What exists:

| Area | File | State |
| --- | --- | --- |
| Data model and show file format | `OnCue/Model/Model.swift`, `OnCue/Model/ShowDocument.swift` | Written, never compiled |
| Switcher interface + simulator + Companion switcher | `OnCue/Devices/SwitcherDevice.swift` | Written, never compiled |
| ATEM over UDP (port 9910) | `OnCue/Devices/ATEMSwitcher.swift` | Written from the PyATEMMax protocol layouts, never compiled or tested on hardware |
| Bitfocus Companion HTTP client | `OnCue/Devices/CompanionClient.swift` | Written, never compiled |
| OSC send / control listener | `OnCue/Devices/OSC.swift` | Written, never compiled |
| PTZ preset recall (Panasonic, VISCA IP/TCP, ATEM macro, Companion) | `OnCue/Devices/PTZService.swift` | Written, never compiled or tested on hardware |
| MIDI clock in, controller in, APC40 LED out | `OnCue/Devices/MIDIManager.swift` | Written, never compiled or tested on hardware |

Not started: LTC decoder, show engine (clocks, cue firing, routing, modes), all UI, crew page server, backup sync, stats and exports, Xcode project, tests, DMG packaging.
