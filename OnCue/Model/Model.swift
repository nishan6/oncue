import Foundation

// MARK: - Enums

enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case song, segment
    var id: String { rawValue }
    var label: String { self == .song ? "Song" : "Segment" }
}

/// How cue positions inside an item are measured.
enum TimeBase: String, Codable, CaseIterable, Identifiable {
    case bars, seconds, order
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bars: return "Bars & beats"
        case .seconds: return "Seconds"
        case .order: return "Order (NEXT)"
        }
    }
}

/// How the playhead moves during the show.
enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case tap, next, midiClock, ltc, freeRun
    var id: String { rawValue }
    var label: String {
        switch self {
        case .tap: return "Section taps"
        case .next: return "NEXT per shot"
        case .midiClock: return "MIDI clock"
        case .ltc: return "LTC timecode"
        case .freeRun: return "Free run (clock)"
        }
    }
}

enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case display, preview, cut
    var id: String { rawValue }
    var label: String {
        switch self {
        case .display: return "Display"
        case .preview: return "Auto preview"
        case .cut: return "Auto cut"
        }
    }
}

enum TransitionKind: String, Codable, CaseIterable, Identifiable {
    case cut, auto
    var id: String { rawValue }
    var label: String { self == .cut ? "Cut" : "Mix (auto)" }
}

enum SwitcherKind: String, Codable, CaseIterable, Identifiable {
    case atem, companion, simulator
    var id: String { rawValue }
    var label: String {
        switch self {
        case .atem: return "Blackmagic ATEM"
        case .companion: return "Via Bitfocus Companion"
        case .simulator: return "Simulator (testing)"
        }
    }
}

enum SwitcherRole: String, Codable, CaseIterable, Identifiable {
    case main, sub, output
    var id: String { rawValue }
    var label: String {
        switch self {
        case .main: return "Main switcher"
        case .sub: return "Sub-switcher (feeds another)"
        case .output: return "Separate output"
        }
    }
}

enum BusKind: String, Codable, CaseIterable, Identifiable {
    case program, aux
    var id: String { rawValue }
}

enum TrackKind: String, Codable, CaseIterable, Identifiable {
    case shots, fx, control, osc, ptz, lyrics, notes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .shots: return "Shots"
        case .fx: return "FX (keys, DSK, macros)"
        case .control: return "Control"
        case .osc: return "OSC"
        case .ptz: return "PTZ presets"
        case .lyrics: return "Lyrics"
        case .notes: return "Notes"
        }
    }
}

enum FXAction: String, Codable, CaseIterable, Identifiable {
    case macro, dskOn, dskOff, dskAuto, keyOn, keyOff, fadeToBlack, auxSource
    var id: String { rawValue }
    var label: String {
        switch self {
        case .macro: return "Run macro"
        case .dskOn: return "DSK on"
        case .dskOff: return "DSK off"
        case .dskAuto: return "DSK auto"
        case .keyOn: return "Upstream key on"
        case .keyOff: return "Upstream key off"
        case .fadeToBlack: return "Fade to black"
        case .auxSource: return "Aux source"
        }
    }
}

enum ControlAction: String, Codable, CaseIterable, Identifiable {
    case loadNext, stop, wait, jump
    var id: String { rawValue }
    var label: String {
        switch self {
        case .loadNext: return "Load next item"
        case .stop: return "Stop"
        case .wait: return "Wait for GO"
        case .jump: return "Jump to item"
        }
    }
}

enum PTZProtocol: String, Codable, CaseIterable, Identifiable {
    case panasonic, viscaIP, viscaTCP, atemMacro, companion
    var id: String { rawValue }
    var label: String {
        switch self {
        case .panasonic: return "Panasonic (HTTP)"
        case .viscaIP: return "Sony VISCA over IP (UDP 52381)"
        case .viscaTCP: return "VISCA over TCP (PTZOptics etc.)"
        case .atemMacro: return "ATEM macro per preset"
        case .companion: return "Companion button per preset"
        }
    }
}

enum CompanionVersion: String, Codable, CaseIterable, Identifiable {
    case v3, v2
    var id: String { rawValue }
    var label: String { self == .v3 ? "Companion 3.x or newer" : "Companion 2.x" }
}

