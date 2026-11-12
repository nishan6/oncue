import Foundation

// Backward-compatible decoding for every show type.
//
// Swift's synthesized `Decodable` rejects a file the moment one key is missing, so the first new
// field added to the model would make every existing show file unreadable. Each type below decodes
// field by field: a missing field gets the same default as the property declaration, and an enum
// value this build does not know (written by a newer OnCue) falls back to a safe default instead of
// failing the whole file. Encoding stays compiler-synthesized, so key names here must match the
// property names exactly; `PersistenceTests.testEveryFieldSurvivesRoundTrip` guards that.

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(_ string: String) { stringValue = string; intValue = nil }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

extension KeyedDecodingContainer where K == AnyCodingKey {
    /// Decodes `key`, or returns `fallback` when the key is missing or null.
    /// A present value of the wrong type still throws: that is corruption, not an old file.
    func value<T: Decodable>(_ key: String, _ fallback: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(T.self, forKey: AnyCodingKey(key)) ?? fallback()
    }

    func optional<T: Decodable>(_ key: String) throws -> T? {
        try decodeIfPresent(T.self, forKey: AnyCodingKey(key))
    }

    /// String-backed enum with a fallback for missing or unknown values.
    func enumValue<E: RawRepresentable>(_ key: String, _ fallback: E) throws -> E where E.RawValue == String {
        guard let raw = try decodeIfPresent(String.self, forKey: AnyCodingKey(key)) else { return fallback }
        return E(rawValue: raw) ?? fallback
    }

    /// Optional string-backed enum: missing or unknown values become nil.
    func optionalEnum<E: RawRepresentable>(_ key: String) throws -> E? where E.RawValue == String {
        guard let raw = try decodeIfPresent(String.self, forKey: AnyCodingKey(key)) else { return nil }
        return E(rawValue: raw)
    }
}

extension Camera {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(number: try c.value("number", 0))
        id = try c.value("id", UUID())
        name = try c.value("name", "")
        operatorName = try c.value("operatorName", "")
        switcherID = try c.optional("switcherID")
        input = try c.value("input", 0)
        ptzID = try c.optional("ptzID")
        color = try c.value("color", "")
        extraInputs = try c.value("extraInputs", [])
    }
}

extension CompanionButton {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        page = try c.value("page", 1)
        row = try c.value("row", 0)
        column = try c.value("column", 0)
        bank = try c.value("bank", 1)
        enabled = try c.value("enabled", false)
    }
}

extension CompanionInputButtons {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(input: try c.value("input", 0))
        preview = try c.value("preview", CompanionButton())
        program = try c.value("program", CompanionButton())
    }
}

extension CompanionMapping {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        inputs = try c.value("inputs", [])
        cut = try c.value("cut", CompanionButton())
        auto = try c.value("auto", CompanionButton())
    }
}

extension SwitcherConfig {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Switcher"))
        id = try c.value("id", UUID())
        kind = try c.enumValue("kind", .simulator)
        host = try c.value("host", "")
        me = try c.value("me", 0)
        role = try c.enumValue("role", .main)
        parentID = try c.optional("parentID")
        feedInput = try c.value("feedInput", 0)
        companion = try c.value("companion", CompanionMapping())
        inputCount = try c.value("inputCount", 20)
    }
}

extension OutputConfig {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Output"))
        id = try c.value("id", UUID())
        switcherID = try c.optional("switcherID")
        bus = try c.enumValue("bus", .program)
        auxIndex = try c.value("auxIndex", 0)
        mirrorMain = try c.value("mirrorMain", false)
    }
}

extension SongSection {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Section"), at: try c.value("at", 0.0))
        id = try c.value("id", UUID())
    }
}

extension Cue {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(at: try c.value("at", 0.0))
        id = try c.value("id", UUID())
        cameraID = try c.optional("cameraID")
        text = try c.value("text", "")
        note = try c.value("note", "")
        transition = try c.enumValue("transition", .cut)
        fxAction = try c.optionalEnum("fxAction")
        fxIndex = try c.value("fxIndex", 0)
        fxValue = try c.value("fxValue", 0)
        controlAction = try c.optionalEnum("controlAction")
        jumpItemID = try c.optional("jumpItemID")
        oscTargetID = try c.optional("oscTargetID")
        oscAddress = try c.value("oscAddress", "")
        oscArgs = try c.value("oscArgs", "")
        ptzCameraID = try c.optional("ptzCameraID")
        ptzPreset = try c.value("ptzPreset", 1)
    }
}

