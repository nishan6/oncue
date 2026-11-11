import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared in Info.plist (UTExportedTypeDeclarations).
    static let onCueShow = UTType(exportedAs: "com.nishanpani.oncue.show")
}

/// One show = one file. SwiftUI's DocumentGroup gives autosave and macOS version history for free
/// (File > Revert To > Browse All Versions).
struct ShowDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.onCueShow, .json] }
    static var writableContentTypes: [UTType] { [.onCueShow] }

    var show: Show

    init(show: Show = .starter()) {
        self.show = show
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        show = try ShowCoding.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try ShowCoding.encode(show))
    }
}

enum ShowCoding {
    static func encode(_ show: Show) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(show)
    }

    static func decode(_ data: Data) throws -> Show {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Show.self, from: data)
    }
}
