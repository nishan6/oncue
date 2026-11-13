import Foundation

// MARK: - Updates from GitHub Releases
//
// OnCue checks the repository's latest release and offers it; it never installs on its own and
// never while a show is in Live Mode. A release is offered only when it carries a DMG named
// OnCue-<version>-<build>.dmg and is newer than the running copy.

/// A version such as 1.2.0 with a build number. Compares numerically (1.10.0 > 1.9.0), then by build.
public struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    public var parts: [Int]
    public var build: Int

    public init?(_ version: String, build: Int = 0) {
        var v = version.trimmingCharacters(in: .whitespaces)
        if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
        let parts = v.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        self.parts = parts.map { $0! }
        self.build = build
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        let n = max(a.parts.count, b.parts.count)
        for k in 0..<n {
            let x = k < a.parts.count ? a.parts[k] : 0
            let y = k < b.parts.count ? b.parts[k] : 0
            if x != y { return x < y }
        }
        return a.build < b.build
    }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

public struct AvailableUpdate: Equatable {
    public var version: AppVersion
    public var title: String
    public var notes: String
    public var dmgURL: URL
    public var dmgName: String
    public var size: Int
    public var published: Date?
    public var pageURL: URL?
}

public enum UpdateCheck {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/nishan6/oncue/releases/latest")!

    /// The update offered by a GitHub "latest release" response, or nil when there is none newer
    /// than `current` (or it is a draft, a pre-release, the skipped version, or has no DMG).
    public static func update(fromRelease data: Data, current: AppVersion, skipped: String = "") -> AvailableUpdate? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if json["draft"] as? Bool == true || json["prerelease"] as? Bool == true { return nil }
        let assets = json["assets"] as? [[String: Any]] ?? []
        for asset in assets {
            guard let name = asset["name"] as? String, let (version, build) = dmgVersion(name),
                  let urlString = asset["browser_download_url"] as? String, let url = URL(string: urlString),
                  let offered = AppVersion(version, build: build) else { continue }
            guard offered > current else { return nil }
            if !skipped.isEmpty, skipped == "\(offered)-\(offered.build)" { return nil }
            let published = (json["published_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            return AvailableUpdate(version: offered, title: json["name"] as? String ?? "OnCue \(offered)",
                                   notes: json["body"] as? String ?? "", dmgURL: url, dmgName: name,
                                   size: asset["size"] as? Int ?? 0, published: published,
                                   pageURL: (json["html_url"] as? String).flatMap(URL.init(string:)))
        }
        return nil
    }

    /// "OnCue-1.2.0-57.dmg" → ("1.2.0", 57).
    public static func dmgVersion(_ name: String) -> (String, Int)? {
        guard name.hasPrefix("OnCue-"), name.hasSuffix(".dmg") else { return nil }
        let core = name.dropFirst("OnCue-".count).dropLast(".dmg".count)
        guard let dash = core.lastIndex(of: "-"), let build = Int(core[core.index(after: dash)...]) else { return nil }
        let version = String(core[..<dash])
        return AppVersion(version) == nil ? nil : (version, build)
    }

    /// The key stored when the person skips a version.
    public static func skipKey(_ u: AvailableUpdate) -> String { "\(u.version)-\(u.version.build)" }

    /// When to check again: every 6 hours, never while a show is live.
    public static func shouldCheck(lastCheck: Date?, now: Date, live: Bool, enabled: Bool) -> Bool {
        guard enabled, !live else { return false }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= 6 * 3600
    }
}
