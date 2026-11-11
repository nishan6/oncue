import SwiftUI
import OnCueCore

/// Per-window state of the scripting workspace: what is selected, which panels are open, and the
/// single entry point for edits. Every change to the show goes through `edit`, which applies an
/// OnCueCore editing operation to the document and registers it with Undo. Views never change
/// the show directly.
final class WorkspaceModel: ObservableObject {
    @Published var selectedItemID: UUID? {
        didSet {
            guard oldValue != selectedItemID else { return }
            if !restoring { selectedShotIDs = [] }
            persistState()
        }
    }
    @Published var selectedShotIDs: Set<UUID> = [] { didSet { persistState() } }
    @Published var showInspector = true { didSet { persistState() } }
    @Published var cameraManagerOpen = false
    @Published var renamingItemID: UUID?
    @Published var errorMessage: String?
    /// Shot list scrolls here when set (a shot or section id).
    @Published var scrollTarget: String?

    private var read: () -> Show = { Show() }
    private var write: (Show) -> Void = { _ in }
    private weak var undoManager: UndoManager?
    private var attachedShowID: UUID?
    private var restoring = false
    private var typedNumber = ""
    private var lastDigitTime = Date.distantPast

    // MARK: - Document

    func attach(document: Binding<ShowDocument>, undoManager: UndoManager?) {
        read = { document.wrappedValue.show }
        write = { document.wrappedValue.show = $0 }
        self.undoManager = undoManager
        let show = read()
        if attachedShowID != show.id {
            attachedShowID = show.id
            restoreState(for: show)
        }
    }

    var show: Show { read() }

    /// Applies an edit as one undoable step.
    func edit(_ actionName: String, _ change: (inout Show) -> Void) {
        let before = read()
        var after = before
        change(&after)
        guard after != before else { return }
        commit(after, replacing: before, actionName: actionName)
    }

    private func commit(_ new: Show, replacing old: Show, actionName: String) {
        write(new)
        undoManager?.registerUndo(withTarget: self) { model in
            model.commit(old, replacing: new, actionName: actionName)
            model.validateSelection()
        }
        undoManager?.setActionName(actionName)
    }

    // MARK: - Selection

    var selectedItem: RundownItem? { show.item(selectedItemID) }

    /// The selected shots in time order.
    var selectedRows: [ShotRow] {
        guard let id = selectedItemID else { return [] }
        return show.shotRows(forItem: id).filter { selectedShotIDs.contains($0.id) }
    }

