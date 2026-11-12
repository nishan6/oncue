import Foundation

/// What a file turned out to hold.
public enum ProjectFileContents {
    /// A schema 2 project.
    case project(Project)
    /// A schema 0/1 show, already migrated to schema 1 in memory. The app asks whether to open it
    /// as a new project or add it to an existing one as a playlist.
    case legacyShow(Show)
}

/// Encodes and decodes project files (schema 2) and recognises older show files.
public enum ProjectCoding {
    static func encoder(rate: FrameRate, pretty: Bool) -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        enc.userInfo[.oncueProjectFrameRate] = rate
        return enc
    }

    static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    public static func encode(_ project: Project) throws -> Data {
        var copy = project
        copy.schemaVersion = Project.currentSchemaVersion
        return try encoder(rate: project.frameRate, pretty: true).encode(copy)
    }

    /// Never touches the file on disk. Throws `ShowFileError` with a message for the person at the Mac.
    public static func decode(_ data: Data) throws -> ProjectFileContents {
        guard !data.isEmpty else { throw ShowFileError.empty }
        struct Probe: Decodable { var schemaVersion: Int?; var playlists: [Ignored]? }
        struct Ignored: Decodable {}
        let probe: Probe
        do {
            probe = try decoder().decode(Probe.self, from: data)
        } catch {
            throw ShowFileError.notAShowFile(ShowCoding.describe(error))
        }
        let version = probe.schemaVersion ?? 0
        guard version <= Project.currentSchemaVersion else {
            throw ShowFileError.unsupportedVersion(found: version, supported: Project.currentSchemaVersion)
        }
        if version < 2 && probe.playlists == nil {
            return .legacyShow(try ShowCoding.decode(data))
        }
        do {
            var project = try decoder().decode(Project.self, from: data)
            project.schemaVersion = Project.currentSchemaVersion
            return .project(project)
        } catch {
            throw ShowFileError.invalidContent(ShowCoding.describe(error))
        }
    }

    /// Decodes a file that must be a project (backups, versions).
    public static func decodeProject(_ data: Data) throws -> Project {
        switch try decode(data) {
        case .project(let p): return p
        case .legacyShow(let s): return Project(migrating: s)
        }
    }
}

extension Project {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        schemaVersion = try c.value("schemaVersion", Project.currentSchemaVersion)
        id = try c.value("id", UUID())
        name = try c.value("name", "Untitled project")
        artist = try c.value("artist", "")
        venue = try c.value("venue", "")
        showDate = try c.optional("showDate")
        frameRate = try c.value("frameRate", FrameRate.r25)
        createdAt = try c.value("createdAt", Date(timeIntervalSince1970: 0))
        editedAt = try c.value("editedAt", Date(timeIntervalSince1970: 0))
        cameras = try c.value("cameras", [])
        switchers = try c.value("switchers", [])
        outputs = try c.value("outputs", [])
        oscTargets = try c.value("oscTargets", [])
        ptzCameras = try c.value("ptzCameras", [])
        midiBindings = try c.value("midiBindings", [])
        settings = try c.value("settings", ShowSettings())
        settings.ltcFPS = frameRate.fps
        plot = try c.value("plot", CameraPlot())
        comments = try c.value("comments", [])
        playlists = try c.value("playlists", [])
        media = try c.value("media", [])
        properties = try c.value("properties", ProjectProperties())
        versions = try c.value("versions", [])
    }
}

extension Playlist {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Playlist"))
        id = try c.value("id", UUID())
        items = try c.value("items", [])
        notes = try c.value("notes", "")
    }
}

extension ProjectProperties {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        sceneDefaults = try c.value("sceneDefaults", SceneDefaults())
        roles = try c.value("roles", ProjectRole.standard.map { ProjectRole(name: $0) })
        shots = try c.value("shots", ShotVocabulary())
        countdown = try c.value("countdown", CountdownSettings())
        triggerRoutes = try c.value("triggerRoutes", [])
        chase = try c.value("chase", ChaseSettings())
    }
}

extension ChaseSettings {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        freewheel = try c.enumValue("freewheel", .untilSongEnd)
        freewheelSeconds = try c.value("freewheelSeconds", 5.0)
        preRollSeconds = try c.value("preRollSeconds", 0.0)
    }
}

extension TriggerRoute {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", ""), input: try c.value("input", TriggerInput()), action: try c.value("action", TriggerAction()))
        id = try c.value("id", UUID())
        enabled = try c.value("enabled", true)
    }
}

extension TriggerInput {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(kind: try c.enumValue("kind", .osc))
        address = try c.value("address", "")
        channel = try c.value("channel", 0)
        number = try c.value("number", 0)
        msc = MSCCommand(rawValue: try c.value("msc", MSCCommand.go.rawValue)) ?? .go
        universe = try c.value("universe", 0)
        threshold = try c.value("threshold", kind == .midiCC ? 64 : 128)
    }
}

extension TriggerAction {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(kind: try c.enumValue("kind", .command))
        command = try c.enumValue("command", .next)
        cameraNumber = try c.value("cameraNumber", 0)
        target = try c.enumValue("target", .fixed)
        itemID = try c.optional("itemID")
        sectionID = try c.optional("sectionID")
        cueID = try c.optional("cueID")
        noteText = try c.value("noteText", "")
    }
}

