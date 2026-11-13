import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnCueCore

extension UTType {
    /// Declared in Info.plist (UTExportedTypeDeclarations), file extension .oncue. A package
    /// (a folder Finder shows as one file); older single-file shows use the same extension.
    static let onCueShow = UTType(exportedAs: "com.nishanpani.oncue.show")
}

/// One project = one .oncue package. SwiftUI's DocumentGroup gives autosave and macOS version
/// history. Encoding, packages and backups live in OnCueCore (ProjectCoding, ProjectPackage) so
/// they can be tested without the app.
struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.onCueShow, .json] }
    static var writableContentTypes: [UTType] { [.onCueShow] }

    var project: Project
    /// Set when the file was an older single-file show. The window asks how to bring it in, and
    /// this document refuses to save over the original until that is done.
    var legacy: Show?

    init(project: Project = .starter(name: "New Project", frameRate: .r25)) {
        self.project = project
    }

    init(configuration: ReadConfiguration) throws {
        switch try ProjectPackage.read(configuration.file) {
        case .project(let p):
            project = p
        case .legacyShow(let show):
            project = Project(migrating: show)
            legacy = show
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if legacy != nil {
            throw ShowFileError.invalidContent("this older show must be brought into a project first; the original file is left untouched")
        }
        return try ProjectPackage.fileWrapper(for: project, existing: configuration.existingFile)
    }
}


/// Opens a .oncue project as an OnCue project explicitly, without asking macOS what kind of file
/// it is. Used when Launch Services maps .oncue to a plain folder (an older or second copy of
/// OnCue registered the extension) so projects still open.
enum ProjectOpener {
    static func open(_ url: URL) throws {
        let dc = NSDocumentController.shared
        if let open = dc.document(for: url) {
            open.showWindows()
            return
        }
        let doc = try dc.makeDocument(withContentsOf: url, ofType: UTType.onCueShow.identifier)
        dc.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
        dc.noteNewRecentDocument(doc)
    }
}
