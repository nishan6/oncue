import SwiftUI
import AppKit
import Combine
import OnCueCore

/// Only one window at a time can be in Live Mode and control hardware.
enum LiveLock {
    static var holder: ObjectIdentifier?
}

/// How the centre panel shows a song or segment.
enum EditorMode: String, Codable, CaseIterable, Identifiable {
    case timeline, split, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .timeline: return "Timeline"
        case .split: return "Timeline and list"
        case .list: return "List"
        }
    }
    var symbol: String {
        switch self {
        case .timeline: return "rectangle.split.3x1"
        case .split: return "rectangle.split.1x2"
        case .list: return "list.bullet"
        }
    }
}

/// Timeline tracks: sections, the main output's shots, each separate output's shots, and the
/// lyrics, notes, FX, control, OSC and PTZ tracks. Each can be hidden (cues are kept) or locked.
enum TimelineLane: Codable, Identifiable, Hashable {
    case sections, media, shots, output(UUID), lyrics, notes, fx, control, osc, ptz

    var id: String {
        if case .output(let id) = self { return "output-\(id.uuidString)" }
        return "\(self)"
    }

    var label: String {
        switch self {
        case .sections: return "Sections"
        case .shots: return "Vision"
        case .output: return "Output"
        case .lyrics: return "Lyrics"
        case .notes: return "Notes"
        case .fx: return "FX"
        case .control: return "Control"
        case .osc: return "OSC"
        case .ptz: return "PTZ"
        case .media: return "Media"
        }
    }

    var trackKind: TrackKind? {
        switch self {
        case .sections, .media: return nil
        case .shots, .output: return .shots
        case .lyrics: return .lyrics
        case .notes: return .notes
        case .fx: return .fx
        case .control: return .control
        case .osc: return .osc
        case .ptz: return .ptz
        }
    }

    var isShots: Bool {
        switch self {
        case .shots, .output: return true
        default: return false
        }
    }

    static func forKind(_ kind: TrackKind) -> TimelineLane {
        switch kind {
        case .lyrics: return .lyrics
        case .fx: return .fx
        case .control: return .control
        case .osc: return .osc
        case .ptz: return .ptz
        case .shots: return .shots
        case .notes: return .notes
        }
    }
}

/// Per-window state of the scripting workspace: what is selected, which panels are open, and the
/// single entry point for edits. Every change to the show goes through `edit`, which applies an
/// OnCueCore editing operation to the document and registers it with Undo. Views never change
/// the show directly.
final class WorkspaceModel: ObservableObject {
    @Published var selectedItemID: UUID? {
        didSet {
            guard oldValue != selectedItemID else { return }
            if !restoring { selectedShotIDs = []; selectedCueID = nil; editingCueID = nil }
            persistState()
        }
    }
    @Published var selectedShotIDs: Set<UUID> = [] {
        didSet {
            if !selectedShotIDs.isEmpty, selectedCueID != nil { selectedCueID = nil }
            persistState()
        }
    }
    /// A selected lyric, note or FX cue (shots use `selectedShotIDs`).
    @Published var selectedCueID: UUID? {
        didSet { if selectedCueID != nil, !selectedShotIDs.isEmpty { selectedShotIDs = [] } }
    }
    /// Cue whose quick editor is open on the timeline.
    @Published var editingCueID: UUID?
    /// Section whose rename editor is open on the timeline.
    @Published var editingSectionID: UUID?
    @Published var showInspector = true { didSet { persistState() } }
    @Published var editorMode: EditorMode = .timeline { didSet { persistState() } }
    /// Timeline zoom, 1 = default scale.
    @Published var zoom: Double = 1 { didSet { persistState() } }
    @Published var hiddenLanes: Set<TimelineLane> = [] { didSet { persistState() } }
    /// The show engine while in Live Mode, nil in Edit Mode.
    @Published var engine: EngineController? { didSet { crew.follow(engine) } }
    /// The crew page for this window.
    let crew = CrewController()
    /// Song audio or PGM video under the timeline.
    let media = MediaPlayer()
    /// Operator monitor windows (Live Mode only).
    let monitors = MonitorWindows()
    var isLive: Bool { engine != nil }
    /// Used by the screenshot run: shows that open straight into Live Mode at a shot index.
    static var openLive: [UUID: Int] = [:]
    @Published var lockedLanes: Set<TimelineLane> = [] { didSet { persistState() } }
    @Published var cameraManagerOpen = false
    @Published var switcherSetupOpen = false
    @Published var exportOpen = false
    @Published var preShowCheckOpen = false
    @Published var plotOpen = false
    @Published var tourOpen = false
    @Published var draftSource: DraftSource?
    @Published var versionsOpen = false
    @Published var backupError: String?
    @Published var cameraDownOpen = false
    /// The log shown in the after-show report.
    @Published var reportLog: SwitchLog?
    @Published var renamingItemID: UUID?
    @Published var errorMessage: String?
    /// Shot list scrolls here when set (a shot or section id).
    @Published var scrollTarget: String?