enum BackupRole: String, Codable, CaseIterable, Identifiable {
    case off, primary, backup
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Off"
        case .primary: return "This Mac is the primary"
        case .backup: return "This Mac is the backup"
        }
    }
}

enum MonitorKind: String, Codable, CaseIterable, Identifiable {
    case gallery, cameras, shotlist, countdown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gallery: return "Gallery (NOW / NEXT / running order)"
        case .cameras: return "Camera positions (chosen cameras)"
        case .shotlist: return "Shotlist"
        case .countdown: return "Big countdown"
        }
    }
}

/// Everything a controller (keyboard, APC40, Stream Deck via Companion, OSC, HTTP) can trigger.
enum ControlCommand: String, Codable, CaseIterable, Identifiable {
    case go, stop, next, previous, take, auto, tapSection, prevSection, tapBeat, loopToggle,
         panic, resume, freeModeToggle, modeDisplay, modePreview, modeCut, nextItem, prevItem,
         previewCamera, takeCamera
    var id: String { rawValue }
    var label: String {
        switch self {
        case .go: return "GO / start item"
        case .stop: return "Stop"
        case .next: return "NEXT shot"
        case .previous: return "Previous shot"
        case .take: return "Take (cut)"
        case .auto: return "Auto (mix)"
        case .tapSection: return "Tap next section"
        case .prevSection: return "Back one section"
        case .tapBeat: return "Tap tempo"
        case .loopToggle: return "Loop current section"
        case .panic: return "PANIC: all outputs to display"
        case .resume: return "Resume automation"
        case .freeModeToggle: return "Free mode on/off"
        case .modeDisplay: return "Main output: display"
        case .modePreview: return "Main output: auto preview"
        case .modeCut: return "Main output: auto cut"
        case .nextItem: return "Next song / segment"
        case .prevItem: return "Previous song / segment"
        case .previewCamera: return "Preview camera N"
        case .takeCamera: return "Take camera N"
        }
    }
    /// Commands that need a camera number.
    var needsCamera: Bool { self == .previewCamera || self == .takeCamera }
}

// MARK: - Structs

struct Camera: Identifiable, Codable, Hashable {
    var id = UUID()
    var number: Int
    /// Renamable label. Empty means "Cam <number>".
    var name: String = ""
    /// Who operates it for this show. Renamable any time.
    var operatorName: String = ""
    var switcherID: UUID?
    /// Switcher input (source) number this camera arrives on.
    var input: Int = 0
    var ptzID: UUID?

    var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Cam \(number)" : name }
    var label: String { operatorName.isEmpty ? displayName : "\(displayName) (\(operatorName))" }
}

struct CompanionButton: Codable, Hashable {
    var page: Int = 1
    var row: Int = 0
    var column: Int = 0
    /// Companion 2.x uses a single bank number per page.
    var bank: Int = 1
    var enabled: Bool = false
}

struct CompanionInputButtons: Codable, Hashable, Identifiable {
    var id: Int { input }
    var input: Int
    var preview = CompanionButton()
    var program = CompanionButton()
}

struct CompanionMapping: Codable, Hashable {
    var inputs: [CompanionInputButtons] = []
    var cut = CompanionButton()
    var auto = CompanionButton()

    func buttons(for input: Int) -> CompanionInputButtons? { inputs.first { $0.input == input } }
}

struct SwitcherConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SwitcherKind = .simulator
    var host: String = ""
    /// Mix effect bus to drive (0 = M/E 1).
    var me: Int = 0
    var role: SwitcherRole = .main
    /// For sub-switchers: which switcher it feeds, and on which input of that switcher.
    var parentID: UUID?
    var feedInput: Int = 0
    var companion = CompanionMapping()
    /// Simulator input count.
    var inputCount: Int = 20
}

struct OutputConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var switcherID: UUID?
    var bus: BusKind = .program
    /// Aux number (0 based) when bus == .aux.
    var auxIndex: Int = 0
    /// Follow the main output's shots instead of its own track.
    var mirrorMain: Bool = false
}

struct Section: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Position in the item's time base.
    var at: Double
}

