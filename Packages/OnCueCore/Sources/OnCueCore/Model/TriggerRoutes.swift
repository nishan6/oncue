import Foundation

// MARK: - Trigger Routes
//
// Incoming triggers (Companion / Stream Deck over OSC, a grandMA3 over OSC, MIDI or Art-Net, the
// band's playback rig over MIDI or MIDI Show Control, a MIDI pedal) mapped to OnCue actions.
// Routes live in the project. Matching is pure and tested here; the engine listens and performs.

/// What kind of message a route listens for.
public enum TriggerInputKind: String, Codable, CaseIterable, Identifiable {
    case osc, midiNote, midiCC, midiProgram, msc, artNet
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .osc: return "OSC"
        case .midiNote: return "MIDI note"
        case .midiCC: return "MIDI CC"
        case .midiProgram: return "MIDI program change"
        case .msc: return "MIDI Show Control"
        case .artNet: return "Art-Net (DMX)"
        }
    }
}

/// MIDI Show Control commands OnCue understands (MSC command byte).
public enum MSCCommand: Int, Codable, CaseIterable, Identifiable {
    case go = 0x01, stop = 0x02, resume = 0x03, timedGo = 0x04, load = 0x05, set = 0x06, fire = 0x07,
         reset = 0x0A, goOff = 0x0B
    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .go: return "GO"
        case .stop: return "STOP"
        case .resume: return "RESUME"
        case .timedGo: return "TIMED GO"
        case .load: return "LOAD"
        case .set: return "SET"
        case .fire: return "FIRE"
        case .reset: return "RESET"
        case .goOff: return "GO OFF"
        }
    }
}

public struct TriggerInput: Codable, Hashable {
    public var kind: TriggerInputKind = .osc
    /// OSC address ("/oncue/go", "/gma3/cue/12"). A trailing "*" matches any ending.
    public var address: String = ""
    /// MIDI channel 1–16; 0 = any channel.
    public var channel: Int = 0
    /// Note, CC number or Art-Net channel (1–512). Unused for program change.
    public var number: Int = 0
    /// MSC command.
    public var msc: MSCCommand = .go
    /// Art-Net universe (port address, 0 = the first universe).
    public var universe: Int = 0
    /// Art-Net and CC: fires when the value rises to this or above (0–255 for DMX, 0–127 for CC).
    public var threshold: Int = 128

    public init(kind: TriggerInputKind = .osc) {
        self.kind = kind
        if kind == .midiCC { threshold = 64 }
    }

    public var summary: String {
        let ch = channel == 0 ? "any ch" : "ch \(channel)"
        switch kind {
        case .osc: return address.isEmpty ? "OSC (no address)" : address
        case .midiNote: return "Note \(number) · \(ch)"
        case .midiCC: return "CC \(number) ≥ \(threshold) · \(ch)"
        case .midiProgram: return "Program change · \(ch)"
        case .msc: return "MSC \(msc.label)"
        case .artNet: return "Art-Net U\(universe) ch \(number) ≥ \(threshold)"
        }
    }
}

/// What a route does.
public enum TriggerActionKind: String, Codable, CaseIterable, Identifiable {
    case command
    case jumpToItem
    case jumpToSection
    case fireCue
    case goLive, stopLive, holdLive
    case pauseChase, resumeChase, toggleChase
    case markNote
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .command: return "Live control"
        case .jumpToItem: return "Jump to song or segment"
        case .jumpToSection: return "Jump to section"
        case .fireCue: return "Fire a shot or cue"
        case .goLive: return "Start Live (GO)"
        case .stopLive: return "Stop Live"
        case .holdLive: return "Hold / release Live"
        case .pauseChase: return "Pause timecode chase"
        case .resumeChase: return "Resume timecode chase"
        case .toggleChase: return "Pause / resume chase"
        case .markNote: return "Mark a rehearsal note"
        }
    }
}

/// Where a song, section or cue target comes from: a fixed target, or the incoming value
/// (a grandMA3 cue number, a program change, an MSC cue number selects song N).
public enum TriggerTargetSource: String, Codable, CaseIterable, Identifiable {
    case fixed, fromValue
    public var id: String { rawValue }
}

