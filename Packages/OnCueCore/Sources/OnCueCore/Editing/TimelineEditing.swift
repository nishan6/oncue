import Foundation

// Timeline support for the scripting workspace: where blocks start and end, snapping, and editing
// the cues of the lyrics, notes and FX tracks.

/// A shot drawn on the timeline: from its own position to the next shot (the last runs to the song end).
public struct ShotSpan: Identifiable, Hashable {
    public var id: UUID { row.id }
    public let row: ShotRow
    public let start: Double
    public let end: Double
}

/// A section drawn on the timeline: from its start to the next section (the last runs to the song end).
public struct SectionSpan: Identifiable, Hashable {
    public var id: UUID { section.id }
    public let section: SongSection
    public let start: Double
    public let end: Double
}

extension Show {

    // MARK: - Snapping

    /// Smallest step positions snap to: one beat, half a second, or one step.
    public static func snapUnit(for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars: return 1
        case .seconds: return 0.5
        case .order: return 1
        }
    }

    public static func snap(_ position: Double, for item: RundownItem) -> Double {
        let unit = snapUnit(for: item)
        let snapped = (position / unit).rounded() * unit
        return item.timeBase == .order ? max(1, snapped) : max(0, snapped)
    }

    // MARK: - Lengths

    /// The planned length of the item in its own time base, when one is set.
    public static func plannedEnd(for item: RundownItem) -> Double? {
        guard item.plannedDuration > 0 else { return nil }
        switch item.timeBase {
        case .bars: return item.plannedDuration * max(item.bpm, 1) / 60
        case .seconds: return item.plannedDuration
        case .order: return nil
        }
    }

    /// Where the song or segment ends on the timeline: the end of its last section, its planned
    /// length, or just after its last cue, whichever is latest.
    public func itemEnd(forItem id: UUID) -> Double {
        guard let item = item(id) else { return 0 }
        let step = Self.step(for: item)
        var end: Double = 0
        if let last = item.sortedSections.last { end = max(end, last.at + Self.defaultSectionLength(for: item)) }
        if let planned = Self.plannedEnd(for: item) { end = max(end, planned) }
        if let lastCue = item.tracks.flatMap(\.cues).map(\.at).max() { end = max(end, lastCue + step) }
        if item.timeBase == .order {
            // One step per position: the last shot occupies one step.
            let lastCue = item.tracks.flatMap(\.cues).map(\.at).max() ?? 0
            end = max(lastCue + 1, (item.sortedSections.last?.at ?? 1) + 1)
        }
        return end
    }

    /// The main output's shots as timeline blocks.
    public func shotSpans(forItem id: UUID) -> [ShotSpan] {
        let rows = shotRows(forItem: id)
        let end = itemEnd(forItem: id)
        return rows.enumerated().map { k, row in
            let next = k + 1 < rows.count ? rows[k + 1].cue.at : end
            return ShotSpan(row: row, start: row.cue.at, end: max(next, row.cue.at))
        }
    }

    public func sectionSpans(forItem id: UUID) -> [SectionSpan] {
        guard let item = item(id) else { return [] }
        let sections = item.sortedSections
        let end = itemEnd(forItem: id)
        return sections.enumerated().map { k, s in
            let next = k + 1 < sections.count ? sections[k + 1].at : end
            return SectionSpan(section: s, start: s.at, end: max(next, s.at))
        }
    }

    // MARK: - Lyrics, notes and FX tracks

    /// The first track of a kind in the item, created if missing. Shots use the main output's track.
    @discardableResult
    public mutating func ensureTrack(_ kind: TrackKind, inItem id: UUID) -> UUID? {
        if kind == .shots { return ensureMainShotTrack(inItem: id) }
        guard let i = itemIndex(id) else { return nil }
        if let existing = items[i].tracks.first(where: { $0.kind == kind }) { return existing.id }
        let name: String
        switch kind {
        case .lyrics: name = "Lyrics"
        case .notes: name = "Notes"
        case .fx: name = "FX"
        case .control: name = "Control"
        case .osc: name = "OSC"
        case .ptz: name = "PTZ"
        default: name = kind.label
        }
        let track = Track(kind: kind, name: name, switcherID: kind == .fx ? mainOutput?.switcherID : nil)
        items[i].tracks.append(track)
        return track.id
    }

    /// Cues of the first track of a kind, in time order.
    public func trackCues(_ kind: TrackKind, inItem id: UUID) -> [Cue] {
        guard let item = item(id) else { return [] }
        let track = kind == .shots ? item.shotsTrack(for: mainOutput?.id) : item.tracks.first { $0.kind == kind }
        return (track?.cues ?? []).sorted { $0.at < $1.at }
    }

    /// Adds a lyric line, note or FX cue at a position. Shots go through `addShot`.
    @discardableResult
    public mutating func addTrackCue(_ kind: TrackKind, inItem id: UUID, at position: Double, text: String = "") -> UUID? {
        if kind == .shots { return addShot(inItem: id, at: position) }
        guard let trackID = ensureTrack(kind, inItem: id), let i = itemIndex(id),
              let t = items[i].tracks.firstIndex(where: { $0.id == trackID }) else { return nil }
        var cue = Cue(at: max(0, position))
        cue.text = text
        switch kind {
        case .fx: cue.fxAction = .macro
        case .control: cue.controlAction = .loadNext
        case .osc: cue.oscTargetID = oscTargets.first?.id
        case .ptz: cue.ptzCameraID = ptzCameras.first?.id
        default: break
        }
        items[i].tracks[t].cues.append(cue)
        items[i].tracks[t].sortCues()
        if items[i].timeBase == .order { normalizeOrder(itemIndex: i) }
        return cue.id
    }

    /// The kind of track a cue sits on.
    public func trackKind(ofCue cueID: UUID, inItem id: UUID) -> TrackKind? {
        item(id)?.tracks.first { $0.cues.contains { $0.id == cueID } }?.kind
    }

    public func cue(_ cueID: UUID, inItem id: UUID) -> Cue? {
        item(id)?.tracks.lazy.flatMap(\.cues).first { $0.id == cueID }
    }

    /// Moves a cue on any track to a new position.
    public mutating func moveCue(_ cueID: UUID, inItem id: UUID, to position: Double) {
        updateCue(cueID, inItem: id) { $0.at = max(0, position) }
    }
}

