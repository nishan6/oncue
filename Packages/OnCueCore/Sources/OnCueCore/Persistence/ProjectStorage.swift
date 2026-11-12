import Foundation

// A project on disk is a package (a folder Finder shows as one file):
//
//   Arena 2026.oncue/
//     project.json                    the project
//     Backups/20261112T143000Z.json   automatic backups, every 5 minutes while editing (newest 24)
//
// A second, independent copy of every backup goes to a backup folder outside the package and is
// never deleted by OnCue (ProjectBackupFolder).

enum BackupStamp {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f
    }()

    static func name(_ date: Date) -> String { formatter.string(from: date) + ".json" }

    static func date(_ fileName: String) -> Date? {
        guard fileName.hasSuffix(".json") else { return nil }
        return formatter.date(from: String(fileName.dropLast(5)))
    }
}

public enum ProjectPackage {
    public static let projectFile = "project.json"
    public static let backupsFolder = "Backups"
    public static let insideBackupsKept = 24
    public static let backupInterval: TimeInterval = 300

    /// The package to save. Backups already inside are kept; a new one is added when the newest is
    /// at least 5 minutes old, and only the newest 24 stay.
    public static func fileWrapper(for project: Project, existing: FileWrapper?, now: Date = Date()) throws -> FileWrapper {
        let data = try ProjectCoding.encode(project)
        var backups: [(name: String, data: Data)] = []
        if let old = existing?.fileWrappers?[backupsFolder]?.fileWrappers {
            for (name, wrapper) in old {
                if BackupStamp.date(name) != nil, let contents = wrapper.regularFileContents {
                    backups.append((name, contents))
                }
            }
        }
        backups.sort { $0.name < $1.name }
        let newest = backups.last.flatMap { BackupStamp.date($0.name) }
        if newest == nil || now.timeIntervalSince(newest!) >= backupInterval {
            backups.append((BackupStamp.name(now), data))
        }
        let kept = backups.suffix(insideBackupsKept)

        let backupDir = FileWrapper(directoryWithFileWrappers: [:])
        backupDir.preferredFilename = backupsFolder
        for b in kept {
            let file = FileWrapper(regularFileWithContents: b.data)
            file.preferredFilename = b.name
            backupDir.addFileWrapper(file)
        }
        let projectWrapper = FileWrapper(regularFileWithContents: data)
        projectWrapper.preferredFilename = projectFile
        let package = FileWrapper(directoryWithFileWrappers: [:])
        package.addFileWrapper(projectWrapper)
        package.addFileWrapper(backupDir)
        return package
    }

    /// A package, or an older single-file show.
    public static func read(_ wrapper: FileWrapper) throws -> ProjectFileContents {
        if wrapper.isDirectory {
            guard let data = wrapper.fileWrappers?[projectFile]?.regularFileContents else {
                throw ShowFileError.notAShowFile("the project has no \(projectFile)")
            }
            return try ProjectCoding.decode(data)
        }
        guard let data = wrapper.regularFileContents else {
            throw ShowFileError.notAShowFile("the file has no contents")
        }
        return try ProjectCoding.decode(data)
    }

    public static func read(at url: URL) throws -> ProjectFileContents {
        let wrapper: FileWrapper
        do {
            wrapper = try FileWrapper(url: url, options: .immediate)
        } catch {
            throw ShowFileError.notAShowFile(error.localizedDescription)
        }
        return try read(wrapper)
    }

    /// Writes a package (new, duplicated or renamed projects). Never used on a project that is open
    /// in a window: the window's document owns that file.
    public static func write(_ project: Project, to url: URL, now: Date = Date()) throws {
        let existing = try? FileWrapper(url: url, options: .immediate)
        let wrapper = try fileWrapper(for: project, existing: existing?.isDirectory == true ? existing : nil, now: now)
        try wrapper.write(to: url, options: [.atomic], originalContentsURL: nil)
    }

    /// Dates of the backups inside a package, oldest first.
    public static func insideBackupDates(_ wrapper: FileWrapper) -> [Date] {
        (wrapper.fileWrappers?[backupsFolder]?.fileWrappers?.keys.compactMap { BackupStamp.date($0) } ?? []).sorted()
    }
}

