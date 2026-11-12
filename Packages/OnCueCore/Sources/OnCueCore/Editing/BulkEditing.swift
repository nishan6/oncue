import Foundation

/// Grid sizes for Quantise, in the item's own time base.
public enum QuantizeGrid: String, CaseIterable, Identifiable {
    case beat, halfBar, bar, halfSecond, second
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .beat: return "Beat"
        case .halfBar: return "Half bar"
        case .bar: return "Bar"
        case .halfSecond: return "Half second"
        case .second: return "Second"
        }
    }

    public static func choices(for item: RundownItem) -> [QuantizeGrid] {
        switch item.timeBase {
        case .bars: return [.beat, .halfBar, .bar]
        case .seconds: return [.halfSecond, .second]
        case .order: return []
        }
    }

    /// Grid step in the item's time base (beats or seconds).
    public func step(for item: RundownItem) -> Double {
        let bpb = Double(max(item.beatsPerBar, 1))
        switch self {
        case .beat: return 1
        case .halfBar: return bpb / 2
        case .bar: return bpb
        case .halfSecond: return 0.5
        case .second: return 1
        }
    }
}

extension Show {
    /// Snaps the given shots to a grid. Two shots that land on the same spot on one track keep
    /// their order: the later one moves one step on.
    public mutating func quantizeShots(_ ids: Set<UUID>, inItem id: UUID, to grid: QuantizeGrid) {
        guard let i = itemIndex(id), items[i].timeBase != .order else { return }
        let step = grid.step(for: items[i])
        for t in items[i].tracks.indices where items[i].tracks[t].kind == .shots {
            var taken = Set(items[i].tracks[t].cues.filter { !ids.contains($0.id) }.map { ($0.at / step).rounded() })
            for c in items[i].tracks[t].cues.indices where ids.contains(items[i].tracks[t].cues[c].id) {
                var slot = max(0, (items[i].tracks[t].cues[c].at / step).rounded())
                while taken.contains(slot) { slot += 1 }
                taken.insert(slot)
                items[i].tracks[t].cues[c].at = slot * step
            }
            items[i].tracks[t].sortCues()
        }
    }

    /// Moves everything at or after `position` (shots and cues on every track, and sections when
    /// asked) by `delta`, to open or close a gap. Nothing moves before zero: if it would, nothing
    /// moves and false is returned.
    @discardableResult
    public mutating func moveAll(inItem id: UUID, from position: Double, by delta: Double, sections: Bool = true) -> Bool {
        guard let i = itemIndex(id), items[i].timeBase != .order, delta != 0 else { return false }
        let eps = 1e-9
        let moving = items[i].tracks.flatMap(\.cues).filter { $0.at >= position - eps }
        if let earliest = moving.map(\.at).min(), earliest + delta < -eps { return false }
        if delta < 0 {
            // Closing a gap must not run into what stays put before `position`.
            let staying = items[i].tracks.flatMap(\.cues).filter { $0.at < position - eps }.map(\.at).max()
            if let staying, let earliest = moving.map(\.at).min(), earliest + delta < staying - eps { return false }
        }
        for t in items[i].tracks.indices {
            for c in items[i].tracks[t].cues.indices where items[i].tracks[t].cues[c].at >= position - eps {
                items[i].tracks[t].cues[c].at += delta
            }
            items[i].tracks[t].sortCues()
        }
        if sections {
            for s in items[i].sections.indices where items[i].sections[s].at >= position - eps && items[i].sections[s].at > eps {
                items[i].sections[s].at = max(0, items[i].sections[s].at + delta)
            }
        }
        return true
    }

    /// Shots from `position` to the end (mark-ins at or after it).
    public func shotIDs(inItem id: UUID, from position: Double) -> [UUID] {
        shotRows(forItem: id).filter { $0.cue.at >= position - 1e-9 }.map(\.id)
    }

    /// Shots inside one section.
    public func shotIDs(inItem id: UUID, section sectionID: UUID?) -> [UUID] {
        shotRows(forItem: id).filter { $0.sectionID == sectionID }.map(\.id)
    }
}
