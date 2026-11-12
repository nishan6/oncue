import Foundation

// MARK: - Enums

public enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case song, segment
    public var id: String { rawValue }
    public var label: String { self == .song ? "Song" : "Segment" }
}

/// How cue positions inside an item are measured.
public enum TimeBase: String, Codable, CaseIterable, Identifiable {
    case bars, seconds, order
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .bars: return "Bars & beats"
        case .seconds: return "Seconds"
        case .order: return "Order (NEXT)"
        }
    }
}

/// How the playhead moves during the show.
public enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case tap, next, midiClock, ltc, freeRun
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .tap: return "Section taps"
        case .next: return "NEXT per shot"
        case .midiClock: return "MIDI clock"
        case .ltc: return "LTC timecode"
        case .freeRun: return "Free run (clock)"
        }
    }
}

public enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case display, preview, cut
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .display: return "Display"
        case .preview: return "Auto preview"
        case .cut: return "Auto cut"
        }
    }
}

public enum TransitionKind: String, Codable, CaseIterable, Identifiable {
    case cut, auto
    public var id: String { rawValue }
    public var label: String { self == .cut ? "Cut" : "Mix (auto)" }
}

public enum SwitcherKind: String, Codable, CaseIterable, Identifiable {
    case atem, companion, simulator
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .atem: return "Blackmagic ATEM"
        case .companion: return "Via Bitfocus Companion"
        case .simulator: return "Simulator (testing)"
        }
    }
}

public enum SwitcherRole: String, Codable, CaseIterable, Identifiable {
    case main, sub, output
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .main: return "Main switcher"
        case .sub: return "Sub-switcher (feeds another)"
        case .output: return "Separate output"
        }
    }
}

public enum BusKind: String, Codable, CaseIterable, Identifiable {
    case program, aux
    public var id: String { rawValue }
}

public enum TrackKind: String, Codable, CaseIterable, Identifiable {
    case shots, fx, control, osc, ptz, lyrics, notes
    public var id: String { rawValue }
    public var label: String {
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

public enum FXAction: String, Codable, CaseIterable, Identifiable {
    case macro, dskOn, dskOff, dskAuto, keyOn, keyOff, fadeToBlack, auxSource
    public var id: String { rawValue }
    public var label: String {
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

public enum ControlAction: String, Codable, CaseIterable, Identifiable {
    case loadNext, stop, wait, jump
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .loadNext: return "Load next item"
        case .stop: return "Stop"
        case .wait: return "Wait for GO"
        case .jump: return "Jump to item"
        }
    }
}

public enum PTZProtocol: String, Codable, CaseIterable, Identifiable {
    case panasonic, viscaIP, viscaTCP, atemMacro, companion
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .panasonic: return "Panasonic (HTTP)"
        case .viscaIP: return "Sony VISCA over IP (UDP 52381)"
        case .viscaTCP: return "VISCA over TCP (PTZOptics etc.)"
        case .atemMacro: return "ATEM macro per preset"
        case .companion: return "Companion button per preset"
        }
    }
}

public enum CompanionVersion: String, Codable, CaseIterable, Identifiable {
    case v3, v2
    public var id: String { rawValue }
    public var label: String { self == .v3 ? "Companion 3.x or newer" : "Companion 2.x" }
}

public enum BackupRole: String, Codable, CaseIterable, Identifiable {
    case off, primary, backup
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .off: return "Off"
        case .primary: return "This Mac is the primary"
        case .backup: return "This Mac is the backup"
        }
    }
}

public enum MonitorKind: String, Codable, CaseIterable, Identifiable {
    case gallery, cameras, shotlist, countdown
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .gallery: return "Gallery (NOW / NEXT / running order)"
        case .cameras: return "Camera positions (chosen cameras)"
        case .shotlist: return "Shotlist"
        case .countdown: return "Big countdown"
        }
    }
}

/// Everything a controller (keyboard, APC40, Stream Deck via Companion, OSC, HTTP) can trigger.
public enum ControlCommand: String, Codable, CaseIterable, Identifiable {
    case go, stop, next, previous, take, auto, tapSection, prevSection, tapBeat, loopToggle,
         panic, resume, freeModeToggle, modeDisplay, modePreview, modeCut, nextItem, prevItem,
         previewCamera, takeCamera
    public var id: String { rawValue }
    public var label: String {
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
    public var needsCamera: Bool { self == .previewCamera || self == .takeCamera }
}

// MARK: - Structs

public struct Camera: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var number: Int
    /// Renamable label. Empty means "Cam <number>".
    public var name: String = ""
    /// Who operates it for this show. Renamable any time.
    public var operatorName: String = ""
    public var switcherID: UUID?
    /// Switcher input (source) number this camera arrives on.
    public var input: Int = 0
    public var ptzID: UUID?
    /// The same camera on other switchers (split or DA'd to separate outputs).
    public var extraInputs: [CameraInput] = []
    /// Colour of this camera's shots, as "#RRGGBB". Empty means the default colour for its number.
    public var color: String = ""

