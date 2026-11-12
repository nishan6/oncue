import Foundation

// Schema 2: a project holds playlists of scenes. A scene is a `RundownItem` (song or segment);
// the rig (cameras, switchers, outputs, OSC targets, PTZ, MIDI) is shared by every playlist.
//
// Time: in the file, positions in a timecode/seconds scene are whole frames at the scene's frame
// rate, and positions in a bars-and-beats scene are whole ticks (960 per beat). In memory the
// editor and engine still work in seconds and beats; `quantizePositions` keeps those values on
// the frame or tick grid, so saving and reopening never moves anything.

// MARK: - Frame rate

/// An exact frame rate as a fraction (30000/1001 for 29.97), with drop-frame timecode where it applies.
public struct FrameRate: Hashable, Codable, Identifiable, CustomStringConvertible {
    public var numerator: Int
    public var denominator: Int
    /// Drop-frame timecode labels. Only meaningful for 29.97 and 59.94.
    public var dropFrame: Bool

    public init(numerator: Int, denominator: Int = 1, dropFrame: Bool = false) {
        let n = max(numerator, 1)
        let d = max(denominator, 1)
        let g = FrameRate.gcd(n, d)
        self.numerator = n / g
        self.denominator = d / g
        self.dropFrame = dropFrame && FrameRate.dropFrameAllowed(n / g, d / g)
    }

    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = a
        var y = b
        while y != 0 {
            let r = x % y
            x = y
            y = r
        }
        return max(x, 1)
    }

    static func dropFrameAllowed(_ n: Int, _ d: Int) -> Bool {
        d == 1001 && (n == 30000 || n == 60000)
    }

    public var allowsDropFrame: Bool { Self.dropFrameAllowed(numerator, denominator) }
    public var fps: Double { Double(numerator) / Double(denominator) }
    /// The frame count per timecode second (30 for 29.97).
    public var nominalFPS: Int { max(Int(fps.rounded()), 1) }
    public var id: String { key }

    /// Stable text form, e.g. "25/1" or "30000/1001 DF".
    public var key: String { "\(numerator)/\(denominator)" + (dropFrame ? " DF" : "") }

    public init?(key: String) {
        let parts = key.trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard let fraction = parts.first else { return nil }
        let nd = fraction.split(separator: "/")
        guard nd.count == 2, let n = Int(nd[0]), let d = Int(nd[1]), n > 0, d > 0 else { return nil }
        self.init(numerator: n, denominator: d, dropFrame: parts.count > 1 && parts[1].uppercased() == "DF")
    }

    /// "25", "29.97", "29.97 DF", "23.976".
    public var label: String {
        var text: String
        if denominator == 1 {
            text = "\(numerator)"
        } else {
            text = String(format: "%.3f", fps)
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return dropFrame ? text + " DF" : text
    }

    public var description: String { label }

    public func frames(seconds: Double) -> Int {
        Int((seconds * Double(numerator) / Double(denominator)).rounded())
    }

    public func seconds(frames: Int) -> Double {
        Double(frames) * Double(denominator) / Double(numerator)
    }

    // Presets
    public static let r23976 = FrameRate(numerator: 24000, denominator: 1001)
    public static let r24 = FrameRate(numerator: 24)
    public static let r25 = FrameRate(numerator: 25)
    public static let r2997 = FrameRate(numerator: 30000, denominator: 1001)
    public static let r2997DF = FrameRate(numerator: 30000, denominator: 1001, dropFrame: true)
    public static let r30 = FrameRate(numerator: 30)
    public static let r48 = FrameRate(numerator: 48)
    public static let r50 = FrameRate(numerator: 50)
    public static let r5994 = FrameRate(numerator: 60000, denominator: 1001)
    public static let r5994DF = FrameRate(numerator: 60000, denominator: 1001, dropFrame: true)
    public static let r60 = FrameRate(numerator: 60)

    public static let presets: [FrameRate] = [r23976, r24, r25, r2997, r2997DF, r30, r48, r50, r5994, r5994DF, r60]

    /// A typed rate ("12.5", "29.97", "120"). 1000/1001 rates are recognised; anything else is
    /// kept exactly to three decimals. Returns nil outside 1–1000 fps.
    public static func custom(_ fps: Double) -> FrameRate? {
        guard fps.isFinite, fps >= 1, fps <= 1000 else { return nil }
        for base in [24, 30, 48, 60, 120, 240] {
            if abs(fps - Double(base) * 1000 / 1001) < 0.002 {
                return FrameRate(numerator: base * 1000, denominator: 1001)
            }
        }
        if abs(fps - fps.rounded()) < 0.0005 { return FrameRate(numerator: Int(fps.rounded())) }
        return FrameRate(numerator: Int((fps * 1000).rounded()), denominator: 1000)
    }

    /// The preset nearest a decimal rate (for older shows that stored fps as a number).
    public static func closest(to fps: Double) -> FrameRate {
        let nonDrop = presets.filter { !$0.dropFrame }
        return nonDrop.min { abs($0.fps - fps) < abs($1.fps - fps) } ?? r25
    }
}