    private var readProject: () -> Project = { Project.starter(name: "New Project", frameRate: .r25) }
    private var writeProject: (Project) -> Void = { _ in }
    private weak var undoManager: UndoManager?
    private var attachedShowID: UUID?
    private var attachedProjectID: UUID?
    private var fileURL: URL?
    private var restoring = false
    private var typedNumber = ""
    private var lastDigitTime = Date.distantPast
    private var saveKeyMonitor: Any?
    private var backupTimer: Timer?
    private var lastFolderBackup = Date.distantPast

    /// The playlist this window edits.
    @Published var activePlaylistID: UUID? {
        didSet {
            guard oldValue != activePlaylistID, let pid = attachedProjectID, let id = activePlaylistID else { return }
            UserDefaults.standard.set(id.uuidString, forKey: "workspace.playlist.\(pid.uuidString)")
        }
    }
    /// An older single-file show that has to be brought into a project before it can be edited.
    @Published var legacyShow: Show?
    /// Shown once when a newer backup was restored on opening.
    @Published var recoveredNotice: String?
    @Published var projectPropertiesOpen = false
    /// Drives the New Scene sheet.
    @Published var newSceneKind: ItemKind?
    /// Asks whether to renumber scenes after a move.
    @Published var renumberPromptOpen = false

    // MARK: - Document

    func attach(document: Binding<ProjectDocument>, fileURL: URL?, undoManager: UndoManager?) {
        readProject = { document.wrappedValue.project }
        writeProject = { document.wrappedValue.project = $0 }
        self.undoManager = undoManager
        self.fileURL = fileURL
        legacyShow = document.wrappedValue.legacy
        let project = readProject()
        if attachedProjectID != project.id {
            attachedProjectID = project.id
            let saved = UserDefaults.standard.string(forKey: "workspace.playlist.\(project.id.uuidString)").flatMap(UUID.init)
            activePlaylistID = project.playlist(saved)?.id ?? project.playlists.first?.id
            if legacyShow == nil { recoverIfNewerBackup() }
            startBackups()
            installSaveSnapshot()
        } else if project.playlist(activePlaylistID) == nil {
            activePlaylistID = project.playlists.first?.id
        }
        let show = self.show
        crew.onComment = { [weak self] itemID, cueID, author, text in
            self?.edit("Crew Comment") { $0.addComment(itemID: itemID, cueID: cueID, author: author, text: text) }
        }
        crew.showChanged(show)
        if attachedShowID != show.id {
            attachedShowID = show.id
            restoreState(for: show)
            if let index = Self.openLive[show.id] {
                enterLive()
                engine?.setMode(.cut)
                for _ in 0...index { engine?.next() }
            }
        }
    }

    deinit {
        if let m = saveKeyMonitor { NSEvent.removeMonitor(m) }
        backupTimer?.invalidate()
        if LiveLock.holder == ObjectIdentifier(self) { LiveLock.holder = nil }
    }