    /// The colour actually used: the chosen one, or the palette colour for the camera number.
    public var resolvedColor: String {
        let c = color.trimmingCharacters(in: .whitespaces)
        return CameraPalette.isValid(c) ? c.uppercased() : CameraPalette.color(forNumber: number)
    }

    public var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Cam \(number)" : name }
    public var label: String { operatorName.isEmpty ? displayName : "\(displayName) (\(operatorName))" }
}

/// A camera's input on an additional switcher.
public struct CameraInput: Codable, Hashable {
    public var switcherID: UUID
    public var input: Int
    public init(switcherID: UUID, input: Int) {
        self.switcherID = switcherID
        self.input = input
    }
}

/// Default camera colours: twelve hues that stay distinct from each other on a mid-grey
/// background. Red and green are left out so they never read as tally.
public enum CameraPalette {
    public static let colors: [String] = [
        "#4C8DF6", // blue
        "#F5A524", // amber
        "#2EC4B6", // teal
        "#E85D9E", // pink
        "#9B6CF2", // violet
        "#A8C93A", // lime
        "#F2774F", // coral
        "#43B9E8", // sky
        "#D9B93A", // mustard
        "#B98557", // tan
        "#6F7FE0", // indigo
        "#5FD1A0", // mint
    ]

    public static func color(forNumber number: Int) -> String {
        colors[((max(number, 1) - 1) % colors.count)]
    }

    public static func isValid(_ hex: String) -> Bool {
        guard hex.count == 7, hex.first == "#" else { return false }
        return hex.dropFirst().allSatisfy { $0.isHexDigit }
    }
}

public struct CompanionButton: Codable, Hashable {
    public init(page: Int = 1, row: Int = 0, column: Int = 0, bank: Int = 1, enabled: Bool = false) {
        self.page = page
        self.row = row
        self.column = column
        self.bank = bank
        self.enabled = enabled
    }
    public var page: Int = 1
    public var row: Int = 0
    public var column: Int = 0
    /// Companion 2.x uses a single bank number per page.
    public var bank: Int = 1
    public var enabled: Bool = false
}

public struct CompanionInputButtons: Codable, Hashable, Identifiable {
    public init(input: Int, preview: CompanionButton = CompanionButton(), program: CompanionButton = CompanionButton()) {
        self.input = input
        self.preview = preview
        self.program = program
    }
    public var id: Int { input }
    public var input: Int
    public var preview = CompanionButton()
    public var program = CompanionButton()
}

public struct CompanionMapping: Codable, Hashable {
    public var inputs: [CompanionInputButtons] = []
    public var cut = CompanionButton()
    public var auto = CompanionButton()

    public func buttons(for input: Int) -> CompanionInputButtons? { inputs.first { $0.input == input } }
}

public struct SwitcherConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var kind: SwitcherKind = .simulator
    public var host: String = ""
    /// Mix effect bus to drive (0 = M/E 1).
    public var me: Int = 0
    public var role: SwitcherRole = .main
    /// For sub-switchers: which switcher it feeds, and on which input of that switcher.
    public var parentID: UUID?
    public var feedInput: Int = 0
    public var companion = CompanionMapping()
    /// Simulator input count.
    public var inputCount: Int = 20
}

public struct OutputConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var switcherID: UUID?
    public var bus: BusKind = .program
    /// Aux number (0 based) when bus == .aux.
    public var auxIndex: Int = 0
    /// Follow the main output's shots instead of its own track.
    public var mirrorMain: Bool = false
}

public struct SongSection: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    /// Position in the item's time base.
    public var at: Double
}

public struct Cue: Identifiable, Codable, Hashable {
    public var id = UUID()
    /// Position in the item's time base (beats, seconds or order step).
    public var at: Double
    public var cameraID: UUID?
    /// Shot description, lyric line, note, or label.
    public var text: String = ""
    /// Framing note for the operator.
    public var note: String = ""
    public var transition: TransitionKind = .cut
    // FX
    public var fxAction: FXAction?
    public var fxIndex: Int = 0
    public var fxValue: Int = 0
    // Control
    public var controlAction: ControlAction?
    public var jumpItemID: UUID?
    // OSC
    public var oscTargetID: UUID?
    public var oscAddress: String = ""
    /// Space separated: numbers become ints/floats, everything else strings ("quoted text" allowed).
    public var oscArgs: String = ""
    // PTZ
    public var ptzCameraID: UUID?
    public var ptzPreset: Int = 1
}

