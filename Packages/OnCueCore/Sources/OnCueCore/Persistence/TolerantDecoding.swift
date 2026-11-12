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
        transitionStyle = try c.value("transitionStyle", "mix")
        transitionFrames = try c.optional("transitionFrames")
        shotSize = try c.value("shotSize", "")
        movement = try c.value("movement", "")
        framing = try c.value("framing", "")
        subjects = try c.value("subjects", [])
        shotStatus = try c.value("shotStatus", ShotVocabulary.defaultStatusKey)
        reviews = try c.value("reviews", [])
        callRole = try c.value("callRole", "")
        playerAction = try c.optionalEnum("playerAction")
        playerName = try c.value("playerName", "")
        clip = try c.value("clip", "")
        jumpTo = try c.value("jumpTo", 0.0)
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
        number = try c.value("number", "")
        artist = try c.value("artist", "")
        status = try c.enumValue("status", SceneStatus.unset)
        frameRate = try c.optional("frameRate")
        if let frames: Int = try c.optional("plannedDurationFrames"), let key: String = try c.optional("frameRateUsed"),
           let rate = FrameRate(key: key) {
            plannedDuration = rate.seconds(frames: frames)
        }
        // Schema 2 stores positions as whole frames or ticks; turn them back into seconds or beats.
        if let unit: String = try c.optional("positionUnit"), let scale: Double = try c.optional("positionScale"), scale > 0 {
            if unit == "frames" || unit == "ticks" {
                for i in sections.indices { sections[i].at /= scale }
                for t in tracks.indices {
                    for k in tracks[t].cues.indices { tracks[t].cues[k].at /= scale }
                }
            }
        }
    }

    // Encoding is written out (not synthesized) so a project file can store positions as whole
    // frames or ticks. Without a project frame rate in the encoder's userInfo (schema 1 shows,
    // version snapshots of shows, the backup link) it writes exactly the synthesized form.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(id, forKey: AnyCodingKey("id"))
        try c.encode(kind, forKey: AnyCodingKey("kind"))
        try c.encode(title, forKey: AnyCodingKey("title"))
        try c.encode(timeBase, forKey: AnyCodingKey("timeBase"))
        try c.encode(syncMode, forKey: AnyCodingKey("syncMode"))
        try c.encode(bpm, forKey: AnyCodingKey("bpm"))
        try c.encode(beatsPerBar, forKey: AnyCodingKey("beatsPerBar"))
        try c.encode(ltcStart, forKey: AnyCodingKey("ltcStart"))
        try c.encode(hardOut, forKey: AnyCodingKey("hardOut"))
        try c.encode(notes, forKey: AnyCodingKey("notes"))
        try c.encodeIfPresent(media, forKey: AnyCodingKey("media"))
        try c.encode(number, forKey: AnyCodingKey("number"))
        try c.encode(artist, forKey: AnyCodingKey("artist"))
        try c.encode(status, forKey: AnyCodingKey("status"))
        try c.encodeIfPresent(frameRate, forKey: AnyCodingKey("frameRate"))

        guard let projectRate = encoder.userInfo[.oncueProjectFrameRate] as? FrameRate else {
            try c.encode(plannedDuration, forKey: AnyCodingKey("plannedDuration"))
            try c.encode(sections, forKey: AnyCodingKey("sections"))
            try c.encode(tracks, forKey: AnyCodingKey("tracks"))
            return
        }
        let rate = frameRate ?? projectRate
        try c.encode(rate.frames(seconds: plannedDuration), forKey: AnyCodingKey("plannedDurationFrames"))
        try c.encode(rate.key, forKey: AnyCodingKey("frameRateUsed"))
        guard let scale = positionScale(projectRate: projectRate) else {
            try c.encode(sections, forKey: AnyCodingKey("sections"))
            try c.encode(tracks, forKey: AnyCodingKey("tracks"))
            return
        }
        // Whole numbers in the file: frames for timecode scenes, ticks for bars scenes.
        var whole = self
        for i in whole.sections.indices { whole.sections[i].at = (whole.sections[i].at * scale).rounded() }
        for t in whole.tracks.indices {
            for k in whole.tracks[t].cues.indices { whole.tracks[t].cues[k].at = (whole.tracks[t].cues[k].at * scale).rounded() }
        }
        try c.encode(timeBase == .bars ? "ticks" : "frames", forKey: AnyCodingKey("positionUnit"))
        try c.encode(scale, forKey: AnyCodingKey("positionScale"))
        try c.encode(whole.sections, forKey: AnyCodingKey("sections"))
        try c.encode(whole.tracks, forKey: AnyCodingKey("tracks"))
    }
}

extension CodingUserInfoKey {
    /// Set by `ProjectCoding`: the project's frame rate, so scenes store whole frames and ticks.
    public static let oncueProjectFrameRate = CodingUserInfoKey(rawValue: "oncue.projectFrameRate")!
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
        versions = try c.value("versions", [])
    }
}
