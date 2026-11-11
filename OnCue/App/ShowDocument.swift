import SwiftUI
import UniformTypeIdentifiers
import OnCueCore

extension UTType {
    /// Declared in Info.plist (UTExportedTypeDeclarations), file extension .oncue.
    static let onCueShow = UTType(exportedAs: "com.nishanpani.oncue.show")
}

/// One show = one file. SwiftUI's DocumentGroup gives autosave and macOS version history
/// (File > Revert To > Browse All Versions). All encoding, versioning and error handling lives in
/// OnCueCore (ShowCoding) so it can be tested without the app.
struct ShowDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.onCueShow, .json] }
    static var writableContentTypes: [UTType] { [.onCueShow] }

    var show: Show

    init(show: Show = .starter()) {
        self.show = show
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ShowFileError.notAShowFile("the file has no contents")
        }
        show = try ShowCoding.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try ShowCoding.encode(show))
    }
}