struct Cue: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Position in the item's time base (beats, seconds or order step).
    var at: Double
    var cameraID: UUID?
    /// Shot description, lyric line, note, or label.
    var text: String = ""
    /// Framing note for the operator.
    var note: String = ""
    var transition: TransitionKind = .cut
    // FX
    var fxAction: FXAction?
    var fxIndex: Int = 0
    var fxValue: Int = 0
    // Control
    var controlAction: ControlAction?
    var jumpItemID: UUID?
    // OSC
    var oscTargetID: UUID?
    var oscAddress: String = ""
    /// Space separated: numbers become ints/floats, everything else strings ("quoted text" allowed).
    var oscArgs: String = ""
    // PTZ
    var ptzCameraID: UUID?
    var ptzPreset: Int = 1
}

struct Track: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: TrackKind
    var name: String
    /// Shots tracks: which output they drive.
    var outputID: UUID?
    /// FX tracks: which switcher they drive.
    var switcherID: UUID?
    var cues: [Cue] = []
    var muted: Bool = false

    mutating func sortCues() { cues.sort { $0.at < $1.at } }
}

struct RundownItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: ItemKind = .song
    var title: String
    var timeBase: TimeBase = .bars
    var syncMode: SyncMode = .tap
    var bpm: Double = 120
    var beatsPerBar: Int = 4
    /// "HH:MM:SS:FF" — LTC time at which this item starts. Empty = starts at the first LTC after GO.
    var ltcStart: String = ""
    /// Planned length in seconds (segments, esports, corporate).
    var plannedDuration: Double = 0
    /// Time of day the item must be off air, "HH:MM". Empty = none.
    var hardOut: String = ""
    var sections: [Section] = []
    var tracks: [Track] = []
    var notes: String = ""

    var sortedSections: [Section] { sections.sorted { $0.at < $1.at } }
}

struct OSCTarget: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String = "127.0.0.1"
    var port: Int = 7000
}

struct PTZCamera: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var proto: PTZProtocol = .viscaIP
    var host: String = ""
    var port: Int = 52381
    /// ATEM macro mode: macro index used for preset 1 (preset N runs macroBase + N - 1).
    var macroBase: Int = 0
    var switcherID: UUID?
    /// Companion mode: first preset's button; presets continue along the row.
    var companionStart = CompanionButton()
}

struct MIDIBinding: Identifiable, Codable, Hashable {
    var id = UUID()
    var command: ControlCommand
    var cameraNumber: Int = 0
    /// 0-15
    var channel: Int = 0
    var number: Int = 0
    var isCC: Bool = false
}

struct MonitorConfig: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: MonitorKind = .gallery
    var cameraIDs: [UUID] = []
    /// NSScreen.localizedName to open on. Empty = choose when opening.
    var screenName: String = ""
}

struct Comment: Identifiable, Codable, Hashable {
    var id = UUID()
    var itemID: UUID?
    var cueID: UUID?
    var author: String
    var text: String
    var date = Date()
    var resolved = false
}

struct ShowSettings: Codable, Hashable {
    var ltcFPS: Double = 25
    var ltcDeviceUID: String = ""
    var ltcChannel: Int = 0
    var midiClockSource: String = ""
    var controllerSource: String = ""
    var controllerDestination: String = ""
    var apcLEDs: Bool = true
    var crewPort: Int = 8080
    var crewInterface: String = ""
    var oscControlPort: Int = 9000
    var companionHost: String = "127.0.0.1"
    var companionPort: Int = 8000
    var companionVersion: CompanionVersion = .v3
    var minShotSeconds: Double = 1.5
    var unusedCameraMinutes: Double = 10
    var manualCutWindow: Double = 0.4
    var backupRole: BackupRole = .off
    var primaryHost: String = ""
    var monitors: [MonitorConfig] = []
    var logFolder: String = ""
}

struct Show: Codable, Hashable {
    var name: String = "New Show"
    var cameras: [Camera] = []
    var switchers: [SwitcherConfig] = []
    var outputs: [OutputConfig] = []
    var items: [RundownItem] = []
    var oscTargets: [OSCTarget] = []
    var ptzCameras: [PTZCamera] = []
    var comments: [Comment] = []
    var midiBindings: [MIDIBinding] = []
    var settings = ShowSettings()