public struct TriggerAction: Codable, Hashable {
    public var kind: TriggerActionKind = .command
    public var command: ControlCommand = .next
    /// Camera number for "take camera N" / "preview camera N" (camera override). 0 = from value.
    public var cameraNumber: Int = 0
    public var target: TriggerTargetSource = .fixed
    public var itemID: UUID?
    public var sectionID: UUID?
    public var cueID: UUID?
    /// Text for "mark a note"; empty = "Marked from <input>".
    public var noteText: String = ""
    public init(kind: TriggerActionKind = .command) { self.kind = kind }
}

public struct TriggerRoute: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String = ""
    public var enabled = true
    public var input = TriggerInput()
    public var action = TriggerAction()
    public init(name: String = "", input: TriggerInput = TriggerInput(), action: TriggerAction = TriggerAction()) {
        self.name = name
        self.input = input
        self.action = action
    }
}

/// One message as it arrived.
public struct TriggerEvent: Equatable {
    public var kind: TriggerInputKind
    public var address: String = ""
    /// 1–16
    public var channel: Int = 0
    public var number: Int = 0
    /// Velocity, CC value, program number, DMX level, first OSC argument, or MSC cue number.
    public var value: Double?
    public var msc: MSCCommand?
    public var universe: Int = 0

    public init(kind: TriggerInputKind, address: String = "", channel: Int = 0, number: Int = 0,
                value: Double? = nil, msc: MSCCommand? = nil, universe: Int = 0) {
        self.kind = kind
        self.address = address
        self.channel = channel
        self.number = number
        self.value = value
        self.msc = msc
        self.universe = universe
    }

    public var summary: String {
        switch kind {
        case .osc: return address + (value.map { " \(TriggerEvent.short($0))" } ?? "")
        case .midiNote: return "Note \(number) vel \(Int(value ?? 0)) · ch \(channel)"
        case .midiCC: return "CC \(number) = \(Int(value ?? 0)) · ch \(channel)"
        case .midiProgram: return "Program \(Int(value ?? 0)) · ch \(channel)"
        case .msc: return "MSC \(msc?.label ?? "?")" + (value.map { " cue \(TriggerEvent.short($0))" } ?? "")
        case .artNet: return "Art-Net U\(universe) ch \(number) = \(Int(value ?? 0))"
        }
    }

    static func short(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }
}

/// A route that fired, with the value it carried.
public struct TriggerMatch: Equatable {
    public var route: TriggerRoute
    public var value: Double?
}

/// Matches incoming events against routes. Keeps the last level of each CC and DMX channel so
/// a fader or a held button fires once as it crosses its threshold, not on every update.
public struct TriggerRouter {
    public private(set) var routes: [TriggerRoute]
    private var levels: [String: Double] = [:]

    public init(routes: [TriggerRoute]) { self.routes = routes }

    public mutating func update(routes: [TriggerRoute]) { self.routes = routes }

    public mutating func match(_ event: TriggerEvent) -> [TriggerMatch] {
        var out: [TriggerMatch] = []
        // Edge detection is per input, shared by every route listening to it.
        var previous: Double?
        var levelKey: String?
        if event.kind == .midiCC { levelKey = "cc:\(event.channel):\(event.number)" }
        if event.kind == .artNet { levelKey = "dmx:\(event.universe):\(event.number)" }
        if let levelKey {
            previous = levels[levelKey]
            levels[levelKey] = event.value ?? 0
        }
        for route in routes where route.enabled && Self.inputMatches(route.input, event, previous: previous) {
            out.append(TriggerMatch(route: route, value: event.value))
        }
        return out
    }