/// Backups outside the package, one folder per project, never deleted by OnCue.
public enum ProjectBackupFolder {
    static func safe(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    /// "<root>/<Project name> – <first 8 of id>". Found again by its id after a rename.
    public static func folder(for project: Project, root: URL) -> URL {
        let tag = String(project.id.uuidString.prefix(8))
        if let existing = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .first(where: { $0.lastPathComponent.hasSuffix(tag) }) {
            return existing
        }
        return root.appendingPathComponent("\(safe(project.name)) – \(tag)", isDirectory: true)
    }

    @discardableResult
    public static func write(_ project: Project, root: URL, date: Date = Date()) throws -> URL {
        let dir = folder(for: project, root: root)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(BackupStamp.name(date))
        try ProjectCoding.encode(project).write(to: url, options: .atomic)
        return url
    }

    /// The newest backup of this project, if any.
    public static func newest(for project: Project, root: URL) -> (url: URL, date: Date)? {
        let dir = folder(for: project, root: root)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        return files.compactMap { url in BackupStamp.date(url.lastPathComponent).map { (url, $0) } }
            .max { $0.1 < $1.1 }
    }

    public static func read(_ url: URL) throws -> Project {
        try ProjectCoding.decodeProject(try Data(contentsOf: url))
    }
}

// MARK: - Library

/// One project (or older show file) in the projects folder.
public struct LibraryEntry: Identifiable, Hashable {
    public var url: URL
    public var projectID: UUID?
    public var name: String
    public var artist: String
    public var venue: String
    public var showDate: Date?
    public var frameRate: FrameRate
    public var sceneCount: Int
    public var editedAt: Date
    public var pinned: Bool
    public var archived: Bool
    /// An older single-file show: opening it asks how to bring it in.
    public var isLegacy: Bool
    /// Set when the file could not be read.
    public var problem: String?

    public var id: URL { url }
}

/// Pins and archive state, kept beside the projects (never inside them, so a project open in a
/// window is never written by the Library).
public struct LibraryFlags: Codable, Equatable {
    public var pinned: Set<String> = []
    public var archived: Set<String> = []
    public init() {}
}

public enum ProjectLibrary {
    public static let indexFile = ".oncue-library.json"
    public static let fileExtension = "oncue"

    public static func flags(in folder: URL) -> LibraryFlags {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(indexFile)),
              let flags = try? JSONDecoder().decode(LibraryFlags.self, from: data) else { return LibraryFlags() }
        return flags
    }

    public static func saveFlags(_ flags: LibraryFlags, in folder: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(flags).write(to: folder.appendingPathComponent(indexFile), options: .atomic)
    }

    /// Flags are keyed by file name, so they follow a project when it is moved within the folder.
    static func key(_ url: URL) -> String { url.lastPathComponent }

    public static func setPinned(_ pinned: Bool, _ url: URL, in folder: URL) throws {
        var f = flags(in: folder)
        if pinned { f.pinned.insert(key(url)) } else { f.pinned.remove(key(url)) }
        try saveFlags(f, in: folder)
    }

    public static func setArchived(_ archived: Bool, _ url: URL, in folder: URL) throws {
        var f = flags(in: folder)
        if archived { f.archived.insert(key(url)) } else { f.archived.remove(key(url)) }
        try saveFlags(f, in: folder)
    }