extension FrameRate {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(numerator: try c.value("numerator", 25),
                  denominator: try c.value("denominator", 1),
                  dropFrame: try c.value("dropFrame", false))
    }
}

// MARK: - Timecode

/// Frame counts to and from "HH:MM:SS:FF" (";" before the frames for drop-frame).
public enum Timecode {
    private static func two(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }

    public static func string(frames: Int, rate: FrameRate) -> String {
        let n = rate.nominalFPS
        var f = max(frames, 0)
        if rate.dropFrame {
            let drop = n / 15                 // 2 at 29.97, 4 at 59.94
            let perTenMinutes = n * 600 - drop * 9
            let perMinute = n * 60 - drop
            let tens = f / perTenMinutes
            let rest = f % perTenMinutes
            f += drop * 9 * tens
            if rest > drop { f += drop * ((rest - drop) / perMinute) }
        }
        let ff = f % n
        let total = f / n
        let ss = total % 60
        let mm = (total / 60) % 60
        let hh = (total / 3600) % 24
        let sep = rate.dropFrame ? ";" : ":"
        return two(hh) + ":" + two(mm) + ":" + two(ss) + sep + two(ff)
    }

    /// Nil for text that is not a valid timecode at this rate (including frames a drop-frame
    /// count skips, like 00:01:00;00).
    public static func frames(_ text: String, rate: FrameRate) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(whereSeparator: { $0 == ":" || $0 == ";" || $0 == "." }).map { Int($0) }
        guard parts.count == 4, let hh = parts[0], let mm = parts[1], let ss = parts[2], let ff = parts[3] else { return nil }
        let n = rate.nominalFPS
        guard hh >= 0, hh < 24, mm >= 0, mm < 60, ss >= 0, ss < 60, ff >= 0, ff < n else { return nil }
        var total = ((hh * 60 + mm) * 60 + ss) * n + ff
        if rate.dropFrame {
            let drop = n / 15
            if ss == 0 && mm % 10 != 0 && ff < drop { return nil }
            let minutes = hh * 60 + mm
            total -= drop * (minutes - minutes / 10)
        }
        return total
    }
}

// MARK: - Tempo map

/// Ticks to time for a bars-and-beats scene. Constant tempo for now (the scene's BPM);
/// tempo changes inside a song arrive with the Phase 2 timeline.
public struct TempoMap: Hashable {
    public static let ticksPerBeat = 960
    public var bpm: Double
    public var beatsPerBar: Int

    public init(bpm: Double, beatsPerBar: Int) {
        self.bpm = max(bpm, 1)
        self.beatsPerBar = max(beatsPerBar, 1)
    }

    public func ticks(beats: Double) -> Int { Int((beats * Double(Self.ticksPerBeat)).rounded()) }
    public func beats(ticks: Int) -> Double { Double(ticks) / Double(Self.ticksPerBeat) }
    public func seconds(ticks: Int) -> Double { beats(ticks: ticks) * 60 / bpm }
    public func ticks(seconds: Double) -> Int { ticks(beats: seconds * bpm / 60) }

    /// 1-based bar and beat, and the ticks past that beat.
    public func barBeat(ticks: Int) -> (bar: Int, beat: Int, tick: Int) {
        let t = max(ticks, 0)
        let perBar = Self.ticksPerBeat * beatsPerBar
        return (t / perBar + 1, (t % perBar) / Self.ticksPerBeat + 1, t % Self.ticksPerBeat)
    }
}

// MARK: - Scene metadata