    static func inputMatches(_ input: TriggerInput, _ e: TriggerEvent, previous: Double?) -> Bool {
        guard input.kind == e.kind else { return false }
        let channelOK = input.channel == 0 || input.channel == e.channel
        switch input.kind {
        case .osc:
            let pattern = input.address.trimmingCharacters(in: .whitespaces)
            guard !pattern.isEmpty else { return false }
            if pattern.hasSuffix("*") { return e.address.hasPrefix(String(pattern.dropLast())) }
            return e.address == pattern
        case .midiNote:
            return channelOK && input.number == e.number && (e.value ?? 0) > 0
        case .midiCC:
            guard channelOK, input.number == e.number else { return false }
            let now = e.value ?? 0, before = previous ?? 0
            return now >= Double(input.threshold) && before < Double(input.threshold)
        case .midiProgram:
            return channelOK
        case .msc:
            return e.msc == input.msc
        case .artNet:
            guard input.universe == e.universe, input.number == e.number else { return false }
            let now = e.value ?? 0, before = previous ?? 0
            return now >= Double(input.threshold) && before < Double(input.threshold)
        }
    }
}

// MARK: - Validation

public struct TriggerIssue: Equatable, Identifiable {
    public enum Level: String { case error, warning }
    public var id: String { "\(routeID)-\(message)" }
    public var routeID: UUID
    public var level: Level
    public var message: String
}

extension Project {
    /// Problems with the project's trigger routes: missing targets, bad addresses and ranges,
    /// and two routes listening to the same input.
    public func triggerIssues() -> [TriggerIssue] {
        var issues: [TriggerIssue] = []
        let items = playlists.flatMap(\.items)
        let cueIDs = Set(items.flatMap { $0.tracks.flatMap { $0.cues.map(\.id) } })
        var seen: [String: UUID] = [:]
        for r in properties.triggerRoutes {
            func add(_ level: TriggerIssue.Level, _ m: String) { issues.append(TriggerIssue(routeID: r.id, level: level, message: m)) }
            let i = r.input
            switch i.kind {
            case .osc:
                if !i.address.hasPrefix("/") { add(.error, "OSC addresses start with “/”") }
            case .midiNote, .midiCC:
                if !(0...127).contains(i.number) { add(.error, "MIDI numbers run 0–127") }
            case .artNet:
                if !(1...512).contains(i.number) { add(.error, "DMX channels run 1–512") }
                if !(1...255).contains(i.threshold) { add(.error, "The level runs 1–255") }
            default: break
            }
            if i.kind == .midiCC, !(1...127).contains(i.threshold) { add(.error, "The level runs 1–127") }
            if !(0...16).contains(i.channel) { add(.error, "MIDI channels run 1–16") }

            let a = r.action
            if a.target == .fixed {
                switch a.kind {
                case .jumpToItem:
                    if let id = a.itemID { if !items.contains(where: { $0.id == id }) { add(.error, "That song or segment was deleted") } }
                    else { add(.error, "Choose a song or segment") }
                case .jumpToSection:
                    if let id = a.sectionID { if !items.contains(where: { $0.sections.contains { $0.id == id } }) { add(.error, "That section was deleted") } }
                    else { add(.error, "Choose a section") }
                case .fireCue:
                    if let id = a.cueID { if !cueIDs.contains(id) { add(.error, "That shot or cue was deleted") } }
                    else { add(.error, "Choose a shot or cue") }
                default: break
                }
            } else if [.jumpToItem, .jumpToSection, .fireCue].contains(a.kind), r.input.kind == .midiNote {
                add(.warning, "The note's velocity picks the target; a program change or a cue number is usually meant")
            }
            if a.kind == .command, a.command.needsCamera, a.cameraNumber == 0, r.input.kind == .midiNote {
                add(.warning, "Camera number comes from the note's velocity")
            }
            if r.enabled {
                let key = Self.inputKey(i)
                if let other = seen[key], other != r.id {
                    add(.warning, "Another route listens to the same input; both will fire")
                } else {
                    seen[key] = r.id
                }
            }
        }
        return issues
    }

    static func inputKey(_ i: TriggerInput) -> String {
        switch i.kind {
        case .osc: return "osc:\(i.address)"
        case .midiNote: return "note:\(i.channel):\(i.number)"
        case .midiCC: return "cc:\(i.channel):\(i.number):\(i.threshold)"
        case .midiProgram: return "pc:\(i.channel)"
        case .msc: return "msc:\(i.msc.rawValue)"
        case .artNet: return "dmx:\(i.universe):\(i.number):\(i.threshold)"
        }
    }