    /// Every .oncue in the folder (not subfolders), readable or not.
    public static func scan(_ folder: URL) -> [LibraryEntry] {
        let f = flags(in: folder)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                    options: [.skipsHiddenFiles])) ?? []
        // Rebuilt the way packageURL builds them (packages marked as directories; older single-file
        // shows stay plain files), so they compare equal to what create and rename return.
        return urls.filter { $0.pathExtension == fileExtension }
            .map { folder.appendingPathComponent($0.lastPathComponent, isDirectory: $0.hasDirectoryPath) }
            .map { url in
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            var entry = LibraryEntry(url: url, projectID: nil, name: url.deletingPathExtension().lastPathComponent,
                                     artist: "", venue: "", showDate: nil, frameRate: .r25, sceneCount: 0,
                                     editedAt: modified, pinned: f.pinned.contains(key(url)),
                                     archived: f.archived.contains(key(url)), isLegacy: false, problem: nil)
            do {
                switch try ProjectPackage.read(at: url) {
                case .project(let p):
                    entry.projectID = p.id
                    entry.name = p.name
                    entry.artist = p.artist
                    entry.venue = p.venue
                    entry.showDate = p.showDate
                    entry.frameRate = p.frameRate
                    entry.sceneCount = p.sceneCount
                    entry.editedAt = max(p.editedAt, modified)
                case .legacyShow(let s):
                    entry.name = s.name
                    entry.frameRate = FrameRate.closest(to: s.settings.ltcFPS)
                    entry.sceneCount = s.items.count
                    entry.isLegacy = true
                }
            } catch {
                entry.problem = error.localizedDescription
            }
            return entry
        }
    }

    /// Pinned first, then most recently edited.
    public static func sorted(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        entries.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            if a.editedAt != b.editedAt { return a.editedAt > b.editedAt }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Matches name, artist and venue, ignoring case.
    public static func filter(_ entries: [LibraryEntry], search: String) -> [LibraryEntry] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
                || $0.venue.localizedCaseInsensitiveContains(q)
        }
    }

    /// Every project URL is built here, always marked as a directory (a package), so a URL made
    /// before the package exists equals the one made after. Foundation otherwise checks the disk
    /// and adds a trailing slash only when the folder is already there.
    public static func packageURL(file: String, in folder: URL) -> URL {
        folder.appendingPathComponent(file, isDirectory: true)
    }

    /// A file name in the folder that is not taken: "Arena.oncue", "Arena 2.oncue", ...
    public static func uniqueURL(named name: String, in folder: URL) -> URL {
        let base = ProjectBackupFolder.safe(name)
        var url = packageURL(file: "\(base).\(fileExtension)", in: folder)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = packageURL(file: "\(base) \(n).\(fileExtension)", in: folder)
            n += 1
        }
        return url
    }

    @discardableResult
    public static func create(_ project: Project, in folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = uniqueURL(named: project.name, in: folder)
        try ProjectPackage.write(project, to: url)
        return url
    }

    /// A copy with a new identity and "copy" in its name. Its versions come along; its backups do not.
    @discardableResult
    public static func duplicate(_ url: URL, in folder: URL) throws -> URL {
        guard case .project(var p) = try ProjectPackage.read(at: url) else {
            throw ShowFileError.invalidContent("only projects can be duplicated; open the older show first")
        }
        p.id = UUID()
        p.name = "\(p.name) copy"
        p.createdAt = Date()
        p.editedAt = Date()
        return try create(p, in: folder)
    }

    /// Renames the project and its package. Pins and archive state follow it.
    @discardableResult
    public static func rename(_ url: URL, to name: String, in folder: URL) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ShowFileError.invalidContent("a project needs a name") }
        guard case .project(var p) = try ProjectPackage.read(at: url) else {
            throw ShowFileError.invalidContent("only projects can be renamed; open the older show first")
        }
        p.name = trimmed
        p.editedAt = Date()
        try ProjectPackage.write(p, to: url)
        let target = uniqueURL(named: trimmed, in: folder)
        guard target.lastPathComponent != url.lastPathComponent else { return url }
        try FileManager.default.moveItem(at: url, to: target)
        var f = flags(in: folder)
        if f.pinned.remove(key(url)) != nil { f.pinned.insert(key(target)) }
        if f.archived.remove(key(url)) != nil { f.archived.insert(key(target)) }
        try saveFlags(f, in: folder)
        return target
    }

    /// Moves the project to the macOS Trash (recoverable there). Backup-folder copies stay.
    public static func moveToTrash(_ url: URL, in folder: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        var f = flags(in: folder)
        f.pinned.remove(key(url))
        f.archived.remove(key(url))
        try saveFlags(f, in: folder)
    }
}

extension URL {
    /// The same file on disk, ignoring a trailing slash, "/./" and "/private" symlink spellings.
    public func isSameFile(as other: URL?) -> Bool {
        guard let other else { return false }
        return resolvingSymlinksInPath().standardizedFileURL.path == other.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