public enum SceneStatus: String, Codable, CaseIterable, Identifiable {
    case unset = "none", draft, wip, ok, nok
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .unset: return "None"
        case .draft: return "Draft"
        case .wip: return "WIP"
        case .ok: return "OK"
        case .nok: return "NOK"
        }
    }
}

public enum NumberingMode: String, Codable, CaseIterable, Identifiable {
    case automatic, fixed, fixedWithSuffix
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .automatic: return "Automatic (follows the order)"
        case .fixed: return "Fixed"
        case .fixedWithSuffix: return "Fixed, inserts get 3a, 3b"
        }
    }
}

/// Track types a new scene can start with.
public enum SceneTrackKind: String, Codable, CaseIterable, Identifiable {
    case arrangement, edit, cues, audio, switcherEffects, triggers, mediaPlayer, cameraControl, lyrics, notes, showControl
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .arrangement: return "Arrangement"
        case .edit: return "Edit"
        case .cues: return "Cues"
        case .audio: return "Audio"
        case .switcherEffects: return "Switcher Effects"
        case .triggers: return "Triggers"
        case .mediaPlayer: return "Media Player Control"
        case .cameraControl: return "Camera Control"
        case .lyrics: return "Lyrics"
        case .notes: return "Notes"
        case .showControl: return "Show Control"
        }
    }

    /// The timeline lane this becomes. Arrangement and Audio are built into every scene.
    public var trackKind: TrackKind? {
        switch self {
        case .edit: return .shots
        case .switcherEffects: return .fx
        case .triggers: return .osc
        case .cameraControl: return .ptz
        case .lyrics: return .lyrics
        case .notes: return .notes
        case .showControl: return .control
        case .cues: return .calls
        case .mediaPlayer: return .player
        case .arrangement, .audio: return nil
        }
    }

    public var hasLaneToday: Bool { trackKind != nil || self == .arrangement || self == .audio }
}

public struct DefaultTrack: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var kind: SceneTrackKind
    /// Output an Edit track drives; nil = the main output.
    public var routeTo: UUID?

    public init(kind: SceneTrackKind, routeTo: UUID? = nil) {
        self.kind = kind
        self.routeTo = routeTo
    }
}

public struct SceneDefaults: Codable, Hashable {
    public var startTimecode: String = "01:00:00:00"
    public var durationSeconds: Int = 180
    public var timecodeChase: Bool = false
    public var numberingMode: NumberingMode = .automatic
    public var numberingFrom: Int = 1
    public var tracks: [DefaultTrack] = SceneDefaults.standardTracks

    public init() {}

    public static let standardTracks: [DefaultTrack] = [
        .arrangement, .edit, .cues, .audio, .switcherEffects, .triggers, .mediaPlayer, .cameraControl, .lyrics,
    ].map { DefaultTrack(kind: $0) }
}

public struct ProjectRole: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public init(name: String) { self.name = name }

    public static let standard: [String] = [
        "Video", "Audio", "Lights", "SFX", "Staging", "Props", "Director", "Vision Mixer", "Camera Ops", "Producer",
    ]
}

public struct ProjectProperties: Codable, Hashable {
    public var sceneDefaults = SceneDefaults()
    public var roles: [ProjectRole] = ProjectRole.standard.map { ProjectRole(name: $0) }
    /// Shot sizes, movements, framings, cast, statuses and transitions for this project.
    public var shots = ShotVocabulary()
    public var countdown = CountdownSettings()
    public init() {}
}

// MARK: - Playlist and project

public struct Playlist: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var items: [RundownItem] = []
    public var notes: String = ""

    public init(name: String, items: [RundownItem] = []) {
        self.name = name
        self.items = items
    }
}

/// A named snapshot of the whole project, kept in the project ("Before rehearsal", "As run, night 2").
public struct ProjectVersion: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var date: Date
    public var automatic: Bool
    /// Why an automatic version was taken ("Saved", "Before Live Mode", "Before renumbering").
    public var reason: String
    public var author: String
    /// LZFSE-compressed JSON of the project, versions left out.
    public var data: Data

    public init(name: String, date: Date, automatic: Bool, reason: String, author: String, data: Data) {
        self.name = name
        self.date = date
        self.automatic = automatic
        self.reason = reason
        self.author = author
        self.data = data
    }
}

