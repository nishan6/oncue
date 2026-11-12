import Foundation

// The switch log: every program change the switchers report (in every mode, including display
// only) and every shot the script called. It is saved next to the show during Live Mode and is
// the source for scripted-vs-actual, Director Stats, EDL export and the after-show reel.

public struct SwitchLogEntry: Codable, Hashable {
    public enum Kind: String, Codable { case cut, scripted }
    public var kind: Kind
    public var date: Date
    /// LTC at that moment, when LTC is running.
    public var timecode: String?
    public var switcherID: UUID?
    public var outputID: UUID?
    /// The program input the switcher reported (cuts).
    public var input: Int?
    public var cameraID: UUID?
    public var itemID: UUID?
    /// Scripted shot number (scripted entries; for cuts, the shot on air at the time).
    public var shotNumber: Int?
    public var mode: String
    public var freeMode: Bool

    public init(kind: Kind, date: Date, timecode: String? = nil, switcherID: UUID? = nil, outputID: UUID? = nil,
                input: Int? = nil, cameraID: UUID? = nil, itemID: UUID? = nil, shotNumber: Int? = nil,
                mode: String, freeMode: Bool = false) {
        self.kind = kind
        self.date = date
        self.timecode = timecode
        self.switcherID = switcherID
        self.outputID = outputID
        self.input = input
        self.cameraID = cameraID
        self.itemID = itemID
        self.shotNumber = shotNumber
        self.mode = mode
        self.freeMode = freeMode
    }
}

public struct SwitchLog: Codable, Equatable {
    public static let fileExtension = "oncuelog"
    public var showID: UUID
    public var showName: String
    public var started: Date
    public var machine: String
    public var entries: [SwitchLogEntry] = []

    public init(showID: UUID, showName: String, started: Date, machine: String = "") {
        self.showID = showID
        self.showName = showName
        self.started = started
        self.machine = machine
    }

    public var cuts: [SwitchLogEntry] { entries.filter { $0.kind == .cut } }
    public var scripted: [SwitchLogEntry] { entries.filter { $0.kind == .scripted } }

    /// ISO 8601 with milliseconds: cut times matter to the frame.
    private static func formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        let f = Self.formatter()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> SwitchLog {
        let d = JSONDecoder()
        let withFraction = formatter()
        let plain = ISO8601DateFormatter()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let text = try c.decode(String.self)
            if let date = withFraction.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not a date: \(text)")
        }
        return try d.decode(SwitchLog.self, from: data)
    }

    /// File name for a log: show name and start time.
    public var fileName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm"
        let safe = showName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return "\(safe) \(f.string(from: started)).\(Self.fileExtension)"
    }
}

// MARK: - Analysis

/// Director Stats and scripted-vs-actual for one log.
public struct ShowAnalysis: Equatable {
    public struct CameraStats: Equatable, Identifiable {
        public var id: UUID { cameraID }
        public let cameraID: UUID
        public let onAirSeconds: Double
        public let shots: Int
    }

    public enum Result: Equatable {
        /// Cut within the window; seconds early (negative) or late (positive).
        case hit(offset: Double)
        case missed
    }

    public struct ScriptedResult: Equatable {
        public let entry: SwitchLogEntry
        public let result: Result
    }

    public let duration: Double
    public let cutCount: Int
    public let cutsPerMinute: Double
    public let averageShotSeconds: Double
    public let cameras: [CameraStats]
    public let scripted: [ScriptedResult]
    /// Cuts not matching any scripted shot.
    public let offScript: [SwitchLogEntry]

    public var hits: Int { scripted.filter { if case .hit = $0.result { return true } else { return false } }.count }
    public var missed: Int { scripted.count - hits }
    public var averageOffset: Double? {
        let offsets = scripted.compactMap { r -> Double? in if case .hit(let o) = r.result { return o } else { return nil } }
        return offsets.isEmpty ? nil : offsets.reduce(0, +) / Double(offsets.count)
    }