    // MARK: lookups
    func camera(_ id: UUID?) -> Camera? { guard let id else { return nil }; return cameras.first { $0.id == id } }
    func camera(number: Int) -> Camera? { cameras.first { $0.number == number } }
    func switcher(_ id: UUID?) -> SwitcherConfig? { guard let id else { return nil }; return switchers.first { $0.id == id } }
    func output(_ id: UUID?) -> OutputConfig? { guard let id else { return nil }; return outputs.first { $0.id == id } }
    var mainOutput: OutputConfig? { outputs.first }
    func ptz(_ id: UUID?) -> PTZCamera? { guard let id else { return nil }; return ptzCameras.first { $0.id == id } }
    func oscTarget(_ id: UUID?) -> OSCTarget? { guard let id else { return nil }; return oscTargets.first { $0.id == id } }
    func itemIndex(_ id: UUID?) -> Int? { guard let id else { return nil }; return items.firstIndex { $0.id == id } }

    // MARK: defaults
    static func starter() -> Show {
        var show = Show()
        let sim = SwitcherConfig(name: "Simulator", kind: .simulator, role: .main)
        show.switchers = [sim]
        show.outputs = [OutputConfig(name: "Program", switcherID: sim.id)]
        show.cameras = (1...4).map { Camera(number: $0, switcherID: sim.id, input: $0) }
        show.items = [RundownItem.newSong(title: "Song 1", show: show)]
        show.midiBindings = MIDIBinding.apc40Defaults()
        return show
    }

    /// New shots track for every output (used when outputs change).
    mutating func ensureShotTracks() {
        for i in items.indices {
            for out in outputs where !items[i].tracks.contains(where: { $0.kind == .shots && $0.outputID == out.id }) {
                items[i].tracks.insert(Track(kind: .shots, name: "\(out.name) shots", outputID: out.id), at: 0)
            }
        }
    }
}

extension RundownItem {
    static func newSong(title: String, show: Show) -> RundownItem {
        var item = RundownItem(kind: .song, title: title, timeBase: .bars, syncMode: .tap)
        item.sections = [Section(name: "Intro", at: 0), Section(name: "Verse", at: 16), Section(name: "Chorus", at: 48)]
        item.tracks = show.outputs.map { Track(kind: .shots, name: "\($0.name) shots", outputID: $0.id) }
        item.tracks.append(Track(kind: .fx, name: "FX", switcherID: show.mainOutput?.switcherID))
        item.tracks.append(Track(kind: .control, name: "Control"))
        item.tracks.append(Track(kind: .lyrics, name: "Lyrics"))
        return item
    }

    static func newSegment(title: String, show: Show) -> RundownItem {
        var item = RundownItem(kind: .segment, title: title, timeBase: .seconds, syncMode: .freeRun)
        item.plannedDuration = 300
        item.tracks = show.outputs.map { Track(kind: .shots, name: "\($0.name) shots", outputID: $0.id) }
        item.tracks.append(Track(kind: .fx, name: "FX", switcherID: show.mainOutput?.switcherID))
        item.tracks.append(Track(kind: .control, name: "Control"))
        item.tracks.append(Track(kind: .notes, name: "Notes"))
        return item
    }

    func shotsTrack(for outputID: UUID?) -> Track? {
        tracks.first { $0.kind == .shots && $0.outputID == outputID }
    }

    /// End of a section = start of the following one (nil for the last section).
    func sectionEnd(_ section: Section) -> Double? {
        let s = sortedSections
        guard let i = s.firstIndex(where: { $0.id == section.id }), i + 1 < s.count else { return nil }
        return s[i + 1].at
    }

    func section(at position: Double) -> Section? {
        sortedSections.last { $0.at <= position + 1e-9 }
    }

    /// Format a position for display.
    func format(_ position: Double) -> String {
        switch timeBase {
        case .bars:
            let bpb = Double(max(beatsPerBar, 1))
            let bar = Int(floor(position / bpb)) + 1
            let beat = position - Double(bar - 1) * bpb + 1
            return String(format: "%d.%g", bar, (beat * 100).rounded() / 100)
        case .seconds:
            return TimeFormat.mmss(position)
        case .order:
            return "#\(Int(position.rounded()))"
        }
    }

