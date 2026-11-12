import Foundation

// Editing operations for the scripting workspace. All show changes made by the app go through
// these functions, so they can be unit-tested without any UI.

public enum ShowEditError: LocalizedError, Equatable {
    case cameraNumberTaken(Int)
    case invalidCameraNumber

    public var errorDescription: String? {
        switch self {
        case .cameraNumberTaken(let n): return "Camera \(n) already exists. Pick another number."
        case .invalidCameraNumber: return "Camera numbers start at 1."
        }
    }
}

/// Something a director would want to notice in a script. Shown subtly, never blocking.
public struct ScriptIssue: Hashable {
    public enum Kind: Hashable { case noCamera, cameraMissing, sameCameraAsPrevious, tooShort }
    public let kind: Kind
    public let message: String
}

/// One row of a shot list: a cue on the main output's shots track, with derived information.
public struct ShotRow: Identifiable, Hashable {
    public var id: UUID { cue.id }
    public let cue: Cue
    /// 1-based shot number within the song or segment.
    public let number: Int
    public let sectionID: UUID?
    /// Time until the next shot, when it can be known from the time base.
    public let lengthSeconds: Double?
    public let issues: [ScriptIssue]
}

/// Shots grouped under the section they fall in. `section == nil` holds shots before the first section.
public struct ShotGroup: Identifiable, Hashable {
    public var id: String { section?.id.uuidString ?? "before-first-section" }
    public let section: SongSection?
    public let rows: [ShotRow]
}

extension Show {

    // MARK: - Lookups

    public func item(_ id: UUID?) -> RundownItem? {
        guard let i = itemIndex(id) else { return nil }
        return items[i]
    }

    public var sortedCameras: [Camera] { cameras.sorted { $0.number < $1.number } }

    public var nextFreeCameraNumber: Int {
        let used = Set(cameras.map(\.number))
        var n = 1
        while used.contains(n) { n += 1 }
        return n
    }

