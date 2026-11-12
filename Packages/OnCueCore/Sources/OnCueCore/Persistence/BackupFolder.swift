import Foundation

/// Copies of each show in a backup folder: "<Show>/<Show>.oncue" is always the latest, and
/// timestamped copies are kept beside it (the newest `keep`).
public enum ShowBackup {
    public static let keep = 30

    @discardableResult
    public static func write(_ show: Show, to folder: URL, date: Date = Date(), keep: Int = ShowBackup.keep) throws -> URL {
        let safe = show.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let dir = folder.appendingPathComponent(safe, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try ShowCoding.encode(show)
        let latest = dir.appendingPathComponent("\(safe).oncue")
        try data.write(to: latest, options: .atomic)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let stamped = dir.appendingPathComponent("\(safe) \(f.string(from: date)).oncue")
        try data.write(to: stamped, options: .atomic)
        // Prune old timestamped copies.
        let copies = (try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))
            .filter { $0.pathExtension == "oncue" && $0.lastPathComponent != latest.lastPathComponent }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for old in copies.dropLast(keep) { try? FileManager.default.removeItem(at: old) }
        return latest
    }
}
