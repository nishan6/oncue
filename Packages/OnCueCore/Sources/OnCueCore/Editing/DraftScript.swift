import Foundation

// Drafting a script from what really happened: last show's switch log, or the EDL of an edit of
// the ISO recordings. The draft is a first pass: new songs and segments next to the originals,
// which are never overwritten, so the director keeps what works and deletes the rest.

/// One cut taken from a log or an EDL: seconds from the start of the song, and the camera.
public struct DraftCut: Equatable {
    public var seconds: Double
    public var cameraID: UUID?
}

/// A song or segment to draft, with the cuts found for it.
public struct DraftPlan: Identifiable, Equatable {
    public var id: UUID { sourceItemID ?? newID }
    /// The item the cuts came from (switch logs); nil for an EDL, which makes a new segment.
    public var sourceItemID: UUID?
    public var newID = UUID()
    public var title: String
    public var cuts: [DraftCut]
}

extension Show {
    /// One plan per song or segment that ran in the log: the main switcher's program cuts during
    /// its first run, timed from the run's start.
    public func draftPlans(from log: SwitchLog) -> [DraftPlan] {
        let mainSwitcher = mainOutput?.switcherID
        let cuts = log.cuts.filter { mainSwitcher == nil || $0.switcherID == mainSwitcher }.sorted { $0.date < $1.date }
        let runs = RundownTiming.runs(log: log, mainOutput: mainOutput?.id)
        var plans: [DraftPlan] = []
        var done = Set<UUID>()
        for run in runs where !done.contains(run.itemID) {
            guard let item = item(run.itemID) else { continue }
            done.insert(run.itemID)
            let end = run.ended ?? (cuts.last?.date ?? run.started).addingTimeInterval(0.001)
            // The camera on air when the song started counts as its first shot.
            var inRun = cuts.filter { $0.date >= run.started && $0.date < end }
            if let before = cuts.last(where: { $0.date < run.started }), inRun.first.map({ $0.date.timeIntervalSince(run.started) > 0.5 }) ?? true {
                var opening = before
                opening.date = run.started
                inRun.insert(opening, at: 0)
            }
            let draft = inRun.map { DraftCut(seconds: max(0, $0.date.timeIntervalSince(run.started)), cameraID: $0.cameraID) }
            if !draft.isEmpty {
                plans.append(DraftPlan(sourceItemID: item.id, title: item.title, cuts: draft))
            }
        }
        return plans
    }

    /// A CMX 3600 EDL as one plan: each event's record-in, from the first event, and its camera
    /// (from the reel "CAM3", or a clip name starting with the camera number).
    public func draftPlan(fromEDL text: String, fps: Int, title: String) -> DraftPlan? {
        struct Event { var record: Int; var reel: String; var clip: String = "" }
        var events: [Event] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("*") {
                if let r = line.range(of: "FROM CLIP NAME:"), !events.isEmpty {
                    events[events.count - 1].clip = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // Event, reel, track, transition (C, D, W...), [duration], source in/out, record in/out.
            guard f.count >= 8, Int(f[0]) != nil, f[2].hasPrefix("V") || f[2].hasPrefix("B") else { continue }
            let tcs = f.filter { $0.filter { $0 == ":" || $0 == ";" }.count == 3 }
            guard tcs.count >= 4, let rec = EDLTimecode.parse(tcs[2], fps: fps) else { continue }
            events.append(Event(record: rec, reel: f[1]))
        }
        guard let first = events.map(\.record).min() else { return nil }
        func camera(_ e: Event) -> UUID? {
            let reel = e.reel.uppercased()
            for prefix in ["CAM", "CAMERA", "ISO", "C"] where reel.hasPrefix(prefix) {
                if let n = Int(reel.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: "_- "))),
                   let cam = self.camera(number: n) { return cam.id }
            }
            if let n = Int(e.clip.prefix { $0.isNumber }), let cam = self.camera(number: n) { return cam.id }
            let name = e.clip.lowercased()
            return cameras.first { !name.isEmpty && name.contains($0.displayName.lowercased()) }?.id
        }
        let cuts = events.sorted { $0.record < $1.record }
            .map { DraftCut(seconds: Double($0.record - first) / Double(max(fps, 1)), cameraID: camera($0)) }
        return DraftPlan(sourceItemID: nil, title: title, cuts: cuts)
    }

    /// Adds each plan as a new song or segment right after its source (or at the end), with the
    /// source's tempo, sections and other tracks, and the drafted cuts as its shots. Returns the
    /// new items' ids.
    @discardableResult
    public mutating func applyDrafts(_ plans: [DraftPlan], label: String) -> [UUID] {
        var created: [UUID] = []
        for plan in plans {
            var item: RundownItem
            var after: UUID?
            if let source = plan.sourceItemID, let original = self.item(source) {
                guard let copyID = duplicateItem(source) else { continue }
                item = self.item(copyID)!
                after = copyID
                item.title = "\(original.title) (\(label))"
            } else {
                item = RundownItem.newSegment(title: plan.title, show: self)
                item.plannedDuration = 0
                item.syncMode = .freeRun
            }
            // Drafted shots replace the main output's shots on the copy.
            let positions: [(Double, UUID?)] = plan.cuts.enumerated().map { k, cut in
                switch item.timeBase {
                case .bars:
                    let beats = cut.seconds * max(item.bpm, 1) / 60
                    return ((beats * 4).rounded() / 4, cut.cameraID)
                case .seconds:
                    return ((cut.seconds * 10).rounded() / 10, cut.cameraID)
                case .order:
                    return (Double(k + 1), cut.cameraID)
                }
            }
            if let t = item.tracks.firstIndex(where: { $0.kind == .shots && ($0.outputID == nil || $0.outputID == mainOutput?.id) }) {
                item.tracks[t].cues = []
                var last = -Double.infinity
                for (at, cam) in positions where at > last {
                    item.tracks[t].cues.append(Cue(at: at, cameraID: cam))
                    last = at
                }
            }
            if let after, let i = itemIndex(after) {
                items[i] = item
            } else {
                items.append(item)
                ensureShotTracks()
                if let i = itemIndex(item.id), let t = items[i].tracks.firstIndex(where: { $0.kind == .shots && $0.outputID == mainOutput?.id }) {
                    var last = -Double.infinity
                    items[i].tracks[t].cues = positions.compactMap { at, cam in
                        guard at > last else { return nil }
                        last = at
                        return Cue(at: at, cameraID: cam)
                    }
                }
            }
            created.append(item.id)
        }
        return created
    }
}
