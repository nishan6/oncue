import Foundation

/// Why a show file could not be opened. Messages are written for the person at the Mac.
public enum ShowFileError: LocalizedError, Equatable {
    case empty
    case notAShowFile(String)
    case unsupportedVersion(found: Int, supported: Int)
    case invalidContent(String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "This show file is empty. Nothing was changed."
        case .notAShowFile(let detail):
            return "This file is not an OnCue show, or it is damaged (\(detail)). Nothing was changed."
        case .unsupportedVersion(let found, let supported):
            return "This show was saved by a newer version of OnCue (show format \(found); this version reads up to \(supported)). Update OnCue to open it. Nothing was changed."
        case .invalidContent(let detail):
            return "This show file has a value OnCue cannot read: \(detail). Nothing was changed."
        }
    }
}

/// Encodes and decodes show files, with versioning and migration.
public enum ShowCoding {
    public static func encode(_ show: Show) throws -> Data {
        var copy = show
        copy.schemaVersion = Show.currentSchemaVersion
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(copy)
    }

    /// Decodes any supported show file and migrates it to the current schema in memory.
    /// Never touches the file on disk.
    public static func decode(_ data: Data) throws -> Show {
        guard !data.isEmpty else { throw ShowFileError.empty }

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        // 1. Is it a JSON object at all, and which format version?
        struct Probe: Decodable { var schemaVersion: Int? }
        let probe: Probe
        do {
            probe = try dec.decode(Probe.self, from: data)
        } catch {
            throw ShowFileError.notAShowFile(describe(error))
        }
        let version = probe.schemaVersion ?? 0
        guard version <= Show.currentSchemaVersion else {
            throw ShowFileError.unsupportedVersion(found: version, supported: Show.currentSchemaVersion)
        }
        guard version >= 0 else {
            throw ShowFileError.invalidContent("schemaVersion \(version)")
        }

        // 2. Decode tolerantly and migrate.
        var show: Show
        do {
            show = try dec.decode(Show.self, from: data)
        } catch {
            throw ShowFileError.invalidContent(describe(error))
        }
        ShowMigration.migrate(&show, from: version)
        return show
    }

    /// Plain-language location of a decoding problem, e.g. "items › 2 › bpm: expected a number".
    static func describe(_ error: Error) -> String {
        guard let e = error as? DecodingError else { return error.localizedDescription }
        func path(_ ctx: DecodingError.Context) -> String {
            let p = ctx.codingPath.map { key in key.intValue.map { String($0) } ?? key.stringValue }.joined(separator: " › ")
            return p.isEmpty ? "the top level" : p
        }
        switch e {
        case .typeMismatch(let type, let ctx):
            return "\(path(ctx)): expected \(readable(type))"
        case .valueNotFound(let type, let ctx):
            return "\(path(ctx)): missing \(readable(type))"
        case .keyNotFound(let key, let ctx):
            return "\(path(ctx)): missing \(key.stringValue)"
        case .dataCorrupted(let ctx):
            return ctx.codingPath.isEmpty ? "not valid JSON" : "\(path(ctx)): \(ctx.debugDescription)"
        @unknown default:
            return "unreadable content"
        }
    }

    private static func readable(_ type: Any.Type) -> String {
        switch type {
        case is String.Type: return "text"
        case is Int.Type, is Double.Type: return "a number"
        case is Bool.Type: return "true or false"
        default: return "\(type)"
        }
    }
}

/// Upgrades older show files in memory, one schema step at a time.
public enum ShowMigration {
    public static func migrate(_ show: inout Show, from version: Int) {
        var v = version
        while v < Show.currentSchemaVersion {
            switch v {
            case 0:
                // 0 → 1: per-Mac settings moved to MachineProfile. Tolerant decoding already
                // ignored them; nothing else changes shape.
                break
            default:
                break
            }
            v += 1
        }
        show.schemaVersion = Show.currentSchemaVersion
    }
}

/// Reads and writes show files on disk. Writes are atomic, so a failed save never leaves
/// a half-written file; reads never modify the file.
public enum ShowFileIO {
    public static func read(_ url: URL) throws -> Show {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ShowFileError.notAShowFile(error.localizedDescription)
        }
        return try ShowCoding.decode(data)
    }

    public static func write(_ show: Show, to url: URL) throws {
        try ShowCoding.encode(show).write(to: url, options: .atomic)
    }
}