    func selectItem(offset: Int) {
        let items = show.items
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedItemID } ?? 0
        selectedItemID = items[min(max(current + offset, 0), items.count - 1)].id
    }

    func validateSelection() {
        let s = show
        if s.item(selectedItemID) == nil { selectedItemID = s.items.first?.id }
        if let id = selectedItemID {
            let valid = Set(s.shotRows(forItem: id).map(\.id))
            let kept = selectedShotIDs.intersection(valid)
            if kept != selectedShotIDs { selectedShotIDs = kept }
        }
    }

    /// Tally for the camera tiles: red = camera of the selected shot, green = camera of the next shot.
    func tally(forCamera cameraID: UUID) -> TallyState {
        guard let id = selectedItemID, selectedShotIDs.count == 1, let sel = selectedShotIDs.first else { return .off }
        let rows = show.shotRows(forItem: id)
        guard let k = rows.firstIndex(where: { $0.id == sel }) else { return .off }
        if rows[k].cue.cameraID == cameraID { return .current }
        if k + 1 < rows.count, rows[k + 1].cue.cameraID == cameraID { return .next }
        return .off
    }

    /// Tally for a shot row: red = the selected shot, green = the shot after it.
    func tally(forShot shotID: UUID, in rows: [ShotRow]) -> TallyState {
        guard selectedShotIDs.count == 1, let sel = selectedShotIDs.first else { return .off }
        if shotID == sel { return .current }
        if let k = rows.firstIndex(where: { $0.id == sel }), k + 1 < rows.count, rows[k + 1].id == shotID { return .next }
        return .off
    }

    // MARK: - Production and running order

    func renameShow(_ name: String) {
        edit("Rename Production") { $0.name = name }
    }

    func addSong() {
        var newID: UUID?
        edit("New Song") { newID = $0.addSong(after: selectedItemID) }
        if let newID { selectedItemID = newID }
    }

    func addSegment() {
        var newID: UUID?
        edit("New Segment") { newID = $0.addSegment(after: selectedItemID) }
        if let newID { selectedItemID = newID }
    }

    func renameItem(_ id: UUID, to title: String) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        edit("Rename") { $0.renameItem(id, to: t) }
    }

    func duplicateItem(_ id: UUID) {
        var newID: UUID?
        edit("Duplicate") { newID = $0.duplicateItem(id) }
        if let newID { selectedItemID = newID }
    }

    func deleteItem(_ id: UUID) {
        let items = show.items
        let index = items.firstIndex { $0.id == id }
        edit("Delete") { $0.deleteItems([id]) }
        let remaining = show.items
        if selectedItemID == id || show.item(selectedItemID) == nil {
            if let index, !remaining.isEmpty {
                selectedItemID = remaining[min(index, remaining.count - 1)].id
            } else {
                selectedItemID = remaining.first?.id
            }
        }
    }

    func moveItems(_ source: IndexSet, _ destination: Int) {
        edit("Reorder Running Order") { $0.moveItems(fromOffsets: source, toOffset: destination) }
    }

    func updateItem(_ actionName: String, _ change: @escaping (inout RundownItem) -> Void) {
        guard let id = selectedItemID else { return }
        edit(actionName) { $0.updateItem(id) { change(&$0) } }
    }

    func setTimeBase(_ base: TimeBase) {
        guard let id = selectedItemID else { return }
        edit("Change Timing") { $0.setTimeBase(base, forItem: id) }
    }

    // MARK: - Sections

    func addSection() {
        guard let id = selectedItemID else { return }
        var newID: UUID?
        edit("New Section") { newID = $0.addSection(toItem: id) }
        if let newID { scrollTarget = newID.uuidString }
    }

    func renameSection(_ sectionID: UUID, to name: String) {
        guard let id = selectedItemID else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        edit("Rename Section") { $0.renameSection(sectionID, inItem: id, to: n) }
    }

    /// Returns false when the text is not a valid position for this item.
    func setSectionPosition(_ sectionID: UUID, text: String) -> Bool {
        guard let id = selectedItemID, let item = selectedItem, let pos = item.parse(text), pos >= 0 else { return false }
        edit("Move Section") { $0.setSectionPosition(sectionID, inItem: id, to: pos) }
        return true
    }

    func deleteSection(_ sectionID: UUID) {
        guard let id = selectedItemID else { return }
        edit("Delete Section") { $0.deleteSection(sectionID, inItem: id) }
    }

    func moveSections(_ source: IndexSet, _ destination: Int) {
        guard let id = selectedItemID else { return }
        edit("Reorder Sections") { $0.moveSections(inItem: id, fromOffsets: source, toOffset: destination) }
    }

    /// Drag and drop in the section strip: put `moving` before `target` (or at the end when nil).
    func moveSection(_ moving: UUID, before target: UUID?) {
        guard let item = selectedItem else { return }
        let ids = item.sortedSections.map(\.id)
        guard let from = ids.firstIndex(of: moving) else { return }
        let to = target.flatMap { ids.firstIndex(of: $0) } ?? ids.count
        guard to != from, to != from + 1 else { return }
        moveSections(IndexSet(integer: from), to)
    }

    func nudgeSection(_ sectionID: UUID, by delta: Int) {
        guard let item = selectedItem else { return }
        let ids = item.sortedSections.map(\.id)
        guard let from = ids.firstIndex(of: sectionID) else { return }
        let target = from + delta
        guard target >= 0, target < ids.count else { return }
        moveSections(IndexSet(integer: from), delta > 0 ? target + 1 : target)
    }

    // MARK: - Shots

    /// New shot after the selected shot (or at the end), optionally with a camera; it becomes the selection.
    func addShot(cameraID: UUID? = nil, inSection sectionID: UUID? = nil) {
        guard let id = selectedItemID else { return }
        let after = sectionID == nil ? selectedRows.last?.id : nil
        var newID: UUID?
        edit("New Shot") { newID = $0.addShot(inItem: id, after: after, inSection: sectionID, cameraID: cameraID) }
        if let newID {
            selectedShotIDs = [newID]
            scrollTarget = newID.uuidString
        }
    }

    func deleteSelectedShots() {
        guard let id = selectedItemID, !selectedShotIDs.isEmpty else { return }
        let rows = show.shotRows(forItem: id)
        let firstIndex = rows.firstIndex { selectedShotIDs.contains($0.id) } ?? 0
        let ids = selectedShotIDs
        edit(ids.count == 1 ? "Delete Shot" : "Delete Shots") { $0.deleteCues(ids, inItem: id) }
        let remaining = show.shotRows(forItem: id)
        selectedShotIDs = remaining.isEmpty ? [] : [remaining[min(firstIndex, remaining.count - 1)].id]
    }

    func duplicateSelectedShots() {
        guard let id = selectedItemID, !selectedShotIDs.isEmpty else { return }
        let ids = selectedShotIDs
        var created: [UUID] = []
        edit("Duplicate Shot") { created = $0.duplicateCues(ids, inItem: id) }
        if !created.isEmpty { selectedShotIDs = Set(created) }
    }

    func nudgeSelectedShot(by delta: Int) {
        guard let id = selectedItemID, selectedShotIDs.count == 1, let shot = selectedShotIDs.first else { return }
        edit(delta < 0 ? "Move Shot Up" : "Move Shot Down") { $0.nudgeShot(shot, inItem: id, by: delta) }
        scrollTarget = shot.uuidString
    }

    func moveShots(section: UUID?, _ source: IndexSet, _ destination: Int) {
        guard let id = selectedItemID else { return }
        edit("Reorder Shots") { $0.moveShots(inItem: id, section: section, fromOffsets: source, toOffset: destination) }
    }

    func updateShot(_ shotID: UUID, _ actionName: String, _ change: @escaping (inout Cue) -> Void) {
        guard let id = selectedItemID else { return }
        edit(actionName) { $0.updateCue(shotID, inItem: id) { change(&$0) } }
    }

    func setShotPosition(_ shotID: UUID, text: String) -> Bool {
        guard let item = selectedItem, let pos = item.parse(text), pos >= 0 else { return false }
        updateShot(shotID, "Move Shot") { $0.at = pos }
        scrollTarget = shotID.uuidString
        return true
    }

    func setTransition(_ transition: TransitionKind, for ids: Set<UUID>? = nil) {
        guard let id = selectedItemID else { return }
        let targets = ids ?? selectedShotIDs
        guard !targets.isEmpty else { return }
        edit("Change Transition") { $0.setTransition(transition, forCues: targets, inItem: id) }
    }

    func toggleTransitionOfSelection() {
        let rows = selectedRows
        guard !rows.isEmpty else { return }
        let allCut = rows.allSatisfy { $0.cue.transition == .cut }
        setTransition(allCut ? .auto : .cut)
    }

    /// Camera key clicked: set it on the selected shots, or start a new shot with it.
    func useCamera(_ cameraID: UUID, newShot: Bool) {
        guard let id = selectedItemID else { return }
        if newShot || selectedShotIDs.isEmpty {
            addShot(cameraID: cameraID)
        } else {
            let ids = selectedShotIDs
            edit("Set Camera") { $0.setCamera(cameraID, forCues: ids, inItem: id) }
        }
    }

    /// Typing digits in the shot list sets the camera by number ("1", then "2" quickly = camera 12).
    func typeCameraDigit(_ digit: String) {
        let now = Date()
        if now.timeIntervalSince(lastDigitTime) > 0.8 { typedNumber = "" }
        lastDigitTime = now
        typedNumber += digit
        let s = show
        if let n = Int(typedNumber), let cam = s.camera(number: n) {
            useCamera(cam.id, newShot: false)
        } else if let n = Int(digit), let cam = s.camera(number: n) {
            typedNumber = digit
            useCamera(cam.id, newShot: false)
        }
    }

    // MARK: - Cameras

    func addCamera() {
        edit("New Camera") { $0.addCamera() }
    }

    func updateCamera(_ id: UUID, _ actionName: String, _ change: @escaping (inout Camera) -> Void) {
        edit(actionName) { $0.updateCamera(id) { change(&$0) } }
    }

    /// Returns false (and explains why) when the number cannot be used.
    func renumberCamera(_ id: UUID, text: String) -> Bool {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)) else { return false }
        var failure: Error?
        edit("Renumber Camera") { show in
            do { try show.renumberCamera(id, to: n) } catch { failure = error }
        }
        if let failure { errorMessage = failure.localizedDescription; return false }
        return true
    }

    func deleteCamera(_ id: UUID) {
        edit("Delete Camera") { $0.deleteCamera(id) }
    }

    // MARK: - Workspace persistence (per show, per Mac)

    private struct SavedState: Codable {
        var itemID: UUID?
        var shotIDs: [UUID]
        var inspector: Bool
    }

    private static func key(_ showID: UUID) -> String { "workspace.\(showID.uuidString)" }

    private func persistState() {
        guard !restoring, let showID = attachedShowID else { return }
        let state = SavedState(itemID: selectedItemID, shotIDs: Array(selectedShotIDs), inspector: showInspector)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.key(showID))
        }
    }

    private func restoreState(for show: Show) {
        restoring = true
        defer { restoring = false }
        if let data = UserDefaults.standard.data(forKey: Self.key(show.id)),
           let state = try? JSONDecoder().decode(SavedState.self, from: data) {
            selectedItemID = show.item(state.itemID) != nil ? state.itemID : show.items.first?.id
            showInspector = state.inspector
            let valid = Set(selectedItemID.map { show.shotRows(forItem: $0).map(\.id) } ?? [])
            selectedShotIDs = Set(state.shotIDs).intersection(valid)
            if let first = state.shotIDs.first(where: valid.contains) { scrollTarget = first.uuidString }
        } else {
            selectedItemID = show.items.first?.id
            selectedShotIDs = []
        }
    }

    /// Used by the screenshot run to pre-select a workspace before a show opens.
    static func seedState(showID: UUID, itemID: UUID?, shotIDs: [UUID]) {
        let state = SavedState(itemID: itemID, shotIDs: shotIDs, inspector: true)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key(showID))
        }
    }
}