extension Track {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        // An unknown track kind from a newer OnCue is kept as notes so its cues are not lost.
        self.init(kind: try c.enumValue("kind", .notes), name: try c.value("name", "Track"))
        id = try c.value("id", UUID())
        outputID = try c.optional("outputID")
        switcherID = try c.optional("switcherID")
        cues = try c.value("cues", [])
        muted = try c.value("muted", false)
    }
}

extension RundownItem {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(title: try c.value("title", "Untitled"))
        id = try c.value("id", UUID())
        kind = try c.enumValue("kind", .song)
        timeBase = try c.enumValue("timeBase", .bars)
        syncMode = try c.enumValue("syncMode", .tap)
        bpm = try c.value("bpm", 120.0)
        beatsPerBar = try c.value("beatsPerBar", 4)
        ltcStart = try c.value("ltcStart", "")
        plannedDuration = try c.value("plannedDuration", 0.0)
        hardOut = try c.value("hardOut", "")
        sections = try c.value("sections", [])
        tracks = try c.value("tracks", [])
        notes = try c.value("notes", "")
        media = try c.value("media", ItemMedia?.none)
    }
}

extension OSCTarget {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "OSC target"))
        id = try c.value("id", UUID())
        host = try c.value("host", "127.0.0.1")
        port = try c.value("port", 7000)
    }
}

extension PTZCamera {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "PTZ"))
        id = try c.value("id", UUID())
        proto = try c.enumValue("proto", .viscaIP)
        host = try c.value("host", "")
        port = try c.value("port", 52381)
        macroBase = try c.value("macroBase", 0)
        switcherID = try c.optional("switcherID")
        companionStart = try c.value("companionStart", CompanionButton())
    }
}

extension MIDIBinding {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        // An unknown command from a newer OnCue becomes "stop", the safest action, and is
        // never bound to a camera.
        self.init(command: try c.enumValue("command", .stop))
        id = try c.value("id", UUID())
        cameraNumber = try c.value("cameraNumber", 0)
        channel = try c.value("channel", 0)
        number = try c.value("number", 0)
        isCC = try c.value("isCC", false)
    }
}

extension MonitorConfig {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Monitor"))
        id = try c.value("id", UUID())
        kind = try c.enumValue("kind", .gallery)
        cameraIDs = try c.value("cameraIDs", [])
        screenName = try c.value("screenName", "")
    }
}

extension Comment {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(author: try c.value("author", ""), text: try c.value("text", ""))
        id = try c.value("id", UUID())
        itemID = try c.optional("itemID")
        cueID = try c.optional("cueID")
        date = try c.value("date", Date(timeIntervalSince1970: 0))
        resolved = try c.value("resolved", false)
    }
}

extension ShowSettings {
    public init(from decoder: Decoder) throws {
        // Schema 0 files also carry per-Mac keys (MIDI ports, LTC device, crew interface...).
        // They are deliberately ignored here: opening a show never changes this Mac's profile.
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        ltcFPS = try c.value("ltcFPS", 25.0)
        minShotSeconds = try c.value("minShotSeconds", 1.5)
        unusedCameraMinutes = try c.value("unusedCameraMinutes", 10.0)
        manualCutWindow = try c.value("manualCutWindow", 0.4)
        monitors = try c.value("monitors", [])
        nightLabel = try c.value("nightLabel", "")
    }
}

extension Show {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        // Files written before versioning have no schemaVersion: they are schema 0.
        schemaVersion = try c.value("schemaVersion", 0)
        id = try c.value("id", UUID())
        name = try c.value("name", "Untitled show")
        cameras = try c.value("cameras", [])
        switchers = try c.value("switchers", [])
        outputs = try c.value("outputs", [])
        items = try c.value("items", [])
        oscTargets = try c.value("oscTargets", [])
        ptzCameras = try c.value("ptzCameras", [])
        comments = try c.value("comments", [])
        midiBindings = try c.value("midiBindings", [])
        settings = try c.value("settings", ShowSettings())
        plot = try c.value("plot", CameraPlot())
        recorders = try c.value("recorders", [])
        versions = try c.value("versions", [])
    }
}