    /// Parse "17.1" (bars), "1:23.5" (seconds) or "12" (order) into a position.
    func parse(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        switch timeBase {
        case .bars:
            let parts = t.split(separator: ".", maxSplits: 1).map(String.init)
            guard let bar = Double(parts.first ?? "") else { return nil }
            let beat = parts.count > 1 ? (Double(parts[1]) ?? 1) : 1
            return (bar - 1) * Double(max(beatsPerBar, 1)) + (beat - 1)
        case .seconds:
            return TimeFormat.parseSeconds(t)
        case .order:
            return Double(t.replacingOccurrences(of: "#", with: ""))
        }
    }

    /// Converts a position to seconds using the item tempo (for durations and countdowns).
    func seconds(for position: Double, tempo: Double? = nil) -> Double {
        switch timeBase {
        case .bars: return position * 60.0 / max(tempo ?? bpm, 1)
        case .seconds, .order: return position
        }
    }
}

extension MIDIBinding {
    /// APC40 mkII defaults: clip grid notes 0-39 = take camera 1-40 (bottom-left is 1),
    /// track select / scene buttons drive the show. All of these can be re-learned in Setup.
    static func apc40Defaults() -> [MIDIBinding] {
        var b: [MIDIBinding] = []
        for cam in 1...40 { b.append(MIDIBinding(command: .takeCamera, cameraNumber: cam, channel: 0, number: cam - 1)) }
        // Scene launch column (notes 82-86 on APC40 mkII)
        b.append(MIDIBinding(command: .next, channel: 0, number: 82))
        b.append(MIDIBinding(command: .previous, channel: 0, number: 83))
        b.append(MIDIBinding(command: .tapSection, channel: 0, number: 84))
        b.append(MIDIBinding(command: .loopToggle, channel: 0, number: 85))
        b.append(MIDIBinding(command: .resume, channel: 0, number: 86))
        // Transport-style buttons (Play 91, Record 93, Session 102 on APC40 mkII)
        b.append(MIDIBinding(command: .go, channel: 0, number: 91))
        b.append(MIDIBinding(command: .panic, channel: 0, number: 93))
        b.append(MIDIBinding(command: .tapBeat, channel: 0, number: 99))
        return b
    }
}

// MARK: - Time helpers

enum TimeFormat {
    static func mmss(_ s: Double) -> String {
        let neg = s < 0
        let v = abs(s)
        let m = Int(v) / 60
        let sec = v - Double(m * 60)
        return (neg ? "-" : "") + String(format: "%d:%04.1f", m, sec)
    }

    static func hms(_ s: Double) -> String {
        let v = Int(max(0, s))
        return String(format: "%02d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60)
    }

    static func parseSeconds(_ t: String) -> Double? {
        let parts = t.split(separator: ":").map(String.init)
        var total = 0.0
        for p in parts {
            guard let v = Double(p) else { return nil }
            total = total * 60 + v
        }
        return parts.isEmpty ? nil : total
    }

    /// "HH:MM:SS:FF" -> seconds at the given fps.
    static func parseTimecode(_ t: String, fps: Double) -> Double? {
        let parts = t.replacingOccurrences(of: ";", with: ":").split(separator: ":").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2] + parts[3] / max(fps.rounded(), 1)
    }

    static func timecode(_ s: Double, fps: Double) -> String {
        let f = max(fps.rounded(), 1)
        let total = max(0, s)
        let whole = Int(total)
        let frames = Int((total - Double(whole)) * f)
        return String(format: "%02d:%02d:%02d:%02d", whole / 3600, (whole % 3600) / 60, whole % 60, frames)
    }

    /// "HH:MM" today -> Date (the next occurrence if already past by more than 12h).
    static func todayAt(_ hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts[0]; comps.minute = parts[1]; comps.second = parts.count > 2 ? parts[2] : 0
        guard var d = Calendar.current.date(from: comps) else { return nil }
        if d.timeIntervalSinceNow < -12 * 3600 { d = d.addingTimeInterval(24 * 3600) }
        return d
    }
}