public struct Track: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var kind: TrackKind
    public var name: String
    /// Shots tracks: which output they drive.
    public var outputID: UUID?
    /// FX tracks: which switcher they drive.
    public var switcherID: UUID?
    public var cues: [Cue] = []
    public var muted: Bool = false

    public mutating func sortCues() { cues.sort { $0.at < $1.at } }
}

public struct RundownItem: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var kind: ItemKind = .song
    public var title: String
    public var timeBase: TimeBase = .bars
    public var syncMode: SyncMode = .tap
    public var bpm: Double = 120
    public var beatsPerBar: Int = 4
    /// "HH:MM:SS:FF" — LTC time at which this item starts. Empty = starts at the first LTC after GO.
    public var ltcStart: String = ""
    /// Planned length in seconds (segments, esports, corporate).
    public var plannedDuration: Double = 0
    /// Time of day the item must be off air, "HH:MM". Empty = none.
    public var hardOut: String = ""
    public var sections: [SongSection] = []
    public var tracks: [Track] = []
    public var notes: String = ""

    public var sortedSections: [SongSection] { sections.sorted { $0.at < $1.at } }
}

public struct OSCTarget: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var host: String = "127.0.0.1"
    public var port: Int = 7000
}

public struct PTZCamera: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var proto: PTZProtocol = .viscaIP
    public var host: String = ""
    public var port: Int = 52381
    /// ATEM macro mode: macro index used for preset 1 (preset N runs macroBase + N - 1).
    public var macroBase: Int = 0
    public var switcherID: UUID?
    /// Companion mode: first preset's button; presets continue along the row.
    public var companionStart = CompanionButton()
}

public struct MIDIBinding: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var command: ControlCommand
    public var cameraNumber: Int = 0
    /// 0-15
    public var channel: Int = 0
    public var number: Int = 0
    public var isCC: Bool = false
}

public struct MonitorConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var kind: MonitorKind = .gallery
    public var cameraIDs: [UUID] = []
    /// NSScreen.localizedName to open on. Empty = choose when opening.
    public var screenName: String = ""
}

public struct Comment: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var itemID: UUID?
    public var cueID: UUID?
    public var author: String
    public var text: String
    public var date = Date()
    public var resolved = false
}

/// Production settings that travel with the show file.
/// Per-Mac hardware settings live in `MachineProfile` (see MachineProfile.swift).
public struct ShowSettings: Codable, Hashable {
    public var ltcFPS: Double = 25
    public var minShotSeconds: Double = 1.5
    public var unusedCameraMinutes: Double = 10
    public var manualCutWindow: Double = 0.4
    public var monitors: [MonitorConfig] = []
}

public struct Show: Codable, Hashable, Identifiable {
    /// Version of the show file format this build writes. See ShowCoding / ShowMigration.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int = Show.currentSchemaVersion
    /// Stable identity of the production (used to restore each show's workspace).
    public var id: UUID = UUID()
    public var name: String = "New Show"
    public var cameras: [Camera] = []
    public var switchers: [SwitcherConfig] = []
    public var outputs: [OutputConfig] = []
    public var items: [RundownItem] = []
    public var oscTargets: [OSCTarget] = []
    public var ptzCameras: [PTZCamera] = []
    public var comments: [Comment] = []
    public var midiBindings: [MIDIBinding] = []
    public var settings = ShowSettings()
    public var plot = CameraPlot()

    /// Counts shown by the app shell without exposing the internal model types.
    public var cameraCount: Int { cameras.count }
    public var itemCount: Int { items.count }

    // MARK: lookups
    public func camera(_ id: UUID?) -> Camera? { guard let id else { return nil }; return cameras.first { $0.id == id } }
    public func camera(number: Int) -> Camera? { cameras.first { $0.number == number } }
    public func switcher(_ id: UUID?) -> SwitcherConfig? { guard let id else { return nil }; return switchers.first { $0.id == id } }
    public func output(_ id: UUID?) -> OutputConfig? { guard let id else { return nil }; return outputs.first { $0.id == id } }
    public var mainOutput: OutputConfig? { outputs.first }
    public func ptz(_ id: UUID?) -> PTZCamera? { guard let id else { return nil }; return ptzCameras.first { $0.id == id } }
    public func oscTarget(_ id: UUID?) -> OSCTarget? { guard let id else { return nil }; return oscTargets.first { $0.id == id } }
    public func itemIndex(_ id: UUID?) -> Int? { guard let id else { return nil }; return items.firstIndex { $0.id == id } }

