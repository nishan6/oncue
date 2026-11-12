import Foundation

/// A named snapshot of the show kept inside the show file ("Before rehearsal", "Night 2 as run").
/// The snapshot is the show without its own versions, compressed.
public struct ShowVersion: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var date: Date
    public var automatic: Bool = false
    /// LZFSE-compressed JSON of the show (versions left out).
    public var data: Data

    public init(name: String, date: Date, automatic: Bool, data: Data) {
        self.name = name
        self.date = date
        self.automatic = automatic
        self.data = data
    }
}

extension Show {
    /// Versions kept per file; the oldest automatic ones go first.
    public static let maxVersions = 30

    private func snapshotData() throws -> Data {
        var bare = self
        bare.versions = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(bare)
        return try (json as NSData).compressed(using: .lzfse) as Data
    }

    /// Keeps the show as it is now under a name. Automatic versions are skipped when nothing
    /// changed since the last version.
    @discardableResult
    public mutating func saveVersion(name: String, automatic: Bool = false, date: Date = Date()) -> Bool {
        guard let data = try? snapshotData() else { return false }
        if automatic, let last = versions.last, last.data == data { return false }
        versions.append(ShowVersion(name: name, date: date, automatic: automatic, data: data))
        while versions.count > Self.maxVersions {
            if let i = versions.firstIndex(where: { $0.automatic }) { versions.remove(at: i) } else { versions.removeFirst() }
        }
        return true
    }

    /// The show as it was in a version.
    public func show(in version: ShowVersion) throws -> Show {
        let json = try (version.data as NSData).decompressed(using: .lzfse) as Data
        return try JSONDecoder().decode(Show.self, from: json)
    }

    /// Goes back to a version, keeping the version list (so the restore itself can be undone or
    /// restored again).
    public mutating func restoreVersion(_ id: UUID) throws {
        guard let v = versions.first(where: { $0.id == id }) else { return }
        var old = try show(in: v)
        old.versions = versions
        old.id = self.id
        self = old
    }

    public mutating func deleteVersion(_ id: UUID) {
        versions.removeAll { $0.id == id }
    }
}
