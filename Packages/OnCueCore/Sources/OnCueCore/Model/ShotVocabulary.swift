import Foundation

// MARK: - Per-project shot vocabulary
//
// Each list starts with the standard terms and can be extended per project (Project Properties ›
// Shots). A shot stores the term's `key`, never its label, so renaming a term relabels every shot
// that uses it. Built-in terms can be renamed but not removed; terms you add can be removed, and
// shots that used a removed term keep the key and show it as "(removed)".

public struct ShotTerm: Identifiable, Codable, Hashable {
    /// Stable key stored in shots ("cu", "push-in", or a UUID string for terms you add).
    public var key: String
    public var label: String
    /// Short form for the shot list and the camera keys ("CU", "PUSH").
    public var short: String
    public var builtIn: Bool
    public var id: String { key }

    public init(key: String, label: String, short: String = "", builtIn: Bool = false) {
        self.key = key
        self.label = label
        self.short = short.isEmpty ? label : short
        self.builtIn = builtIn
    }

    /// A new term you added.
    public static func custom(_ label: String, short: String = "") -> ShotTerm {
        ShotTerm(key: UUID().uuidString, label: label, short: short, builtIn: false)
    }
}

/// How a shot status behaves.
public enum ShotStatusRole: String, Codable, CaseIterable, Identifiable {
    /// In the script, will run.
    case active
    /// Kept in the script but greyed out.
    case cut
    public var id: String { rawValue }
}

public struct ShotStatusTerm: Identifiable, Codable, Hashable {
    public var key: String
    public var label: String
    public var role: ShotStatusRole
    public var builtIn: Bool
    public var id: String { key }

    public init(key: String, label: String, role: ShotStatusRole = .active, builtIn: Bool = false) {
        self.key = key
        self.label = label
        self.role = role
        self.builtIn = builtIn
    }

    public static func custom(_ label: String, role: ShotStatusRole = .active) -> ShotStatusTerm {
        ShotStatusTerm(key: UUID().uuidString, label: label, role: role, builtIn: false)
    }
}

/// The switcher transition a shot asks for. `kind` is how OnCue fires it today (cut, or the
/// switcher's auto transition); `style` is the transition type the shot is scripted with.
public enum TransitionStyleBase: String, Codable, CaseIterable, Identifiable {
    case mix, dip, wipe, dve, stinger
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .mix: return "Mix"
        case .dip: return "Dip"
        case .wipe: return "Wipe"
        case .dve: return "DVE"
        case .stinger: return "Stinger"
        }
    }
}

public struct TransitionTerm: Identifiable, Codable, Hashable {
    public var key: String
    public var label: String
    public var short: String
    /// The switcher transition type underneath (a custom "Push left" is a DVE).
    public var base: TransitionStyleBase
    /// Default length in frames; nil = the switcher's own rate.
    public var durationFrames: Int?
    public var builtIn: Bool
    public var id: String { key }

    public init(key: String, label: String, short: String = "", base: TransitionStyleBase,
                durationFrames: Int? = nil, builtIn: Bool = false) {
        self.key = key
        self.label = label
        self.short = short.isEmpty ? label.uppercased() : short
        self.base = base
        self.durationFrames = durationFrames
        self.builtIn = builtIn
    }

    public static func custom(_ label: String, base: TransitionStyleBase, durationFrames: Int? = nil) -> TransitionTerm {
        TransitionTerm(key: UUID().uuidString, label: label, base: base, durationFrames: durationFrames)
    }
}

public struct ShotVocabulary: Codable, Hashable {
    public var sizes: [ShotTerm] = ShotVocabulary.standardSizes
    public var movements: [ShotTerm] = ShotVocabulary.standardMovements
    public var framings: [ShotTerm] = ShotVocabulary.standardFramings
    /// People and things on stage, per project ("Lead vocal", "Drummer", "Crowd").
    public var cast: [ShotTerm] = []
    public var statuses: [ShotStatusTerm] = ShotVocabulary.standardStatuses
    public var transitions: [TransitionTerm] = ShotVocabulary.standardTransitions

    public init() {}

    public static let standardSizes: [ShotTerm] = [
        ("ecu", "Extreme close-up", "ECU"), ("cu", "Close-up", "CU"), ("mcu", "Medium close-up", "MCU"),
        ("ms", "Medium shot", "MS"), ("mls", "Medium long shot", "MLS"), ("ls", "Long shot", "LS"),
        ("ws", "Wide shot", "WS"), ("ews", "Extreme wide shot", "EWS"),
    ].map { ShotTerm(key: $0.0, label: $0.1, short: $0.2, builtIn: true) }