extension ShotVocabulary {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        sizes = try c.value("sizes", ShotVocabulary.standardSizes)
        movements = try c.value("movements", ShotVocabulary.standardMovements)
        framings = try c.value("framings", ShotVocabulary.standardFramings)
        cast = try c.value("cast", [])
        statuses = try c.value("statuses", ShotVocabulary.standardStatuses)
        transitions = try c.value("transitions", ShotVocabulary.standardTransitions)
        restoreBuiltIns()
    }
}

extension ShotTerm {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        let label: String = try c.value("label", "")
        self.init(key: try c.value("key", UUID().uuidString), label: label,
                  short: try c.value("short", label), builtIn: try c.value("builtIn", false))
    }
}

extension ShotStatusTerm {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(key: try c.value("key", UUID().uuidString), label: try c.value("label", ""),
                  role: try c.enumValue("role", .active), builtIn: try c.value("builtIn", false))
    }
}

extension TransitionTerm {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        let label: String = try c.value("label", "")
        self.init(key: try c.value("key", UUID().uuidString), label: label,
                  short: try c.value("short", label.uppercased()), base: try c.enumValue("base", .mix),
                  durationFrames: try c.optional("durationFrames"), builtIn: try c.value("builtIn", false))
    }
}

extension ShotNote {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(text: try c.value("text", ""), author: try c.value("author", ""), date: try c.value("date", Date()))
        id = try c.value("id", UUID())
        resolved = try c.value("resolved", false)
    }
}

extension CountdownSettings {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        standbySeconds = try c.value("standbySeconds", 5.0)
        showNextShot = try c.value("showNextShot", true)
        showNextSection = try c.value("showNextSection", true)
        showStandby = try c.value("showStandby", true)
    }
}

extension SceneDefaults {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        startTimecode = try c.value("startTimecode", "01:00:00:00")
        durationSeconds = try c.value("durationSeconds", 180)
        timecodeChase = try c.value("timecodeChase", false)
        numberingMode = try c.enumValue("numberingMode", NumberingMode.automatic)
        numberingFrom = try c.value("numberingFrom", 1)
        tracks = try c.value("tracks", SceneDefaults.standardTracks)
    }
}

extension DefaultTrack {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        // An unknown track type from a newer OnCue becomes Notes rather than failing the file.
        self.init(kind: try c.enumValue("kind", SceneTrackKind.notes), routeTo: try c.optional("routeTo"))
        id = try c.value("id", UUID())
    }
}

extension ProjectRole {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Role"))
        id = try c.value("id", UUID())
    }
}

extension ProjectVersion {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(name: try c.value("name", "Version"),
                  date: try c.value("date", Date(timeIntervalSince1970: 0)),
                  automatic: try c.value("automatic", false),
                  reason: try c.value("reason", ""),
                  author: try c.value("author", ""),
                  data: try c.value("data", Data()))
        id = try c.value("id", UUID())
    }
}

// MARK: - Versions

extension Project {
    /// Automatic versions kept; named versions are never removed automatically.
    public static let maxAutomaticVersions = 200

    func snapshotData() throws -> Data {
        var bare = self
        bare.versions = []
        let json = try ProjectCoding.encoder(rate: frameRate, pretty: false).encode(bare)
        return try (json as NSData).compressed(using: .lzfse) as Data
    }

    /// Keeps the project as it is now. Automatic versions are skipped when nothing changed since
    /// the last version. Returns whether a version was added.
    @discardableResult
    public mutating func saveVersion(name: String, automatic: Bool = false, reason: String = "",
                                     author: String = NSFullUserName(), date: Date = Date(), force: Bool = false) -> Bool {
        guard let data = try? snapshotData() else { return false }
        if automatic, !force, let last = versions.last, last.data == data { return false }
        versions.append(ProjectVersion(name: name, date: date, automatic: automatic, reason: reason, author: author, data: data))
        var automaticCount = versions.filter(\.automatic).count
        while automaticCount > Self.maxAutomaticVersions, let i = versions.firstIndex(where: { $0.automatic }) {
            versions.remove(at: i)
            automaticCount -= 1
        }
        return true
    }

    /// The project as it was in a version.
    public func project(in version: ProjectVersion) throws -> Project {
        let json = try (version.data as NSData).decompressed(using: .lzfse) as Data
        return try ProjectCoding.decodeProject(json)
    }

    /// Goes back to a version without losing anything: the current state is kept as a version
    /// first, the old state comes back, and the restore itself is recorded as a new version.
    /// Every later version stays in the list.
    public mutating func restoreVersion(_ id: UUID, author: String = NSFullUserName(), date: Date = Date()) throws {
        guard let v = versions.first(where: { $0.id == id }) else { return }
        var old = try project(in: v)
        saveVersion(name: "Before restoring “\(v.name)”", automatic: true, reason: "Before restore", author: author, date: date, force: true)
        old.versions = versions
        old.id = self.id
        self = old
        editedAt = date
        saveVersion(name: "Restored “\(v.name)”", automatic: false, reason: "Restore", author: author, date: date)
    }
}

extension MediaAsset {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(path: try c.value("path", ""), bookmark: try c.value("bookmark", Data?.none),
                  kind: try c.enumValue("kind", .playerClip), name: try c.optional("name"),
                  duration: try c.optional("duration"))
        id = try c.value("id", UUID())
        added = try c.value("added", Date())
        notes = try c.value("notes", "")
    }
}