    /// Grid step used for new shots: one bar, five seconds, or one step.
    public static func step(for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars: return Double(max(item.beatsPerBar, 1))
        case .seconds: return 5
        case .order: return 1
        }
    }

    /// Length given to a new section: eight bars, thirty seconds, or ten steps.
    public static func defaultSectionLength(for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars: return Double(max(item.beatsPerBar, 1) * 8)
        case .seconds: return 30
        case .order: return 10
        }
    }

    // MARK: - Running order

    @discardableResult
    public mutating func addSong(title: String? = nil, after: UUID? = nil) -> UUID {
        if outputs.isEmpty { ensureOutput() }
        let n = items.filter { $0.kind == .song }.count + 1
        return insertItem(RundownItem.newSong(title: title ?? "Song \(n)", show: self), after: after)
    }

    @discardableResult
    public mutating func addSegment(title: String? = nil, after: UUID? = nil) -> UUID {
        if outputs.isEmpty { ensureOutput() }
        let n = items.filter { $0.kind == .segment }.count + 1
        return insertItem(RundownItem.newSegment(title: title ?? "Segment \(n)", show: self), after: after)
    }

    private mutating func insertItem(_ item: RundownItem, after: UUID?) -> UUID {
        if let after, let i = itemIndex(after) {
            items.insert(item, at: i + 1)
        } else {
            items.append(item)
        }
        return item.id
    }

    public mutating func updateItem(_ id: UUID, _ change: (inout RundownItem) -> Void) {
        guard let i = itemIndex(id) else { return }
        change(&items[i])
    }

    public mutating func renameItem(_ id: UUID, to title: String) {
        updateItem(id) { $0.title = title }
    }

    public mutating func deleteItems(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        comments.removeAll { c in c.itemID.map(ids.contains) ?? false }
    }

    public mutating func moveItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        items = Self.moved(items, fromOffsets: source, toOffset: destination)
    }

    /// Copies a song or segment with fresh identities, placed right after the original.
    @discardableResult
    public mutating func duplicateItem(_ id: UUID) -> UUID? {
        guard let original = item(id) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.title = original.title + " copy"
        copy.sections = copy.sections.map { var s = $0; s.id = UUID(); return s }
        copy.tracks = copy.tracks.map { t in
            var t = t
            t.id = UUID()
            t.cues = t.cues.map { var c = $0; c.id = UUID(); return c }
            return t
        }
        return insertItem(copy, after: id)
    }

    /// Changes how positions are measured, converting every section and cue so timing is kept.
    public mutating func setTimeBase(_ base: TimeBase, forItem id: UUID) {
        guard let i = itemIndex(id), items[i].timeBase != base else { return }
        let old = items[i]
        let bpm = max(old.bpm, 1)

        func seconds(_ p: Double) -> Double {
            switch old.timeBase {
            case .bars: return p * 60 / bpm
            case .seconds: return p
            case .order: return max(0, (p - 1) * 5)
            }
        }

        if base == .order {
            items[i].timeBase = .order
            // Ranks preserve order; normalizeOrder does the rest.
            items[i].sections = old.sections.map { var s = $0; s.at = seconds(s.at); return s }
            for t in items[i].tracks.indices {
                items[i].tracks[t].cues = old.tracks[t].cues.map { var c = $0; c.at = seconds(c.at); return c }
            }
            normalizeOrder(itemIndex: i)
            return
        }

        func convert(_ p: Double) -> Double {
            let s = seconds(p)
            return base == .bars ? s * bpm / 60 : s
        }
        items[i].timeBase = base
        items[i].sections = old.sections.map { var s = $0; s.at = convert(s.at); return s }
        for t in items[i].tracks.indices {
            items[i].tracks[t].cues = old.tracks[t].cues.map { var c = $0; c.at = convert(c.at); return c }
        }
    }

    // MARK: - Sections

    @discardableResult
    public mutating func addSection(toItem id: UUID, name: String? = nil, at position: Double? = nil) -> UUID? {
        guard let i = itemIndex(id) else { return nil }
        let item = items[i]
        let pos: Double
        if let position {
            pos = position
        } else {
            let length = Self.defaultSectionLength(for: item)
            let afterSections = (item.sortedSections.last?.at).map { $0 + length } ?? 0
            let afterShots = item.tracks.flatMap(\.cues).map(\.at).max().map { $0 + Self.step(for: item) } ?? 0
            pos = max(afterSections, afterShots)
        }
        let section = SongSection(name: name ?? "Section \(item.sections.count + 1)", at: pos)
        items[i].sections.append(section)
        if item.timeBase == .order { normalizeOrder(itemIndex: i) }
        return section.id
    }

    public mutating func renameSection(_ sectionID: UUID, inItem id: UUID, to name: String) {
        updateSection(sectionID, inItem: id) { $0.name = name }
    }

    public mutating func setSectionPosition(_ sectionID: UUID, inItem id: UUID, to position: Double) {
        updateSection(sectionID, inItem: id) { $0.at = max(0, position) }
    }

    private mutating func updateSection(_ sectionID: UUID, inItem id: UUID, _ change: (inout SongSection) -> Void) {
        guard let i = itemIndex(id), let s = items[i].sections.firstIndex(where: { $0.id == sectionID }) else { return }
        change(&items[i].sections[s])
    }

    /// Removes a section marker. Its shots stay, and fall into the section before it.
    public mutating func deleteSection(_ sectionID: UUID, inItem id: UUID) {
        guard let i = itemIndex(id) else { return }
        items[i].sections.removeAll { $0.id == sectionID }
    }

    /// Rearranges the song structure: sections move together with their shots, keeping each
    /// section's length. Offsets refer to the sections in time order.
    public mutating func moveSections(inItem id: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let i = itemIndex(id) else { return }
        let item = items[i]
        let secs = item.sortedSections
        guard secs.count > 1 else { return }

        let allPositions = item.tracks.flatMap(\.cues).map(\.at)
        var spans: [UUID: (start: Double, length: Double)] = [:]
        for (k, s) in secs.enumerated() {
            let end: Double
            if k + 1 < secs.count {
                end = secs[k + 1].at
            } else {
                let lastInside = allPositions.filter { $0 >= s.at }.max()
                end = max(lastInside.map { $0 + Self.step(for: item) } ?? s.at, s.at + Self.defaultSectionLength(for: item))
            }
            spans[s.id] = (s.at, max(end - s.at, 0))
        }

        let newOrder = Self.moved(secs, fromOffsets: source, toOffset: destination)
        var cursor = secs[0].at
        var shift: [UUID: Double] = [:]
        for s in newOrder {
            guard let span = spans[s.id] else { continue }
            shift[s.id] = cursor - span.start
            cursor += span.length
        }

        func owner(_ p: Double) -> UUID? { secs.last { $0.at <= p + 1e-9 }?.id }

        for t in items[i].tracks.indices {
            for c in items[i].tracks[t].cues.indices {
                let p = item.tracks[t].cues[c].at
                if let o = owner(p), let d = shift[o] { items[i].tracks[t].cues[c].at = p + d }
            }
            items[i].tracks[t].sortCues()
        }
        for s in items[i].sections.indices {
            let sid = items[i].sections[s].id
            if let d = shift[sid] { items[i].sections[s].at += d }
        }
        if item.timeBase == .order { normalizeOrder(itemIndex: i) }
    }

    // MARK: - Cameras

    @discardableResult
    public mutating func addCamera(number: Int? = nil) -> UUID {
        let n = number ?? nextFreeCameraNumber
        let cam = Camera(number: n, switcherID: mainOutput?.switcherID ?? switchers.first?.id, input: n)
        cameras.append(cam)
        return cam.id
    }

    public mutating func updateCamera(_ id: UUID, _ change: (inout Camera) -> Void) {
        guard let i = cameras.firstIndex(where: { $0.id == id }) else { return }
        let number = cameras[i].number
        change(&cameras[i])
        cameras[i].number = number // numbers change only through renumberCamera
    }

    public mutating func renumberCamera(_ id: UUID, to number: Int) throws {
        guard number > 0 else { throw ShowEditError.invalidCameraNumber }
        guard let i = cameras.firstIndex(where: { $0.id == id }) else { return }
        if cameras.contains(where: { $0.number == number && $0.id != id }) {
            throw ShowEditError.cameraNumberTaken(number)
        }
        cameras[i].number = number
    }

    /// Number of shots across the whole show that use this camera.
    public func shotCount(forCamera id: UUID) -> Int {
        items.reduce(0) { total, item in
            total + item.tracks.filter { $0.kind == .shots }.flatMap(\.cues).filter { $0.cameraID == id }.count
        }
    }

    /// Deletes a camera. Shots that used it keep their place but lose their camera.
    /// Returns how many shots were affected.
    @discardableResult
    public mutating func deleteCamera(_ id: UUID) -> Int {
        var affected = 0
        plot.markers.removeAll { $0.cameraID == id }
        for i in items.indices {
            for t in items[i].tracks.indices {
                for c in items[i].tracks[t].cues.indices where items[i].tracks[t].cues[c].cameraID == id {
                    items[i].tracks[t].cues[c].cameraID = nil
                    affected += 1
                }
            }
        }
        cameras.removeAll { $0.id == id }
        return affected
    }

    // MARK: - Shots

    private mutating func ensureOutput() {
        outputs.append(OutputConfig(name: "Program", switcherID: switchers.first?.id))
    }

    /// The shots track the shot list edits (the main output's), created if missing.
    @discardableResult
    public mutating func ensureMainShotTrack(inItem id: UUID) -> UUID? {
        if outputs.isEmpty { ensureOutput() }
        ensureShotTracks()
        return mainShotTrackID(inItem: id)
    }

    public func mainShotTrackID(inItem id: UUID) -> UUID? {
        item(id)?.shotsTrack(for: mainOutput?.id)?.id
    }

    public func shotRows(forItem id: UUID) -> [ShotRow] {
        guard let item = item(id), let track = item.shotsTrack(for: mainOutput?.id) else { return [] }
        let cues = track.cues.sorted { $0.at < $1.at }
        let cameraIDs = Set(cameras.map(\.id))
        let timed = item.timeBase != .order
        // Sections sorted once and walked alongside the sorted shots (large scripts have
        // thousands of shots; looking the section up per shot was the slow part).
        let sections = item.sortedSections
        var sectionIndex = -1
        var rows: [ShotRow] = []
        rows.reserveCapacity(cues.count)
        for (k, cue) in cues.enumerated() {
            while sectionIndex + 1 < sections.count, sections[sectionIndex + 1].at <= cue.at + 1e-9 { sectionIndex += 1 }
            let sectionID = sectionIndex >= 0 ? sections[sectionIndex].id : nil
            let next = k + 1 < cues.count ? cues[k + 1].at : nil
            let length = (timed && next != nil) ? item.seconds(for: next! - cue.at) : nil
            var issues: [ScriptIssue] = []
            if let cam = cue.cameraID {
                if !cameraIDs.contains(cam) {
                    issues.append(ScriptIssue(kind: .cameraMissing, message: "This camera was deleted"))
                } else if k > 0, cues[k - 1].cameraID == cam {
                    issues.append(ScriptIssue(kind: .sameCameraAsPrevious, message: "Same camera as the shot before"))
                }
            } else {
                issues.append(ScriptIssue(kind: .noCamera, message: "No camera chosen"))
            }
            if let length, length < settings.minShotSeconds {
                issues.append(ScriptIssue(kind: .tooShort, message: String(format: "Shorter than %.1f s", settings.minShotSeconds)))
            }
            rows.append(ShotRow(cue: cue, number: k + 1, sectionID: sectionID,
                                lengthSeconds: length, issues: issues))
        }
        return rows
    }

    public func shotGroups(forItem id: UUID) -> [ShotGroup] {
        guard let item = item(id) else { return [] }
        let rows = shotRows(forItem: id)
        var bySection: [UUID?: [ShotRow]] = [:]
        for row in rows { bySection[row.sectionID, default: []].append(row) }
        var groups: [ShotGroup] = []
        let before = bySection[nil] ?? []
        if !before.isEmpty || item.sections.isEmpty {
            groups.append(ShotGroup(section: nil, rows: before))
        }
        for s in item.sortedSections {
            groups.append(ShotGroup(section: s, rows: bySection[s.id] ?? []))
        }
        return groups
    }

    /// Cameras not used by any shot in this song or segment.
    public func unusedCameras(inItem id: UUID) -> [Camera] {
        let used = Set(shotRows(forItem: id).compactMap(\.cue.cameraID))
        return sortedCameras.filter { !used.contains($0.id) }
    }

    /// Where a new shot goes: after a given shot, at the end of a section, or at the end.
    public func newShotPosition(inItem id: UUID, after cueID: UUID? = nil, inSection sectionID: UUID? = nil) -> Double {
        guard let item = item(id) else { return 0 }
        let step = Self.step(for: item)
        let positions = shotRows(forItem: id).map(\.cue.at)
        let sectionStarts = item.sortedSections.map(\.at)

        func place(after a: Double) -> Double {
            let candidate = a + step
            let limit = (positions.filter { $0 > a + 1e-9 } + sectionStarts.filter { $0 > a + 1e-9 }).min()
            if let limit, candidate >= limit - 1e-9 { return (a + limit) / 2 }
            return candidate
        }

        if let cueID, let a = shotRows(forItem: id).first(where: { $0.id == cueID })?.cue.at {
            return place(after: a)
        }
        if let sectionID, let section = item.sections.first(where: { $0.id == sectionID }) {
            let end = item.sectionEnd(section) ?? .infinity
            let inside = positions.filter { $0 >= section.at - 1e-9 && $0 < end }
            if let last = inside.max() { return place(after: last) }
            return section.at
        }
        if let last = positions.max() { return place(after: last) }
        return item.timeBase == .order ? 1 : 0
    }

    @discardableResult
    public mutating func addShot(inItem id: UUID, after cueID: UUID? = nil, inSection sectionID: UUID? = nil,
                                 cameraID: UUID? = nil, at position: Double? = nil) -> UUID? {
        guard let trackID = ensureMainShotTrack(inItem: id), let i = itemIndex(id),
              let t = items[i].tracks.firstIndex(where: { $0.id == trackID }) else { return nil }
        let pos = position ?? newShotPosition(inItem: id, after: cueID, inSection: sectionID)
        let cue = Cue(at: pos, cameraID: cameraID)
        items[i].tracks[t].cues.append(cue)
        items[i].tracks[t].sortCues()
        if items[i].timeBase == .order { normalizeOrder(itemIndex: i) }
        return cue.id
    }

    /// Edits a cue on any track of the item.
    public mutating func updateCue(_ cueID: UUID, inItem id: UUID, _ change: (inout Cue) -> Void) {
        guard let i = itemIndex(id) else { return }
        for t in items[i].tracks.indices {
            if let c = items[i].tracks[t].cues.firstIndex(where: { $0.id == cueID }) {
                change(&items[i].tracks[t].cues[c])
                items[i].tracks[t].sortCues()
                if items[i].timeBase == .order { normalizeOrder(itemIndex: i) }
                return
            }
        }
    }

    public mutating func setCamera(_ cameraID: UUID?, forCues ids: Set<UUID>, inItem id: UUID) {
        guard let i = itemIndex(id) else { return }
        for t in items[i].tracks.indices {
            for c in items[i].tracks[t].cues.indices where ids.contains(items[i].tracks[t].cues[c].id) {
                items[i].tracks[t].cues[c].cameraID = cameraID
            }
        }
    }

    public mutating func setTransition(_ transition: TransitionKind, forCues ids: Set<UUID>, inItem id: UUID) {
        guard let i = itemIndex(id) else { return }
        for t in items[i].tracks.indices {
            for c in items[i].tracks[t].cues.indices where ids.contains(items[i].tracks[t].cues[c].id) {
                items[i].tracks[t].cues[c].transition = transition
            }
        }
    }

    public mutating func deleteCues(_ ids: Set<UUID>, inItem id: UUID) {
        guard let i = itemIndex(id) else { return }
        for t in items[i].tracks.indices {
            items[i].tracks[t].cues.removeAll { ids.contains($0.id) }
        }
        comments.removeAll { c in c.cueID.map(ids.contains) ?? false }
        if items[i].timeBase == .order { normalizeOrder(itemIndex: i) }
    }

    /// Duplicates shots, each placed right after its original. Returns the new IDs in order.
    @discardableResult
    public mutating func duplicateCues(_ ids: Set<UUID>, inItem id: UUID) -> [UUID] {
        let originals = shotRows(forItem: id).filter { ids.contains($0.id) }.map(\.cue)
        var created: [UUID] = []
        for original in originals.reversed() {
            let pos = newShotPosition(inItem: id, after: original.id)
            if let newID = addShot(inItem: id, cameraID: original.cameraID, at: pos) {
                updateCue(newID, inItem: id) { c in
                    c.text = original.text
                    c.note = original.note
                    c.transition = original.transition
                }
                created.insert(newID, at: 0)
            }
        }
        return created
    }

    /// Drag-and-drop reorder within a section's shot list. The time slots stay where they are and
    /// the shots move between them, so the song's cutting rhythm is kept.
    /// Offsets refer to the rows of that section (or of the shots before the first section).
    public mutating func moveShots(inItem id: UUID, section sectionID: UUID?, fromOffsets source: IndexSet, toOffset destination: Int) {
        let rows = shotRows(forItem: id).filter { $0.sectionID == sectionID }
        guard rows.count > 1, let i = itemIndex(id),
              let trackID = mainShotTrackID(inItem: id),
              let t = items[i].tracks.firstIndex(where: { $0.id == trackID }) else { return }
        let slots = rows.map(\.cue.at)
        let reordered = Self.moved(rows.map(\.cue.id), fromOffsets: source, toOffset: destination)
        var newPosition: [UUID: Double] = [:]
        for (k, cueID) in reordered.enumerated() { newPosition[cueID] = slots[k] }
        for c in items[i].tracks[t].cues.indices {
            if let p = newPosition[items[i].tracks[t].cues[c].id] { items[i].tracks[t].cues[c].at = p }
        }
        items[i].tracks[t].sortCues()
    }

    /// Moves one shot up or down by swapping time slots with its neighbour.
    public mutating func nudgeShot(_ cueID: UUID, inItem id: UUID, by delta: Int) {
        let rows = shotRows(forItem: id)
        guard let k = rows.firstIndex(where: { $0.id == cueID }) else { return }
        let target = k + delta
        guard target >= 0, target < rows.count else { return }
        let a = rows[k].cue.at, b = rows[target].cue.at
        let other = rows[target].id
        updateCue(cueID, inItem: id) { $0.at = b }
        updateCue(other, inItem: id) { $0.at = a }
    }

    // MARK: - Helpers

    /// In order-based items, positions are kept as 1, 2, 3... after every change.
    mutating func normalizeOrder(itemIndex i: Int) {
        guard items[i].timeBase == .order else { return }
        let positions = Array(Set(items[i].tracks.flatMap(\.cues).map(\.at))).sorted()
        var rank: [Double: Double] = [:]
        for (k, p) in positions.enumerated() { rank[p] = Double(k + 1) }
        let originalSections = items[i].sections
        for t in items[i].tracks.indices {
            for c in items[i].tracks[t].cues.indices {
                let p = items[i].tracks[t].cues[c].at
                items[i].tracks[t].cues[c].at = rank[p] ?? p
            }
            items[i].tracks[t].sortCues()
        }
        for s in items[i].sections.indices {
            let at = originalSections[s].at
            let firstAfter = positions.firstIndex { $0 >= at - 1e-9 }
            items[i].sections[s].at = Double((firstAfter ?? positions.count) + 1)
        }
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, without needing SwiftUI.
    static func moved<T>(_ array: [T], fromOffsets source: IndexSet, toOffset destination: Int) -> [T] {
        let moving = source.sorted().filter { $0 < array.count }.map { array[$0] }
        var rest: [T] = []
        for (k, element) in array.enumerated() where !source.contains(k) { rest.append(element) }
        let insertAt = min(max(destination - source.filter { $0 < destination }.count, 0), rest.count)
        rest.insert(contentsOf: moving, at: insertAt)
        return rest
    }
}
