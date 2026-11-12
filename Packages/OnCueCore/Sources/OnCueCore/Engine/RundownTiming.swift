import Foundation

/// When each song or segment actually ran, read from the switch log's scripted calls.
public struct ItemRun: Equatable {
    public let itemID: UUID
    public let started: Date
    /// When the next item started (nil while still running).
    public let ended: Date?

    public var length: Double? { ended.map { $0.timeIntervalSince(started) } }
}

/// Esports and corporate rundown timing: elapsed against planned for the item on air, the countdown
/// to its hard out, how far the show is over or under, and whether the next hard out will be made.
public struct RundownTiming: Equatable {
    public let itemID: UUID
    public let planned: Double?
    public let elapsed: Double?
    /// planned − elapsed; negative when over.
    public var remaining: Double? {
        guard let planned, let elapsed else { return nil }
        return planned - elapsed
    }
    /// Seconds until the item on air must be off (negative once past it).
    public let hardOutIn: Double?
    /// Finished items with a planned length: actual minus planned, summed. Positive = over.
    public let showOffset: Double
    public let finishedPlanned: Int
    /// When the show ends at the planned lengths from here.
    public let forecastEnd: Date?
    /// The next hard out still ahead (this item or a later one) and how much room there is
    /// (negative = will be late).
    public let nextHardOut: (title: String, deadline: Date, margin: Double)?

    public static func == (a: RundownTiming, b: RundownTiming) -> Bool {
        a.itemID == b.itemID && a.planned == b.planned && a.elapsed == b.elapsed && a.hardOutIn == b.hardOutIn
            && a.showOffset == b.showOffset && a.forecastEnd == b.forecastEnd
            && a.nextHardOut?.title == b.nextHardOut?.title && a.nextHardOut?.margin == b.nextHardOut?.margin
    }

    /// Item runs on the main output, in order. A jump back to an earlier item starts a new run.
    public static func runs(log: SwitchLog, mainOutput: UUID?) -> [ItemRun] {
        let calls = log.scripted.filter { mainOutput == nil || $0.outputID == nil || $0.outputID == mainOutput }
            .sorted { $0.date < $1.date }
        var starts: [(UUID, Date)] = []
        for call in calls {
            guard let item = call.itemID else { continue }
            if starts.last?.0 != item { starts.append((item, call.date)) }
        }
        return starts.enumerated().map { k, s in
            ItemRun(itemID: s.0, started: s.1, ended: k + 1 < starts.count ? starts[k + 1].1 : nil)
        }
    }

    /// The deadline for an "HH:MM" hard out nearest to `reference`, between 6 hours past and
    /// 18 hours ahead (so shows running past midnight work).
    public static func deadline(_ hhmm: String, around reference: Date, calendar: Calendar = .current) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: reference)
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.second = parts.count > 2 ? parts[2] : 0
        guard var d = calendar.date(from: comps) else { return nil }
        // Up to 18 hours ahead or 6 hours past: an evening hard out seen in the morning is
        // tonight's, and "00:15" seen at 23:30 is in 45 minutes.
        if d.timeIntervalSince(reference) < -6 * 3600 { d = d.addingTimeInterval(24 * 3600) }
        if d.timeIntervalSince(reference) > 18 * 3600 { d = d.addingTimeInterval(-24 * 3600) }
        return d
    }

    /// Planned length in seconds: the planned duration, or the script's length for timed songs.
    public static func plannedLength(_ item: RundownItem, show: Show) -> Double? {
        if item.plannedDuration > 0 { return item.plannedDuration }
        return show.runLength(forItem: item.id)
    }

    public init(show: Show, log: SwitchLog, itemID: UUID, now: Date, calendar: Calendar = .current) {
        self.itemID = itemID
        let item = show.item(itemID)
        let runs = Self.runs(log: log, mainOutput: show.mainOutput?.id)
        let current = runs.last.flatMap { $0.itemID == itemID && $0.ended == nil ? $0 : nil }
        planned = item.flatMap { $0.plannedDuration > 0 ? $0.plannedDuration : nil }
        elapsed = current.map { now.timeIntervalSince($0.started) }
        hardOutIn = item.flatMap { $0.hardOut.isEmpty ? nil : Self.deadline($0.hardOut, around: now, calendar: calendar) }
            .map { $0.timeIntervalSince(now) }

        var offset = 0.0
        var counted = 0
        for run in runs {
            guard let length = run.length, let it = show.item(run.itemID), it.plannedDuration > 0 else { continue }
            offset += length - it.plannedDuration
            counted += 1
        }
        showOffset = offset
        finishedPlanned = counted

        // Forecast: the rest of this item at plan (at least what has run), then every later item.
        guard let index = show.itemIndex(itemID) else {
            forecastEnd = nil
            nextHardOut = nil
            return
        }
        var t = now
        if let item {
            let plan = Self.plannedLength(item, show: show) ?? 0
            t = t.addingTimeInterval(max(plan - (elapsed ?? 0), 0))
        }
        var next: (String, Date, Double)?
        if let item, !item.hardOut.isEmpty, let d = Self.deadline(item.hardOut, around: now, calendar: calendar) {
            next = (item.title, d, d.timeIntervalSince(t))
        }
        for later in show.items.dropFirst(index + 1) {
            t = t.addingTimeInterval(Self.plannedLength(later, show: show) ?? 0)
            if next == nil, !later.hardOut.isEmpty, let d = Self.deadline(later.hardOut, around: now, calendar: calendar) {
                next = (later.title, d, d.timeIntervalSince(t))
            }
        }
        forecastEnd = t
        nextHardOut = next.map { (title: $0.0, deadline: $0.1, margin: $0.2) }
    }

    /// True when any item has a planned length or a hard out, so the timing is worth showing.
    public static func applies(to show: Show) -> Bool {
        show.items.contains { $0.plannedDuration > 0 || !$0.hardOut.isEmpty }
    }
}
