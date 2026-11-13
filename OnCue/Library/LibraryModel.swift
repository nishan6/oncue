import SwiftUI
import AppKit
import OnCueCore

/// The Project Library: the projects folder (chosen on first launch), the projects in it, and
/// the operations on them. Files are only written here when the project is not open in a window;
/// an open project belongs to its window's document.
final class LibraryModel: ObservableObject {
    static let windowID = "library"
    static let folderKey = "oncue.projectsFolder"

    @Published private(set) var folder: URL?
    @Published private(set) var entries: [LibraryEntry] = []
    @Published var search = ""
    @Published var showArchived = false
    @Published var errorMessage: String?

    init() {
        folder = Self.currentFolder
        refresh()
    }

    /// The projects folder, or nil until one is chosen.
    static var currentFolder: URL? {
        guard let path = UserDefaults.standard.string(forKey: folderKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Backups outside each project, never deleted by OnCue: inside the projects folder when one
    /// is chosen, otherwise in Application Support.
    static var backupRoot: URL {
        if let folder = currentFolder { return folder.appendingPathComponent("OnCue Backups", isDirectory: true) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return support.appendingPathComponent("OnCue/Backups", isDirectory: true)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"
        panel.message = "Choose where OnCue keeps your projects. You can change this later."
        if let folder { panel.directoryURL = folder }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        folder = url
        refresh()
    }

    func refresh() {
        guard let folder else { entries = []; return }
        entries = ProjectLibrary.sorted(ProjectLibrary.scan(folder))
    }

    var visible: [LibraryEntry] {
        ProjectLibrary.filter(entries.filter { $0.archived == showArchived }, search: search)
    }

    var archivedCount: Int { entries.filter(\.archived).count }

    func isOpen(_ url: URL) -> Bool {
        NSDocumentController.shared.documents.contains { url.isSameFile(as: $0.fileURL) }
    }

    private func run(_ what: String, _ body: () throws -> Void) {
        do {
            try body()
            errorMessage = nil
        } catch {
            errorMessage = "\(what) didn't work: \(error.localizedDescription)"
        }
        refresh()
    }

    @discardableResult
    func create(name: String, artist: String, venue: String, showDate: Date?, rate: FrameRate, setup: ProjectSetup? = nil) -> URL? {
        guard let folder else { return nil }
        var project = Project.starter(name: name.trimmingCharacters(in: .whitespaces), frameRate: rate)
        if let setup { project.apply(setup) }
        project.artist = artist.trimmingCharacters(in: .whitespaces)
        project.venue = venue.trimmingCharacters(in: .whitespaces)
        project.showDate = showDate
        var url: URL?
        run("Creating the project") { url = try ProjectLibrary.create(project, in: folder) }
        return url
    }

    func duplicate(_ entry: LibraryEntry) {
        guard let folder else { return }
        run("Duplicating") { try ProjectLibrary.duplicate(entry.url, in: folder) }
    }

    func rename(_ entry: LibraryEntry, to name: String) {
        guard let folder else { return }
        guard !isOpen(entry.url) else {
            errorMessage = "“\(entry.name)” is open in a window. Close it first, or rename it in Project Properties."
            return
        }
        run("Renaming") { try ProjectLibrary.rename(entry.url, to: name, in: folder) }
    }

    func setPinned(_ entry: LibraryEntry, _ pinned: Bool) {
        guard let folder else { return }
        run(pinned ? "Pinning" : "Unpinning") { try ProjectLibrary.setPinned(pinned, entry.url, in: folder) }
    }

    func setArchived(_ entry: LibraryEntry, _ archived: Bool) {
        guard let folder else { return }
        run(archived ? "Archiving" : "Restoring") { try ProjectLibrary.setArchived(archived, entry.url, in: folder) }
    }

    func moveToTrash(_ entry: LibraryEntry) {
        guard let folder else { return }
        guard !isOpen(entry.url) else {
            errorMessage = "“\(entry.name)” is open in a window. Close it before moving it to the Trash."
            return
        }
        run("Moving to the Trash") { try ProjectLibrary.moveToTrash(entry.url, in: folder) }
    }
}