    /// Analyses the main switcher's cuts against the main output's scripted shots.
    /// `window`: how far a cut may be from its scripted moment to count as hitting it.
    public init(log: SwitchLog, show: Show, end: Date? = nil, window: Double = 2) {
        let mainSwitcher = show.mainOutput?.switcherID
        let mainOutput = show.mainOutput?.id
        let cuts = log.cuts.filter { mainSwitcher == nil || $0.switcherID == mainSwitcher }.sorted { $0.date < $1.date }
        let scriptedEntries = log.scripted.filter { mainOutput == nil || $0.outputID == mainOutput }.sorted { $0.date < $1.date }
        let start = (cuts.first?.date ?? log.started)
        let finish = end ?? max(cuts.last?.date ?? start, scriptedEntries.last?.date ?? start)
        duration = max(finish.timeIntervalSince(start), 0)
        cutCount = cuts.count
        cutsPerMinute = duration > 0 ? Double(cuts.count) / (duration / 60) : 0

        // On-air time per camera: each cut lasts until the next.
        var onAir: [UUID: Double] = [:]
        var shots: [UUID: Int] = [:]
        var lengths: [Double] = []
        for (k, cut) in cuts.enumerated() {
            let until = k + 1 < cuts.count ? cuts[k + 1].date : finish
            let length = max(until.timeIntervalSince(cut.date), 0)
            lengths.append(length)
            if let cam = cut.cameraID {
                onAir[cam, default: 0] += length
                shots[cam, default: 0] += 1
            }
        }
        averageShotSeconds = lengths.isEmpty ? 0 : lengths.reduce(0, +) / Double(lengths.count)
        cameras = onAir.keys.map { CameraStats(cameraID: $0, onAirSeconds: onAir[$0] ?? 0, shots: shots[$0] ?? 0) }
            .sorted { $0.onAirSeconds > $1.onAirSeconds }

        // Scripted vs actual: each scripted shot takes the nearest unused cut to the same camera.
        var used = Set<Int>()
        var results: [ScriptedResult] = []
        for entry in scriptedEntries where !entry.freeMode {
            var best: (index: Int, offset: Double)?
            for (k, cut) in cuts.enumerated() where !used.contains(k) && cut.cameraID != nil && cut.cameraID == entry.cameraID {
                let offset = cut.date.timeIntervalSince(entry.date)
                if abs(offset) <= window, abs(offset) < abs(best?.offset ?? .infinity) { best = (k, offset) }
            }
            if let best {
                used.insert(best.index)
                results.append(ScriptedResult(entry: entry, result: .hit(offset: best.offset)))
            } else {
                results.append(ScriptedResult(entry: entry, result: .missed))
            }
        }
        scripted = results
        offScript = cuts.enumerated().filter { !used.contains($0.offset) }.map(\.element)
    }
}

// MARK: - Variety hints and camera down

extension Show {
    /// Cameras that have been off program the longest (never used first), for free mode.
    public func varietyHints(log: SwitchLog, now: Date, count: Int = 3, excluding onAir: UUID? = nil) -> [Camera] {
        var last: [UUID: Date] = [:]
        for cut in log.cuts { if let cam = cut.cameraID { last[cam] = cut.date } }
        return sortedCameras
            .filter { $0.id != onAir && $0.input > 0 }
            .sorted { a, b in
                let la = last[a.id] ?? .distantPast, lb = last[b.id] ?? .distantPast
                return la == lb ? a.number < b.number : la < lb
            }
            .prefix(count)
            .map { $0 }
    }

    /// The camera on a switcher input (main switcher unless given).
    public func camera(input: Int, switcherID: UUID?) -> Camera? {
        let main = mainOutput?.switcherID
        if let s = switcherID, let cam = cameras.first(where: { $0.extraInputs.contains { $0.switcherID == s && $0.input == input } }) {
            return cam
        }
        return cameras.first { $0.input == input && (($0.switcherID ?? main) == (switcherID ?? main)) }
    }

    /// How many of a camera's shots are still ahead, from a position in the running order.
    public func upcomingShotCount(camera: UUID, from cursor: LiveCursor, sameItemOnly: Bool = false) -> Int {
        upcomingShots(camera: camera, from: cursor, limit: .max, sameItemOnly: sameItemOnly).count
    }

    private func upcomingShots(camera: UUID, from cursor: LiveCursor, limit: Int, sameItemOnly: Bool) -> [(item: UUID, cue: UUID)] {
        guard let start = itemIndex(cursor.itemID) else { return [] }
        var found: [(UUID, UUID)] = []
        for i in start..<items.count {
            if sameItemOnly && i != start { break }
            let item = items[i]
            for track in item.tracks where track.kind == .shots {
                let cues = track.cues.sorted { $0.at < $1.at }
                let fromPosition: Double
                if i == start, cursor.index >= 0 {
                    let rows = shotRows(forItem: item.id)
                    fromPosition = rows.indices.contains(cursor.index) ? rows[cursor.index].cue.at : -1
                } else {
                    fromPosition = -1
                }
                for cue in cues where cue.at > fromPosition + 1e-9 && cue.cameraID == camera {
                    found.append((item.id, cue.id))
                }
            }
        }
        // Order across items is running order; within an item by position (already).
        return Array(found.prefix(limit))
    }

    /// Camera down: moves the next `count` upcoming shots of `from` to `to`, starting after the
    /// shot on air. Returns how many shots moved.
    @discardableResult
    public mutating func reassignUpcomingShots(from: UUID, to: UUID, count: Int, after cursor: LiveCursor) -> Int {
        let targets = upcomingShots(camera: from, from: cursor, limit: max(count, 0), sameItemOnly: false)
        for (itemID, cueID) in targets {
            updateCue(cueID, inItem: itemID) { $0.cameraID = to }
        }
        return targets.count
    }
}