    var project: Project { readProject() }

    /// The rig plus the active playlist's scenes: what the editor and Live engine work on.
    var show: Show { project.show(playlist: activePlaylistID) }

    /// Applies an edit to the active playlist (and rig) as one undoable step.
    func edit(_ actionName: String, _ change: (inout Show) -> Void) {
        let target = activePlaylistID
        editProject(actionName) { p in
            guard let pid = target ?? p.playlists.first?.id else { return }
            var s = p.show(playlist: pid)
            let original = s
            change(&s)
            guard s != original else { return }
            p.apply(s, playlist: pid)
        }
    }

    /// Applies an edit to the whole project as one undoable step. The first edit of each day
    /// keeps a version of the project as it was.
    func editProject(_ actionName: String, _ change: (inout Project) -> Void) {
        let before = readProject()
        var base = before
        if needsDailyVersion(before) {
            let day = Date().formatted(date: .abbreviated, time: .omitted)
            base.saveVersion(name: "Start of \(day)", automatic: true, reason: "Daily")
        }
        var after = base
        change(&after)
        var compare = after
        compare.editedAt = base.editedAt
        guard compare != base else { return }
        after.editedAt = Date()
        commitProject(after, replacing: before, actionName: actionName)
    }

    private func needsDailyVersion(_ p: Project) -> Bool {
        !p.versions.contains { $0.reason == "Daily" && Calendar.current.isDateInToday($0.date) }
    }

    private func commitProject(_ new: Project, replacing old: Project, actionName: String) {
        writeProject(new)
        undoManager?.registerUndo(withTarget: self) { model in
            model.commitProject(old, replacing: new, actionName: actionName)
            model.validateSelection()
        }
        undoManager?.setActionName(actionName)
    }

    /// Keeps a version of the project as it is now (skipped when nothing changed since the last).
    /// Not an undo step: undoing an edit never removes a safety copy.
    func snapshot(name: String, reason: String) {
        var p = readProject()
        if p.saveVersion(name: name, automatic: true, reason: reason) { writeProject(p) }
    }

