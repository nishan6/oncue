import Foundation

/// Hardware and network settings that belong to this Mac, not to a show.
/// Shows stay portable: the same show file opens on the main and backup Mac, and each Mac keeps
/// its own MIDI ports, LTC input, network interface and backup role.
public struct MachineProfile: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int = MachineProfile.currentSchemaVersion
    /// Free label, e.g. "Main Mac" or "Backup Mac". Empty until the person names it.
    public var machineName: String = ""

    // MIDI
    public var midiClockSource: String = ""
    public var controllerSource: String = ""
    public var controllerDestination: String = ""
    public var apcLEDs: Bool = true

    // LTC
    public var ltcDeviceUID: String = ""
    public var ltcChannel: Int = 0
    /// LTC output (master timecode): "off", "timeOfDay" or "song" (see LTCOutputMode), and the device.
    public var ltcOutputMode: String = "off"
    public var ltcOutputDevice: String = ""

    // Network
    public var crewPort: Int = 8080
    public var crewInterface: String = ""
    public var oscControlPort: Int = 9000
    public var companionHost: String = "127.0.0.1"
    public var companionPort: Int = 8000
    /// "v3" or "v2" (see CompanionVersion).
    public var companionVersion: String = "v3"
    /// Push Live status to Companion custom variables (for Stream Deck key text and colours).
    public var companionVariables: Bool = false

    // Backup
    /// "off", "primary" or "backup" (see BackupRole).
    public var backupRole: String = "off"
    public var primaryHost: String = ""

    // Files
    public var logFolder: String = ""
    /// A folder (iCloud Drive, a NAS, a USB drive) that gets a copy of every show as it changes.
    public var backupFolder: String = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        schemaVersion = try c.value("schemaVersion", 0)
        machineName = try c.value("machineName", "")
        midiClockSource = try c.value("midiClockSource", "")
        controllerSource = try c.value("controllerSource", "")
        controllerDestination = try c.value("controllerDestination", "")
        apcLEDs = try c.value("apcLEDs", true)
        ltcDeviceUID = try c.value("ltcDeviceUID", "")
        ltcChannel = try c.value("ltcChannel", 0)
        crewPort = try c.value("crewPort", 8080)
        crewInterface = try c.value("crewInterface", "")
        oscControlPort = try c.value("oscControlPort", 9000)
        companionHost = try c.value("companionHost", "127.0.0.1")
        companionPort = try c.value("companionPort", 8000)
        companionVersion = try c.value("companionVersion", "v3")
        companionVariables = try c.value("companionVariables", false)
        backupRole = try c.value("backupRole", "off")
        primaryHost = try c.value("primaryHost", "")
        logFolder = try c.value("logFolder", "")
        backupFolder = try c.value("backupFolder", "")
        ltcOutputMode = try c.value("ltcOutputMode", "off")
        ltcOutputDevice = try c.value("ltcOutputDevice", "")
    }
}

/// Loads and saves this Mac's profile at
/// ~/Library/Application Support/OnCue/MachineProfile.json (directory injectable for tests).
public final class MachineProfileStore {
    public static let fileName = "MachineProfile.json"

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("OnCue", isDirectory: true)
    }

    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    public private(set) var profile = MachineProfile()
    /// Set when the stored profile could not be used; explains what happened and where the
    /// original file was kept.
    public private(set) var issue: String?

    public init(directory: URL = MachineProfileStore.defaultDirectory) {
        self.directory = directory
        load()
    }

    /// Loads the profile. A missing profile is created with defaults. An unreadable or
    /// newer-format profile is never overwritten in place: it is kept as a backup copy first.
    public func load() {
        issue = nil
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            profile = MachineProfile()
            try? save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(MachineProfile.self, from: data)
            if loaded.schemaVersion > MachineProfile.currentSchemaVersion {
                quarantine(reason: "it was saved by a newer version of OnCue")
                return
            }
            profile = loaded
            profile.schemaVersion = MachineProfile.currentSchemaVersion
        } catch {
            quarantine(reason: "it could not be read")
        }
    }

    /// Applies a change and saves. Never touches any show document.
    public func update(_ change: (inout MachineProfile) -> Void) throws {
        var next = profile
        change(&next)
        profile = next
        try save()
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        var copy = profile
        copy.schemaVersion = MachineProfile.currentSchemaVersion
        try enc.encode(copy).write(to: fileURL, options: .atomic)
    }

    /// Keeps the unusable file under a new name, then starts from defaults.
    private func quarantine(reason: String) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = directory.appendingPathComponent("MachineProfile.unreadable-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backup)
            profile = MachineProfile()
            try save()
            issue = "This Mac's settings were reset because \(reason). The old file was kept as \(backup.lastPathComponent)."
        } catch {
            // Could not move it aside: use defaults in memory and leave the file untouched.
            profile = MachineProfile()
            issue = "This Mac's settings could not be loaded because \(reason), and the file could not be moved aside. Using defaults for now; the file was left as it is."
        }
    }
}
