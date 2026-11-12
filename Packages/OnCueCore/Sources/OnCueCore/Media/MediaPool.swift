import Foundation

// MARK: - Media Pool
//
// Every file a project uses, linked in place (never copied): song audio and click tracks, PGM
// recordings, player clips, stills and graphics. Files are found again through a security-scoped
// bookmark, then their path; a moved file can be relinked one by one or by searching a folder.

public enum MediaKind: String, Codable, CaseIterable, Identifiable {
    case songAudio, pgmRecording, playerClip, still
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .songAudio: return "Song audio / click"
        case .pgmRecording: return "PGM recording"
        case .playerClip: return "Player clip"
        case .still: return "Still / graphic"
        }
    }
    public var symbol: String {
        switch self {
        case .songAudio: return "waveform"
        case .pgmRecording: return "film"
        case .playerClip: return "play.rectangle"
        case .still: return "photo"
        }
    }

    static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "mp3", "m4a", "aac", "flac", "caf"]
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "mxf", "avi", "mkv"]
    static let stillExtensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff", "bmp", "gif", "tga", "psd", "heic"]

    /// A first guess from the file name; you can change it in the pool.
    public static func guess(for url: URL) -> MediaKind? {
        let ext = url.pathExtension.lowercased()
        if audioExtensions.contains(ext) { return .songAudio }
        if videoExtensions.contains(ext) { return .playerClip }
        if stillExtensions.contains(ext) { return .still }
        return nil
    }
}

public struct MediaAsset: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var path: String
    public var bookmark: Data?
    public var kind: MediaKind
    /// Name shown in the pool and used by player cues ("Intro loop"). Defaults to the file name
    /// without its extension.
    public var name: String
    public var added: Date = Date()
    /// Length in seconds, read when imported (nil for stills or unknown).
    public var duration: Double?
    public var notes: String = ""

    public init(path: String, bookmark: Data? = nil, kind: MediaKind, name: String? = nil, duration: Double? = nil) {
        self.path = path
        self.bookmark = bookmark
        self.kind = kind
        self.name = name ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        self.duration = duration
    }

    public var fileName: String { (path as NSString).lastPathComponent }

    /// The file, following the bookmark if it moved; nil when it can't be found.
    public func resolvedURL(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL? {
        if let bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale),
               fileExists(url.path) { return url }
        }
        return fileExists(path) ? URL(fileURLWithPath: path) : nil
    }
}

/// Where an asset is used in the project.
public struct MediaUsage: Equatable, Identifiable {
    public enum Place: Equatable {
        /// Loaded under a song's timeline (audio or PGM recording).
        case itemMedia
        /// Named by a Media Player Control cue.
        case playerCue(UUID)
    }
    public var id: String { "\(itemID)-\(place)" }
    public var itemID: UUID
    public var itemTitle: String
    public var place: Place
}

extension Project {
    /// Where each asset is used: songs that play it under the timeline, and player cues that name it.
    public func mediaUsage(_ asset: MediaAsset) -> [MediaUsage] {
        var out: [MediaUsage] = []
        for item in playlists.flatMap(\.items) {
            if let m = item.media, m.path == asset.path { out.append(MediaUsage(itemID: item.id, itemTitle: item.title, place: .itemMedia)) }
            for track in item.tracks where track.kind == .player {
                for cue in track.cues where !cue.clip.isEmpty && (cue.clip == asset.name || cue.clip == asset.fileName) {
                    out.append(MediaUsage(itemID: item.id, itemTitle: item.title, place: .playerCue(cue.id)))
                }
            }
        }
        return out
    }

    /// Adds files already used by songs (loaded before the pool existed) so the pool lists them.
    /// Returns how many were added.
    @discardableResult
    public mutating func collectItemMedia() -> Int {
        var added = 0
        for item in playlists.flatMap(\.items) {
            guard let m = item.media, !media.contains(where: { $0.path == m.path }) else { continue }
            media.append(MediaAsset(path: m.path, bookmark: m.bookmark, kind: m.kind == .video ? .pgmRecording : .songAudio))
            added += 1
        }
        return added
    }

    /// Adds files to the pool, skipping ones already in it. Returns the new assets.
    @discardableResult
    public mutating func importMedia(_ files: [(path: String, bookmark: Data?, kind: MediaKind, duration: Double?)]) -> [MediaAsset] {
        var new: [MediaAsset] = []
        for f in files where !media.contains(where: { $0.path == f.path }) && !new.contains(where: { $0.path == f.path }) {
            new.append(MediaAsset(path: f.path, bookmark: f.bookmark, kind: f.kind, duration: f.duration))
        }
        media += new
        return new
    }

    /// Points an asset at a new file and updates every song that plays it.
    public mutating func relink(_ id: UUID, to path: String, bookmark: Data?) {
        guard let i = media.firstIndex(where: { $0.id == id }) else { return }
        let old = media[i].path
        media[i].path = path
        media[i].bookmark = bookmark
        for p in playlists.indices {
            for k in playlists[p].items.indices where playlists[p].items[k].media?.path == old {
                playlists[p].items[k].media?.path = path
                playlists[p].items[k].media?.bookmark = bookmark
            }
        }
    }

    /// Assets nothing in the project uses.
    public var unusedMedia: [MediaAsset] { media.filter { mediaUsage($0).isEmpty } }
}

public enum MediaRelink {
    /// Matches missing assets to files found in a folder by file name. When a name appears more
    /// than once, the one whose parent folder matches the old one wins; otherwise it is left for
    /// you to pick (not guessed).
    public static func matches(missing: [MediaAsset], candidates: [String]) -> [UUID: String] {
        var byName: [String: [String]] = [:]
        for c in candidates { byName[(c as NSString).lastPathComponent.lowercased(), default: []].append(c) }
        var out: [UUID: String] = [:]
        for asset in missing {
            guard let found = byName[asset.fileName.lowercased()], !found.isEmpty else { continue }
            if found.count == 1 { out[asset.id] = found[0]; continue }
            let oldParent = ((asset.path as NSString).deletingLastPathComponent as NSString).lastPathComponent
            let sameParent = found.filter { (($0 as NSString).deletingLastPathComponent as NSString).lastPathComponent == oldParent }
            if sameParent.count == 1 { out[asset.id] = sameParent[0] }
        }
        return out
    }
}
