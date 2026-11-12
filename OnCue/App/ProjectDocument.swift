import SwiftUI
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