    // MARK: defaults
    public static func starter() -> Show {
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
    public mutating func ensureShotTracks() {
        for i in items.indices {
            for out in outputs where !items[i].tracks.contains(where: { $0.kind == .shots && $0.outputID == out.id }) {
                items[i].tracks.insert(Track(kind: .shots, name: "\(out.name) shots", outputID: out.id), at: 0)
            }
        }
    }
}

extension RundownItem {
    public static func newSong(title: String, show: Show) -> RundownItem {
        var item = RundownItem(kind: .song, title: title, timeBase: .bars, syncMode: .tap)
        item.sections = [SongSection(name: "Intro", at: 0), SongSection(name: "Verse", at: 16), SongSection(name: "Chorus", at: 48)]
        item.tracks = show.outputs.map { Track(kind: .shots, name: "\($0.name) shots", outputID: $0.id) }
        item.tracks.append(Track(kind: .fx, name: "FX", switcherID: show.mainOutput?.switcherID))
        item.tracks.append(Track(kind: .control, name: "Control"))
        item.tracks.append(Track(kind: .lyrics, name: "Lyrics"))
        return item
    }

    public static func newSegment(title: String, show: Show) -> RundownItem {
        var item = RundownItem(kind: .segment, title: title, timeBase: .seconds, syncMode: .freeRun)
        item.plannedDuration = 300
        item.tracks = show.outputs.map { Track(kind: .shots, name: "\($0.name) shots", outputID: $0.id) }
        item.tracks.append(Track(kind: .fx, name: "FX", switcherID: show.mainOutput?.switcherID))
        item.tracks.append(Track(kind: .control, name: "Control"))
        item.tracks.append(Track(kind: .notes, name: "Notes"))
        return item
    }

    public func shotsTrack(for outputID: UUID?) -> Track? {
        tracks.first { $0.kind == .shots && $0.outputID == outputID }
    }

    /// End of a section = start of the following one (nil for the last section).
    public func sectionEnd(_ section: SongSection) -> Double? {
        let s = sortedSections
        guard let i = s.firstIndex(where: { $0.id == section.id }), i + 1 < s.count else { return nil }
        return s[i + 1].at
    }

    public func section(at position: Double) -> SongSection? {
        sortedSections.last { $0.at <= position + 1e-9 }
    }

    /// Format a position for display.
    public func format(_ position: Double) -> String {
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
    public func parse(_ text: String) -> Double? {
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
    public func seconds(for position: Double, tempo: Double? = nil) -> Double {
        switch timeBase {
        case .bars: return position * 60.0 / max(tempo ?? bpm, 1)
        case .seconds, .order: return position
        }
    }
}

extension MIDIBinding {
    /// APC40 mkII defaults: clip grid notes 0-39 = take camera 1-40 (bottom-left is 1),
    /// track select / scene buttons drive the show. All of these can be re-learned in Setup.
    public static func apc40Defaults() -> [MIDIBinding] {
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

public enum TimeFormat {
    public static func mmss(_ s: Double) -> String {
        let neg = s < 0
        let v = abs(s)
        let m = Int(v) / 60
        let sec = v - Double(m * 60)
        return (neg ? "-" : "") + String(format: "%d:%04.1f", m, sec)
    }

    public static func hms(_ s: Double) -> String {
        let v = Int(max(0, s))
        return String(format: "%02d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60)
    }

    public static func parseSeconds(_ t: String) -> Double? {
        let parts = t.split(separator: ":").map(String.init)
        var total = 0.0
        for p in parts {
            guard let v = Double(p) else { return nil }
            total = total * 60 + v
        }
        return parts.isEmpty ? nil : total
    }

    /// "HH:MM:SS:FF" -> seconds at the given fps.
    public static func parseTimecode(_ t: String, fps: Double) -> Double? {
        let parts = t.replacingOccurrences(of: ";", with: ":").split(separator: ":").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2] + parts[3] / max(fps.rounded(), 1)
    }

    public static func timecode(_ s: Double, fps: Double) -> String {
        let f = max(fps.rounded(), 1)
        let total = max(0, s)
        let whole = Int(total)
        let frames = Int((total - Double(whole)) * f)
        return String(format: "%02d:%02d:%02d:%02d", whole / 3600, (whole % 3600) / 60, whole % 60, frames)
    }

    /// "HH:MM" today -> Date (the next occurrence if already past by more than 12h).
    public static func todayAt(_ hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts[0]; comps.minute = parts[1]; comps.second = parts.count > 2 ? parts[2] : 0
        guard var d = Calendar.current.date(from: comps) else { return nil }
        if d.timeIntervalSinceNow < -12 * 3600 { d = d.addingTimeInterval(24 * 3600) }
        return d
    }
}