    /// Resolves a value-driven target: song N (1-based, in running order), section N in the
    /// current song, or the Nth shot in the current song.
    public func resolveItem(number: Double?, playlist: UUID?) -> RundownItem? {
        guard let n = number.map({ Int($0.rounded()) }), n >= 1 else { return nil }
        let list = self.playlist(playlist)?.items ?? playlists.first?.items ?? []
        // A scene number that matches wins ("12" is scene 12 even if it is 9th in the order).
        if let byNumber = list.first(where: { $0.number == String(n) }) { return byNumber }
        return n <= list.count ? list[n - 1] : nil
    }
}

// MARK: - Wire formats

public enum MSCParser {
    /// MIDI Show Control: F0 7F <device> 02 <format> <command> [cue number ASCII] … F7.
    /// Returns the command and the cue number, if any.
    public static func parse(_ bytes: [UInt8]) -> (MSCCommand, Double?)? {
        guard bytes.count >= 6, bytes[0] == 0xF0, bytes[1] == 0x7F, bytes[3] == 0x02,
              let command = MSCCommand(rawValue: Int(bytes[5])) else { return nil }
        var digits = ""
        var k = 6
        while k < bytes.count, bytes[k] != 0x00, bytes[k] != 0xF7 {
            let c = bytes[k]
            if (0x30...0x39).contains(c) || c == 0x2E { digits.append(Character(UnicodeScalar(c))) }
            k += 1
        }
        return (command, Double(digits))
    }
}

public enum ArtNetParser {
    /// ArtDmx (opcode 0x5000): returns the 15-bit port address (universe) and the levels.
    public static func parse(_ data: [UInt8]) -> (universe: Int, levels: [UInt8])? {
        let id: [UInt8] = Array("Art-Net".utf8) + [0]
        guard data.count >= 18, Array(data[0..<8]) == id else { return nil }
        let opcode = Int(data[8]) | Int(data[9]) << 8
        guard opcode == 0x5000 else { return nil }
        let universe = Int(data[14]) | (Int(data[15]) & 0x7F) << 8
        let length = Int(data[16]) << 8 | Int(data[17])
        guard length >= 2, length <= 512, data.count >= 18 + length else { return nil }
        return (universe, Array(data[18..<(18 + length)]))
    }
}

// MARK: - Timecode chase

/// What OnCue does when the timecode it follows drops out mid-song.
public enum FreewheelMode: String, Codable, CaseIterable, Identifiable {
    /// Keep running on OnCue's own clock to the end of the song (your choice for shows).
    case untilSongEnd
    /// Keep running for `freewheelSeconds`, then hold.
    case forSeconds
    /// Hold as soon as timecode stops.
    case off
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .untilSongEnd: return "Until the song ends"
        case .forSeconds: return "For a set time"
        case .off: return "Off: hold when timecode stops"
        }
    }
}

public struct ChaseSettings: Codable, Hashable {
    public var freewheel: FreewheelMode = .untilSongEnd
    public var freewheelSeconds: Double = 5
    public init() {}

    /// How long timecode can be silent before OnCue counts it as a dropout.
    public static let dropoutSeconds = 0.25

    /// The position to run at during a dropout, or nil to hold.
    /// - Parameters:
    ///   - last: the position at the last timecode frame and when it arrived.
    ///   - rate: item units per second (beats or seconds).
    ///   - end: the song's end in item units.
    public func freewheelPosition(last: (position: Double, time: Double), now: Double, rate: Double, end: Double) -> Double? {
        let silent = now - last.time
        guard silent > Self.dropoutSeconds else { return nil }
        switch freewheel {
        case .off: return nil
        case .forSeconds:
            let run = min(silent, max(freewheelSeconds, 0))
            return min(last.position + run * rate, end)
        case .untilSongEnd:
            return min(last.position + silent * rate, end)
        }
    }
}