    public static let standardMovements: [ShotTerm] = [
        ("static", "Static", "STATIC"), ("pan", "Pan", "PAN"), ("tilt", "Tilt", "TILT"),
        ("zoom-in", "Zoom in", "ZOOM IN"), ("zoom-out", "Zoom out", "ZOOM OUT"),
        ("push-in", "Push in", "PUSH"), ("pull-out", "Pull out", "PULL"), ("track", "Track", "TRACK"),
        ("crane-up", "Crane up", "CRANE UP"), ("crane-down", "Crane down", "CRANE DN"),
        ("orbit", "Orbit", "ORBIT"), ("handheld", "Handheld", "HH"), ("whip", "Whip", "WHIP"),
    ].map { ShotTerm(key: $0.0, label: $0.1, short: $0.2, builtIn: true) }

    public static let standardFramings: [ShotTerm] = [
        ("single", "Single", "1S"), ("two-shot", "Two-shot", "2S"), ("group", "Group", "GRP"),
        ("ots", "Over the shoulder", "OTS"), ("profile", "Profile", "PROF"), ("crowd", "Crowd", "CROWD"),
        ("stage-wide", "Stage wide", "STAGE"),
    ].map { ShotTerm(key: $0.0, label: $0.1, short: $0.2, builtIn: true) }

    public static let standardStatuses: [ShotStatusTerm] = [
        ShotStatusTerm(key: "planned", label: "Planned", role: .active, builtIn: true),
        ShotStatusTerm(key: "confirmed", label: "Confirmed", role: .active, builtIn: true),
        ShotStatusTerm(key: "cut", label: "Cut", role: .cut, builtIn: true),
    ]

    public static let standardTransitions: [TransitionTerm] = [
        TransitionTerm(key: "mix", label: "Mix", short: "MIX", base: .mix, builtIn: true),
        TransitionTerm(key: "dip", label: "Dip", short: "DIP", base: .dip, builtIn: true),
        TransitionTerm(key: "wipe", label: "Wipe", short: "WIPE", base: .wipe, builtIn: true),
        TransitionTerm(key: "dve", label: "DVE / push", short: "DVE", base: .dve, builtIn: true),
        TransitionTerm(key: "stinger", label: "Stinger", short: "STING", base: .stinger, builtIn: true),
    ]

    public static let defaultStatusKey = "planned"

    public func size(_ key: String) -> ShotTerm? { sizes.first { $0.key == key } }
    public func movement(_ key: String) -> ShotTerm? { movements.first { $0.key == key } }
    public func framing(_ key: String) -> ShotTerm? { framings.first { $0.key == key } }
    public func castMember(_ key: String) -> ShotTerm? { cast.first { $0.key == key } }
    public func status(_ key: String) -> ShotStatusTerm? { statuses.first { $0.key == key } }
    public func transition(_ key: String) -> TransitionTerm? { transitions.first { $0.key == key } }

    /// A shot whose status has the cut role is greyed out.
    public func isCut(_ cue: Cue) -> Bool { status(cue.shotStatus)?.role == .cut }

    /// Built-in terms are never dropped: anything missing (an older project, or a newer OnCue's
    /// list trimmed by hand) is put back at its standard place.
    public mutating func restoreBuiltIns() {
        sizes = Self.merge(sizes, Self.standardSizes)
        movements = Self.merge(movements, Self.standardMovements)
        framings = Self.merge(framings, Self.standardFramings)
        for s in Self.standardStatuses where !statuses.contains(where: { $0.key == s.key }) {
            statuses.insert(s, at: min(Self.standardStatuses.firstIndex(of: s) ?? 0, statuses.count))
        }
        for t in Self.standardTransitions where !transitions.contains(where: { $0.key == t.key }) {
            transitions.insert(t, at: min(Self.standardTransitions.firstIndex(of: t) ?? 0, transitions.count))
        }
    }

    private static func merge(_ list: [ShotTerm], _ standard: [ShotTerm]) -> [ShotTerm] {
        var out = list
        for (i, s) in standard.enumerated() where !out.contains(where: { $0.key == s.key }) {
            out.insert(s, at: min(i, out.count))
        }
        return out
    }
}

/// A rehearsal note on one shot, kept in the project (Inspector › Reviews). Not shared anywhere.
public struct ShotNote: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var text: String
    public var author: String
    public var date: Date
    public var resolved: Bool = false

    public init(text: String, author: String, date: Date = Date()) {
        self.text = text
        self.author = author
        self.date = date
    }
}

/// When the countdown and the standby warning appear in Live Mode and the transport row.
public struct CountdownSettings: Codable, Hashable {
    /// The next camera's key flashes this many seconds before its cut.
    public var standbySeconds: Double = 5
    public var showNextShot = true
    public var showNextSection = true
    public var showStandby = true
    public init() {}
}