    /// ⌘S keeps a version as well as saving (the save itself is the document's).
    private func installSaveSnapshot() {
        guard saveKeyMonitor == nil else { return }
        saveKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "s",
                  NSDocumentController.shared.currentDocument?.fileURL?.isSameFile(as: self.fileURL) ?? (self.fileURL == nil) else { return event }
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.snapshot(name: "Saved \(stamp)", reason: "Saved")
            return event
        }
    }

    // MARK: - Backups and recovery

    /// Every 5 minutes while the project changes, a copy goes to the backup folder (kept forever).
    private func startBackups() {
        backupTimer?.invalidate()
        backupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.backupNow() }
    }

    func backupNow() {
        guard legacyShow == nil else { return }
        let p = readProject()
        guard p.editedAt > lastFolderBackup else { return }
        let folder = MachineProfileStore().profile.backupFolder
        let root = folder.isEmpty ? LibraryModel.backupRoot : URL(fileURLWithPath: folder, isDirectory: true)
        do {
            try ProjectBackupFolder.write(p, root: root)
            lastFolderBackup = p.editedAt
            backupError = nil
        } catch {
            backupError = "Backup to \(root.path) failed: \(error.localizedDescription)"
        }
    }

    /// When the backup folder holds a newer copy than the file (OnCue quit before it could save),
    /// that copy comes back automatically, and the window says so. Undo takes it back out.
    private func recoverIfNewerBackup() {
        let p = readProject()
        let folder = MachineProfileStore().profile.backupFolder
        let root = folder.isEmpty ? LibraryModel.backupRoot : URL(fileURLWithPath: folder, isDirectory: true)
        guard let newest = ProjectBackupFolder.newest(for: p, root: root),
              var recovered = try? ProjectBackupFolder.read(newest.url),
              recovered.id == p.id, recovered.editedAt > p.editedAt.addingTimeInterval(1) else { return }
        recovered.versions = p.versions
        commitProject(recovered, replacing: p, actionName: "Recover Backup")
        lastFolderBackup = recovered.editedAt
        recoveredNotice = "Recovered changes from \(newest.date.formatted(date: .abbreviated, time: .standard)): this backup was newer than the saved file. Edit › Undo takes them back out."
    }

    // MARK: - Playlists

    func selectPlaylist(_ id: UUID) {
        guard project.playlist(id) != nil else { return }
        activePlaylistID = id
    }

    func addPlaylist(named name: String) {
        let playlist = Playlist(name: name.isEmpty ? "Playlist" : name)
        editProject("New Playlist") { $0.playlists.append(playlist) }
        activePlaylistID = playlist.id
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        editProject("Rename Playlist") { p in
            if let i = p.playlists.firstIndex(where: { $0.id == id }) { p.playlists[i].name = t }
        }
    }

    func duplicatePlaylist(_ id: UUID) {
        guard let original = project.playlist(id) else { return }
        var copy = Playlist(name: "\(original.name) copy")
        copy.notes = original.notes
        copy.items = original.items.map { item in
            var c = item
            c.id = UUID()
            for t in c.tracks.indices {
                c.tracks[t].id = UUID()
                for k in c.tracks[t].cues.indices { c.tracks[t].cues[k].id = UUID() }
            }
            for s in c.sections.indices { c.sections[s].id = UUID() }
            return c
        }
        editProject("Duplicate Playlist") { p in
            let at = (p.playlists.firstIndex { $0.id == id } ?? p.playlists.count - 1) + 1
            p.playlists.insert(copy, at: at)
        }
        activePlaylistID = copy.id
    }

    func deletePlaylist(_ id: UUID) {
        let p = project
        guard p.playlists.count > 1, let index = p.playlists.firstIndex(where: { $0.id == id }) else {
            errorMessage = "A project keeps at least one playlist."
            return
        }
        snapshot(name: "Before deleting playlist “\(p.playlists[index].name)”", reason: "Before delete")
        editProject("Delete Playlist") { $0.playlists.removeAll { $0.id == id } }
        let remaining = project.playlists
        activePlaylistID = remaining[min(index, remaining.count - 1)].id
    }

    // MARK: - Scenes

    /// Adds a scene built from the project's scene defaults after the selection.
    func addScene(kind: ItemKind, title: String, number: String, artist: String, status: SceneStatus, startTimecode: String?) {
        let p = project
        var scene = p.newScene(title: title.isEmpty ? (kind == .song ? "New Song" : "New Segment") : title,
                               number: number, kind: kind, startTimecode: startTimecode)
        scene.artist = artist
        scene.status = status
        let after = selectedItemID
        edit(kind == .song ? "New Song" : "New Segment") { s in
            let at = s.itemIndex(after).map { $0 + 1 } ?? s.items.count
            s.items.insert(scene, at: at)
        }
        selectedItemID = scene.id
    }

    /// Where a new scene goes, and the number it would get.
    func proposedNumber() -> String {
        let s = show
        let at = s.itemIndex(selectedItemID).map { $0 + 1 } ?? s.items.count
        let d = project.properties.sceneDefaults
        return SceneNumbering.numberForInsert(at: at, in: s.items, mode: d.numberingMode, from: d.numberingFrom)
    }

    func renumberScenes() {
        let from = project.properties.sceneDefaults.numberingFrom
        snapshot(name: "Before renumbering", reason: "Before renumbering")
        edit("Renumber Scenes") { $0.items = SceneNumbering.renumbered($0.items, from: from) }
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
            if let cue = selectedCueID, s.cue(cue, inItem: id) == nil { selectedCueID = nil }
        } else {
            selectedCueID = nil
        }
    }

    func clearSelection() {
        if !selectedShotIDs.isEmpty { selectedShotIDs = [] }
        selectedCueID = nil
    }

    /// Click on a shot: select it, or add/remove it with Command or Shift.
    func selectShot(_ id: UUID, extending: Bool) {
        if extending {
            if selectedShotIDs.contains(id) { selectedShotIDs.remove(id) } else { selectedShotIDs.insert(id) }
        } else if selectedShotIDs != [id] {
            selectedShotIDs = [id]
        }
    }

    /// Left and right arrows on the timeline: previous or next shot.
    func selectAdjacentShot(_ delta: Int) {
        guard let id = selectedItemID else { return }
        let rows = show.shotRows(forItem: id)
        guard !rows.isEmpty else { return }
        let current = rows.lastIndex { selectedShotIDs.contains($0.id) }
        let target: Int
        if let current { target = min(max(current + delta, 0), rows.count - 1) } else { target = delta > 0 ? 0 : rows.count - 1 }
        selectedShotIDs = [rows[target].id]
        scrollTarget = rows[target].id.uuidString
    }

    func changeZoom(by factor: Double) {
        zoom = min(max(zoom * factor, 0.15), 6)
    }

    func toggleLaneHidden(_ lane: TimelineLane) {
        if hiddenLanes.contains(lane) { hiddenLanes.remove(lane) } else { hiddenLanes.insert(lane) }
    }

    func toggleLaneLocked(_ lane: TimelineLane) {
        if lockedLanes.contains(lane) { lockedLanes.remove(lane) } else { lockedLanes.insert(lane) }
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
        editProject("Rename Project") { $0.name = name }
    }

    /// New songs and segments ask for their number and start timecode first.
    func addSong() { newSceneKind = .song }

    func addSegment() { newSceneKind = .segment }

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
        if let title = show.item(id)?.title { snapshot(name: "Before deleting “\(title)”", reason: "Before delete") }
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
        let d = project.properties.sceneDefaults
        if d.numberingMode == .automatic, !SceneNumbering.followsOrder(show.items, from: d.numberingFrom) {
            renumberPromptOpen = true
        }
    }

    /// Changes one scene's number, artist, status or frame rate.
    func updateScene(_ id: UUID, _ actionName: String = "Edit Scene", _ change: @escaping (inout RundownItem) -> Void) {
        edit(actionName) { $0.updateItem(id) { change(&$0) } }
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

    /// New shot at a timeline position; its quick editor opens so the camera can be typed.
    func addShot(at position: Double, cameraID: UUID? = nil) {
        guard let id = selectedItemID else { return }
        var newID: UUID?
        edit("New Shot") { newID = $0.addShot(inItem: id, cameraID: cameraID, at: position) }
        if let newID { selectedShotIDs = [newID] }
    }

    /// New lyric line, note or FX cue at a timeline position, with its editor open.
    func addTrackCue(_ kind: TrackKind, at position: Double) {
        guard let id = selectedItemID else { return }
        var newID: UUID?
        let name: String
        switch kind {
        case .lyrics: name = "New Lyric"
        case .fx: name = "New FX Cue"
        case .control: name = "New Control Cue"
        case .osc: name = "New OSC Cue"
        case .ptz: name = "New PTZ Cue"
        default: name = "New Note"
        }
        edit(name) { newID = $0.addTrackCue(kind, inItem: id, at: position) }
        if let newID {
            selectedCueID = newID
            editingCueID = newID
        }
    }

    /// New shot on a separate output's own track, selected with its editor open.
    func addOutputShot(_ outputID: UUID, at position: Double) {
        guard let id = selectedItemID else { return }
        var newID: UUID?
        edit("New Shot") { newID = $0.addShot(inItem: id, outputID: outputID, cameraID: nil, at: position) }
        if let newID {
            selectedCueID = newID
            editingCueID = newID
        }
    }

    /// Drag on the timeline: a shot or cue to a new position.
    func moveCue(_ cueID: UUID, to position: Double) {
        guard let id = selectedItemID, let current = show.cue(cueID, inItem: id), current.at != position else { return }
        let kind = show.trackKind(ofCue: cueID, inItem: id)
        edit(kind == .shots ? "Move Shot" : "Move Cue") { $0.moveCue(cueID, inItem: id, to: position) }
    }

    /// Edits a lyric, note or FX cue.
    func updateCue(_ cueID: UUID, _ actionName: String, _ change: @escaping (inout Cue) -> Void) {
        guard let id = selectedItemID else { return }
        edit(actionName) { $0.updateCue(cueID, inItem: id) { change(&$0) } }
    }

    func deleteSelectedCue() {
        guard let id = selectedItemID, let cue = selectedCueID else { return }
        edit("Delete Cue") { $0.deleteCues([cue], inItem: id) }
        selectedCueID = nil
    }

    /// Delete on the timeline: the selected shots, or the selected lyric, note or FX cue.
    func deleteSelection() {
        if selectedCueID != nil { deleteSelectedCue() } else { deleteSelectedShots() }
    }

    func setSectionPosition(_ sectionID: UUID, position: Double) {
        guard let id = selectedItemID else { return }
        edit("Move Section") { $0.setSectionPosition(sectionID, inItem: id, to: position) }
    }

    func addSection(at position: Double) {
        guard let id = selectedItemID else { return }
        var newID: UUID?
        edit("New Section") { newID = $0.addSection(toItem: id, at: position) }
        if let newID { editingSectionID = newID }
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

    // MARK: - Switcher

    func ensureMainSwitcher() {
        edit("Add Switcher") { $0.ensureMainSwitcher() }
    }

    func updateMainSwitcher(_ actionName: String, _ change: @escaping (inout SwitcherConfig) -> Void) {
        edit(actionName) { show in
            let id = show.ensureMainSwitcher()
            show.updateSwitcher(id) { change(&$0) }
        }
    }

    // MARK: - Live Mode

    /// Enters Live Mode on the selected song or segment: the engine stands by in Display mode
    /// (nothing is sent to the switcher until the director picks Auto preview or Auto cut), and
    /// OnCue connects to the show's main switcher.
    func enterLive() {
        guard let id = selectedItemID ?? show.items.first?.id else { return }
        editingCueID = nil
        // Only one window at a time can be live or control hardware.
        if let holder = LiveLock.holder, holder != ObjectIdentifier(self) {
            errorMessage = "Another project window is in Live Mode. Leave Live Mode there first: only one window can control the hardware at a time."
            return
        }
        LiveLock.holder = ObjectIdentifier(self)
        // A version of the script as it went live, kept in the project (skipped when unchanged).
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let night = show.settings.nightLabel
        snapshot(name: "Before Live" + (night.isEmpty ? ", \(stamp)" : ", \(night)"), reason: "Before Live")
        let profile = MachineProfileStore().profile
        let controller = EngineController(show: show, itemID: id, profile: profile)
        controller.connectSwitcher()
        engine = controller
        startBackupLink(controller, role: BackupRole(rawValue: profile.backupRole) ?? .off, primaryHost: profile.primaryHost)
    }

    /// Leaves Live Mode, selecting the song and the shot that was on air.
    func exitLive() {
        guard let controller = engine else { return }
        let cursor = controller.status.cursor
        let onAir = show.liveNow(cursor)
        monitors.close()
        stopBackupLink()
        controller.shutdown()
        let log = controller.log
        engine = nil
        if LiveLock.holder == ObjectIdentifier(self) { LiveLock.holder = nil }
        // After a run with cuts or calls, show the report.
        if !log.entries.isEmpty { reportLog = log }
        if selectedItemID != cursor.itemID { selectedItemID = cursor.itemID }
        if let onAir {
            selectedShotIDs = [onAir.id]
            scrollTarget = onAir.id.uuidString
        }
    }

    // MARK: - Backup Mac link

    private var backupServer: BackupLinkServer?
    private var backupClient: BackupLinkClient?
    private var backupWatch: AnyCancellable?
    @Published var backupMacs = 0
    @Published var backupLinkError: String?

    private func startBackupLink(_ controller: EngineController, role: BackupRole, primaryHost: String) {
        stopBackupLink()
        switch role {
        case .off:
            break
        case .primary:
            let server = BackupLinkServer()
            server.onClientsChanged = { [weak self] n in self?.backupMacs = n }
            server.start { [weak self] result in
                if case .failure(let e) = result { self?.backupLinkError = "The backup link couldn't start: \(e.localizedDescription)" }
            }
            if let data = try? ShowCoding.encode(show) { server.send(show: data) }
            backupWatch = controller.$status
                .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
                .sink { [weak server, weak controller] _ in
                    guard let server, let controller else { return }
                    server.send(state: controller.backupState)
                }
            backupServer = server
        case .backup:
            controller.startFollowing()
            let client = BackupLinkClient()
            client.onConnectedChanged = { [weak controller] up in controller?.setMainLinked(up) }
            client.onMessage = { [weak self, weak controller] message in
                guard let self, let controller else { return }
                switch message {
                case .state(let state):
                    controller.follow(state)
                case .show(let data):
                    guard let remote = try? ShowCoding.decode(data), remote.id == self.show.id else { return }
                    let incoming = remote
                    if incoming != self.show { self.edit("Update from Main Mac") { $0 = incoming } }
                case .hello:
                    break
                }
            }
            client.connect(to: primaryHost)
            backupClient = client
        }
    }

    private func stopBackupLink() {
        backupWatch = nil
        backupServer?.stop()
        backupServer = nil
        backupClient?.disconnect()
        backupClient = nil
        backupMacs = 0
    }

    /// Main Mac: the script changed during the show; the backup gets it too.
    func sendShowToBackup(_ show: Show) {
        guard let server = backupServer, let data = try? ShowCoding.encode(show) else { return }
        server.send(show: data)
    }

    /// Backup Mac: take the show (the main Mac failed).
    func takeOverFromMain() {
        engine?.takeOver()
        backupClient?.disconnect()
        backupClient = nil
    }

    func toggleLive() {
        if engine == nil { enterLive() } else { exitLive() }
    }

    // MARK: - Workspace persistence (per show, per Mac)

    private struct SavedState: Codable {
        var itemID: UUID?
        var shotIDs: [UUID]
        var inspector: Bool
        var editor: EditorMode?
        var zoom: Double?
        var hiddenLanes: [TimelineLane]?
        var lockedLanes: [TimelineLane]?
    }

    private static func key(_ showID: UUID) -> String { "workspace.\(showID.uuidString)" }

    private func persistState() {
        guard !restoring, let showID = attachedShowID else { return }
        let state = SavedState(itemID: selectedItemID, shotIDs: Array(selectedShotIDs), inspector: showInspector,
                               editor: editorMode, zoom: zoom,
                               hiddenLanes: Array(hiddenLanes), lockedLanes: Array(lockedLanes))
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
            editorMode = state.editor ?? .timeline
            zoom = state.zoom ?? 1
            hiddenLanes = Set(state.hiddenLanes ?? [])
            lockedLanes = Set(state.lockedLanes ?? [])
            let valid = Set(selectedItemID.map { show.shotRows(forItem: $0).map(\.id) } ?? [])
            selectedShotIDs = Set(state.shotIDs).intersection(valid)
            if let first = state.shotIDs.first(where: valid.contains) { scrollTarget = first.uuidString }
        } else {
            selectedItemID = show.items.first?.id
            selectedShotIDs = []
        }
    }

    /// Used by the screenshot run to pre-select a workspace before a show opens.
    static func seedState(showID: UUID, itemID: UUID?, shotIDs: [UUID], editor: EditorMode = .timeline) {
        let state = SavedState(itemID: itemID, shotIDs: shotIDs, inspector: true, editor: editor,
                               zoom: nil, hiddenLanes: nil, lockedLanes: nil)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key(showID))
        }
    }
}