extension Show {
    /// How long the song or segment runs, in seconds, when its time base allows knowing it.
    public func runLength(forItem id: UUID) -> Double? {
        guard let item = item(id), item.timeBase != .order else { return nil }
        let end = itemEnd(forItem: id)
        return end > 0 ? item.seconds(for: end) : nil
    }
}

// MARK: - Other outputs' shots tracks

extension Show {
    /// Shots of a separate output (its own track) as timeline blocks.
    public func shotSpans(forItem id: UUID, outputID: UUID) -> [ShotSpan] {
        guard let item = item(id), let track = item.shotsTrack(for: outputID) else { return [] }
        let cues = track.cues.sorted { $0.at < $1.at }
        let end = itemEnd(forItem: id)
        let timed = item.timeBase != .order
        return cues.enumerated().map { k, cue in
            let next = k + 1 < cues.count ? cues[k + 1].at : end
            let row = ShotRow(cue: cue, number: k + 1, sectionID: item.section(at: cue.at)?.id,
                              lengthSeconds: timed && k + 1 < cues.count ? item.seconds(for: next - cue.at) : nil, issues: [])
            return ShotSpan(row: row, start: cue.at, end: max(next, cue.at))
        }
    }

    /// Adds a shot to a separate output's own track.
    @discardableResult
    public mutating func addShot(inItem id: UUID, outputID: UUID, cameraID: UUID?, at position: Double) -> UUID? {
        ensureShotTracks()
        guard let i = itemIndex(id), let t = items[i].tracks.firstIndex(where: { $0.kind == .shots && $0.outputID == outputID }) else { return nil }
        let cue = Cue(at: max(0, position), cameraID: cameraID)
        items[i].tracks[t].cues.append(cue)
        items[i].tracks[t].sortCues()
        if items[i].timeBase == .order { normalizeOrder(itemIndex: i) }
        return cue.id
    }

    /// The output a shots-track cue belongs to (nil for other tracks).
    public func outputID(ofCue cueID: UUID, inItem id: UUID) -> UUID? {
        item(id)?.tracks.first { $0.kind == .shots && $0.cues.contains { $0.id == cueID } }?.outputID
    }
}

// MARK: - Switchers and outputs

extension Show {
    @discardableResult
    public mutating func addSwitcher(name: String, kind: SwitcherKind, role: SwitcherRole) -> UUID {
        var config = SwitcherConfig(name: name, kind: kind, role: role)
        if role == .sub { config.parentID = mainOutput?.switcherID }
        switchers.append(config)
        if role == .output {
            outputs.append(OutputConfig(name: name, switcherID: config.id))
            ensureShotTracks()
        }
        return config.id
    }

    /// Deletes a switcher. Outputs on it are removed with their tracks; cameras on it move to the
    /// main switcher; sub-switchers fed into it lose their parent.
    public mutating func deleteSwitcher(_ id: UUID) {
        guard id != mainOutput?.switcherID else { return }
        let removedOutputs = Set(outputs.filter { $0.switcherID == id }.map(\.id))
        outputs.removeAll { removedOutputs.contains($0.id) }
        for i in items.indices {
            items[i].tracks.removeAll { $0.kind == .shots && removedOutputs.contains($0.outputID ?? UUID()) }
        }
        for c in cameras.indices {
            if cameras[c].switcherID == id { cameras[c].switcherID = mainOutput?.switcherID }
            cameras[c].extraInputs.removeAll { $0.switcherID == id }
        }
        for s in switchers.indices where switchers[s].parentID == id { switchers[s].parentID = nil }
        switchers.removeAll { $0.id == id }
    }

    @discardableResult
    public mutating func addOutput(name: String, switcherID: UUID?) -> UUID {
        let output = OutputConfig(name: name, switcherID: switcherID ?? mainOutput?.switcherID)
        outputs.append(output)
        ensureShotTracks()
        return output.id
    }

    public mutating func updateOutput(_ id: UUID, _ change: (inout OutputConfig) -> Void) {
        guard let i = outputs.firstIndex(where: { $0.id == id }) else { return }
        change(&outputs[i])
    }

    /// Deletes a separate output and its shots tracks (the main output stays).
    public mutating func deleteOutput(_ id: UUID) {
        guard id != mainOutput?.id else { return }
        outputs.removeAll { $0.id == id }
        for i in items.indices { items[i].tracks.removeAll { $0.kind == .shots && $0.outputID == id } }
    }

    /// Sets (or clears, with input 0) a camera's input on an additional switcher.
    public mutating func setExtraInput(camera: UUID, switcherID: UUID, input: Int) {
        updateCamera(camera) { cam in
            cam.extraInputs.removeAll { $0.switcherID == switcherID }
            if input > 0 { cam.extraInputs.append(CameraInput(switcherID: switcherID, input: input)) }
        }
    }
}