public struct Project: Identifiable, Codable, Hashable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int = Project.currentSchemaVersion
    public var id = UUID()
    public var name: String = "New Project"
    public var artist: String = ""
    public var venue: String = ""
    public var showDate: Date?
    public var frameRate: FrameRate = .r25
    public var createdAt = Date()
    public var editedAt = Date()

    // Rig, shared by every playlist
    public var cameras: [Camera] = []
    public var switchers: [SwitcherConfig] = []
    public var outputs: [OutputConfig] = []
    public var oscTargets: [OSCTarget] = []
    public var ptzCameras: [PTZCamera] = []
    public var midiBindings: [MIDIBinding] = []
    public var settings = ShowSettings()
    public var plot = CameraPlot()
    public var comments: [Comment] = []

    public var playlists: [Playlist] = []
    public var properties = ProjectProperties()
    public var versions: [ProjectVersion] = []

    public init() {}

    public var sceneCount: Int { playlists.reduce(0) { $0 + $1.items.count } }

    public func playlist(_ id: UUID?) -> Playlist? {
        guard let id else { return nil }
        return playlists.first { $0.id == id }
    }

    /// A new project with one playlist and one scene built from the project's scene defaults.
    public static func starter(name: String, frameRate: FrameRate) -> Project {
        var p = Project()
        p.name = name
        p.frameRate = frameRate
        p.settings.ltcFPS = frameRate.fps
        let sim = SwitcherConfig(name: "Simulator", kind: .simulator, role: .main)
        p.switchers = [sim]
        p.outputs = [OutputConfig(name: "Program", switcherID: sim.id)]
        p.cameras = (1...4).map { Camera(number: $0, switcherID: sim.id, input: $0) }
        p.midiBindings = MIDIBinding.apc40Defaults()
        var playlist = Playlist(name: "Show")
        playlist.items = [p.newScene(title: "Scene 1", number: "1", kind: .song)]
        p.playlists = [playlist]
        return p
    }

    /// A scene built from the scene defaults: its tracks, length, start timecode and chase.
    public func newScene(title: String, number: String, kind: ItemKind, startTimecode: String? = nil) -> RundownItem {
        let defaults = properties.sceneDefaults
        var item = RundownItem(kind: kind, title: title,
                               timeBase: kind == .song ? .bars : .seconds,
                               syncMode: defaults.timecodeChase ? .ltc : (kind == .song ? .tap : .freeRun))
        item.number = number
        item.plannedDuration = Double(defaults.durationSeconds)
        item.ltcStart = startTimecode ?? (defaults.timecodeChase ? defaults.startTimecode : "")
        if kind == .song, defaults.tracks.contains(where: { $0.kind == .arrangement }) {
            item.sections = [SongSection(name: "Intro", at: 0)]
        }
        let main = outputs.first
        for t in defaults.tracks {
            guard let lane = t.kind.trackKind else { continue }
            switch lane {
            case .shots:
                let out = outputs.first { $0.id == t.routeTo } ?? main
                item.tracks.append(Track(kind: .shots, name: "\(out?.name ?? "Program") shots", outputID: out?.id))
            case .fx:
                item.tracks.append(Track(kind: .fx, name: t.kind.label, switcherID: main?.switcherID))
            default:
                item.tracks.append(Track(kind: lane, name: t.kind.label))
            }
        }
        // Every output still gets a shots track, as before.
        for out in outputs where !item.tracks.contains(where: { $0.kind == .shots && $0.outputID == out.id }) {
            item.tracks.insert(Track(kind: .shots, name: "\(out.name) shots", outputID: out.id), at: 0)
        }
        return item
    }

    // MARK: Bridge to the editor and engine

    /// The editor and Live engine work on a `Show`: the rig plus one playlist's scenes.
    public func show(playlist id: UUID?) -> Show {
        var s = Show()
        let list = playlist(id) ?? playlists.first
        s.id = list?.id ?? self.id
        s.name = name
        s.cameras = cameras
        s.switchers = switchers
        s.outputs = outputs
        s.items = list?.items ?? []
        s.oscTargets = oscTargets
        s.ptzCameras = ptzCameras
        s.comments = comments
        s.midiBindings = midiBindings
        s.settings = settings
        s.settings.ltcFPS = frameRate.fps
        s.plot = plot
        return s
    }

    /// Writes an edited `Show` back: the rig, and the scenes of that playlist (positions kept on
    /// the frame or tick grid).
    public mutating func apply(_ show: Show, playlist id: UUID) {
        cameras = show.cameras
        switchers = show.switchers
        outputs = show.outputs
        oscTargets = show.oscTargets
        ptzCameras = show.ptzCameras
        comments = show.comments
        midiBindings = show.midiBindings
        settings = show.settings
        settings.ltcFPS = frameRate.fps
        plot = show.plot
        if let i = playlists.firstIndex(where: { $0.id == id }) {
            var items = show.items
            for k in items.indices { items[k].quantizePositions(projectRate: frameRate) }
            playlists[i].items = items
        }
        editedAt = Date()
    }

    /// Keeps every scene's positions on its grid.
    public mutating func quantizePositions() {
        for p in playlists.indices {
            for k in playlists[p].items.indices { playlists[p].items[k].quantizePositions(projectRate: frameRate) }
        }
    }

    // MARK: Migration from a schema 0/1 show

    /// A schema 0/1 show becomes a project with one playlist named after the show. Scenes are
    /// numbered in order; positions snap to the nearest frame (timecode scenes) or tick (bars).
    public init(migrating show: Show) {
        self.init()
        id = UUID()
        name = show.name
        frameRate = FrameRate.closest(to: show.settings.ltcFPS)
        cameras = show.cameras
        switchers = show.switchers
        outputs = show.outputs
        oscTargets = show.oscTargets
        ptzCameras = show.ptzCameras
        midiBindings = show.midiBindings
        settings = show.settings
        settings.ltcFPS = frameRate.fps
        plot = show.plot
        comments = show.comments
        var playlist = Playlist(name: show.name)
        playlist.id = show.id
        playlist.items = show.items
        for k in playlist.items.indices {
            if playlist.items[k].number.isEmpty { playlist.items[k].number = "\(k + 1)" }
            playlist.items[k].quantizePositions(projectRate: frameRate)
        }
        playlists = [playlist]
    }

    /// Adds a schema 0/1 show to this project as a new playlist. Its rig is not merged: cameras
    /// are matched by number, and any camera this project lacks is added.
    public mutating func addPlaylist(from show: Show) -> UUID {
        var map: [UUID: UUID] = [:]
        for cam in show.cameras {
            if let existing = cameras.first(where: { $0.number == cam.number }) {
                map[cam.id] = existing.id
            } else {
                cameras.append(cam)
                map[cam.id] = cam.id
            }
        }
        var playlist = Playlist(name: show.name)
        playlist.items = show.items
        for k in playlist.items.indices {
            if playlist.items[k].number.isEmpty { playlist.items[k].number = "\(k + 1)" }
            for t in playlist.items[k].tracks.indices {
                for c in playlist.items[k].tracks[t].cues.indices {
                    if let cam = playlist.items[k].tracks[t].cues[c].cameraID, let mapped = map[cam] {
                        playlist.items[k].tracks[t].cues[c].cameraID = mapped
                    }
                }
            }
            playlist.items[k].quantizePositions(projectRate: frameRate)
        }
        playlists.append(playlist)
        editedAt = Date()
        return playlist.id
    }
}

// MARK: - Positions on the grid

extension RundownItem {
    /// Frames per second (timecode scenes) or ticks per beat (bars scenes); nil for order scenes,
    /// whose positions are a running order rather than a time.
    public func positionScale(projectRate: FrameRate) -> Double? {
        switch timeBase {
        case .bars: return Double(TempoMap.ticksPerBeat)
        case .seconds: return (frameRate ?? projectRate).fps
        case .order: return nil
        }
    }

    public var tempoMap: TempoMap { TempoMap(bpm: bpm, beatsPerBar: beatsPerBar) }

    /// Rounds every section and cue position to the nearest frame or tick, and the planned
    /// length to the nearest frame.
    public mutating func quantizePositions(projectRate: FrameRate) {
        let rate = frameRate ?? projectRate
        plannedDuration = rate.seconds(frames: rate.frames(seconds: plannedDuration))
        guard let scale = positionScale(projectRate: projectRate) else { return }
        for i in sections.indices { sections[i].at = (sections[i].at * scale).rounded() / scale }
        for t in tracks.indices {
            for c in tracks[t].cues.indices { tracks[t].cues[c].at = (tracks[t].cues[c].at * scale).rounded() / scale }
        }
    }
}
