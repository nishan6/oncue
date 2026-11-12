import SwiftUI
import AppKit
import OnCueCore

/// Centre panel for one song or segment: header, then the timeline, the shot list or both, and the
/// camera bank.
struct ItemEditorView: View {
    static let splitShotHeight: CGFloat = 92
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let groups = show.shotGroups(forItem: item.id)
        let rows = groups.flatMap(\.rows)
        VStack(spacing: 0) {
            ItemHeaderView(item: item, rows: rows, model: model)
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            switch model.editorMode {
            case .timeline:
                GeometryReader { geo in
                    let chrome = TimelineLayout.chromeHeight(for: item, hidden: model.hiddenLanes)
                    TimelineEditorView(show: show, item: item, model: model,
                                       shotHeight: min(max(geo.size.height - chrome - 8, 84), 320))
                }
            case .split:
                TimelineEditorView(show: show, item: item, model: model, shotHeight: Self.splitShotHeight)
                    .frame(height: TimelineLayout.chromeHeight(for: item, hidden: model.hiddenLanes) + Self.splitShotHeight + 6)
                Rectangle().fill(Gallery.hairline).frame(height: 1)
                ShotListView(show: show, item: item, groups: groups, rows: rows, model: model)
            case .list:
                SectionStripView(item: item, rows: rows, model: model)
                Rectangle().fill(Gallery.hairline).frame(height: 1)
                ShotListView(show: show, item: item, groups: groups, rows: rows, model: model)
            }
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            CameraBankView(show: show, model: model)
        }
        .background(Gallery.canvas)
    }
}

// MARK: - Header

struct ItemHeaderView: View {
    let item: RundownItem
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Pill(text: item.kind == .song ? "Song" : "Segment",
                     color: item.kind == .song ? Gallery.ink : Gallery.amber)
                CommitField(placeholder: "Title", value: item.title, font: .title(22)) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.renameItem(item.id, to: t)
                    return true
                }
                Spacer(minLength: 12)
                Picker("View", selection: $model.editorMode) {
                    ForEach(EditorMode.allCases) { mode in
                        Image(systemName: mode.symbol).help(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Timeline, timeline and list, or list (⌘1, ⌘2, ⌘3)")
            }
            HStack(spacing: 8) {
                ReadoutField(label: "Timing") {
                    Picker("Timing", selection: Binding(get: { item.timeBase }, set: { model.setTimeBase($0) })) {
                        ForEach(TimeBase.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help("How shot positions are measured. Changing it converts every position.")
                }
                if item.timeBase == .bars {
                    ReadoutField(label: "Tempo") {
                        HStack(spacing: 3) {
                            CommitField(placeholder: "120", value: String(format: "%g", item.bpm), font: .readout(13, weight: .semibold), width: 46) { text in
                                guard let v = Double(text), (20...400).contains(v) else { return false }
                                model.updateItem("Change Tempo") { $0.bpm = v }
                                return true
                            }
                            Text("BPM").font(.umd(10)).foregroundStyle(Gallery.dim)
                        }
                    }
                    ReadoutField(label: "Beats per bar") {
                        CommitField(placeholder: "4", value: "\(item.beatsPerBar)", font: .readout(13, weight: .semibold), width: 30) { text in
                            guard let v = Int(text), (1...16).contains(v) else { return false }
                            model.updateItem("Change Beats per Bar") { $0.beatsPerBar = v }
                            return true
                        }
                    }
                }
                ReadoutField(label: "Planned length") {
                    CommitField(placeholder: "m:ss", value: item.plannedDuration > 0 ? clock(item.plannedDuration) : "",
                                font: .readout(13, weight: .semibold), width: 56) { text in
                        if text.trimmingCharacters(in: .whitespaces).isEmpty {
                            model.updateItem("Clear Planned Length") { $0.plannedDuration = 0 }
                            return true
                        }
                        guard let v = TimeFormat.parseSeconds(text), v >= 0 else { return false }
                        model.updateItem("Change Planned Length") { $0.plannedDuration = v }
                        return true
                    }
                }
                ReadoutField(label: "Hard out") {
                    CommitField(placeholder: "HH:MM", value: item.hardOut, font: .readout(13, weight: .semibold), width: 52) { text in
                        let t = text.trimmingCharacters(in: .whitespaces)
                        guard t.isEmpty || TimeFormat.todayAt(t) != nil else { return false }
                        model.updateItem("Change Hard Out") { $0.hardOut = t }
                        return true
                    }
                }
                Spacer(minLength: 8)
                ReadoutField(label: "Shots") {
                    Text("\(rows.count)").font(.readout(13, weight: .semibold)).foregroundStyle(Gallery.ink)
                }
                if let length = scriptLength {
                    ReadoutField(label: "Script runs") {
                        Text(clock(length)).font(.readout(13, weight: .semibold)).foregroundStyle(Gallery.ink)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Gallery.panel)
    }

    /// Time from the first to the last shot, when the time base allows it.
    private var scriptLength: Double? {
        guard item.timeBase != .order, let last = rows.last?.cue.at else { return nil }
        return item.seconds(for: last)
    }

    private func clock(_ s: Double) -> String {
        let v = Int(s.rounded())
        return String(format: "%d:%02d", v / 60, v % 60)
    }
}

// MARK: - Section strip

/// The song structure as proportional blocks. Click to jump, drag a block onto another to move
/// that section (with its shots) before it, drop on the end cap to move it last.
struct SectionStripView: View {
    let item: RundownItem
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let sections = item.sortedSections
        HStack(spacing: 8) {
            if sections.isEmpty {
                Text("No sections yet. Sections group shots by verse, chorus, bridge.")
                    .font(.system(size: 12))
                    .foregroundStyle(Gallery.dim)
                Spacer()
            } else {
                GeometryReader { geo in
                    let lengths = spanLengths(for: sections)
                    let total = max(lengths.reduce(0, +), 0.0001)
                    let available = max(geo.size.width - CGFloat(sections.count - 1) * 3 - 34, 60)
                    HStack(spacing: 3) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { k, section in
                            let width = max(available * CGFloat(lengths[k] / total), 44)
                            sectionBlock(section, shots: rows.filter { $0.sectionID == section.id }.count)
                                .frame(width: width)
                        }
                        endCap
                    }
                }
                .frame(height: 38)
            }
            IconButton(symbol: "plus", help: "New section (⌥⌘E)") { model.addSection() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Gallery.panel)
    }

    private func sectionBlock(_ section: SongSection, shots: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(section.name)
                .font(.umd(12))
                .foregroundStyle(Gallery.ink)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(item.format(section.at)).font(.readout(10))
                Text(shots == 1 ? "1 shot" : "\(shots) shots").font(.umd(10))
            }
            .foregroundStyle(Gallery.dim)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .leading) {
            Rectangle().fill(Gallery.steel.opacity(0.7)).frame(width: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.scrollTarget = section.id.uuidString }
        .draggable(section.id.uuidString)
        .dropDestination(for: String.self) { dropped, _ in
            guard let raw = dropped.first, let moving = UUID(uuidString: raw), moving != section.id else { return false }
            model.moveSection(moving, before: section.id)
            return true
        }
        .help("\(section.name): click to jump, drag onto another section to move it before that one")
    }

    private var endCap: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(Gallery.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: 28)
            .overlay(Image(systemName: "arrow.down.to.line").rotationEffect(.degrees(-90)).font(.system(size: 10)).foregroundStyle(Gallery.faint))
            .dropDestination(for: String.self) { dropped, _ in
                guard let raw = dropped.first, let moving = UUID(uuidString: raw) else { return false }
                model.moveSection(moving, before: nil)
                return true
            }
            .help("Drop a section here to move it to the end")
    }

    /// Relative length of each section (the last runs to its last shot, or a default length).
    private func spanLengths(for sections: [SongSection]) -> [Double] {
        sections.enumerated().map { k, s in
            if k + 1 < sections.count { return max(sections[k + 1].at - s.at, 0.0001) }
            let lastShot = rows.map(\.cue.at).filter { $0 >= s.at }.max()
            let end = max(lastShot.map { $0 + Show.step(for: item) } ?? s.at, s.at + Show.defaultSectionLength(for: item))
            return max(end - s.at, 0.0001)
        }
    }
}

// MARK: - Shot list

struct ShotListView: View {
    let show: Show
    let item: RundownItem
    let groups: [ShotGroup]
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel
    @FocusState private var listFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $model.selectedShotIDs) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.rows) { row in
                            ShotRowView(row: row, item: item, camera: show.camera(row.cue.cameraID),
                                        tally: model.tally(forShot: row.id, in: rows), model: model)
                                .tag(row.id)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 12))
                        }
                        .onMove { model.moveShots(section: group.section?.id, $0, $1) }
                    } header: {
                        SectionHeaderView(item: item, section: group.section, shotCount: group.rows.count, model: model)
                            .id(group.section?.id.uuidString ?? "before-first-section")
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Gallery.canvas)
            .environment(\.defaultMinListRowHeight, 30)
            .overlay {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Text("No shots yet")
                            .font(.title(18))
                            .foregroundStyle(Gallery.ink)
                        Text("Click a camera below, or select this list and press Return.")
                            .foregroundStyle(Gallery.dim)
                    }
                    .allowsHitTesting(false)
                }
            }
            .focused($listFocused)
            .onAppear { revealSelection(proxy) }
            .onChange(of: item.id) { _, _ in revealSelection(proxy) }
            .onDeleteCommand { model.deleteSelectedShots() }
            .onKeyPress(.return) {
                model.addShot()
                return .handled
            }
            .onKeyPress(characters: .decimalDigits) { press in
                model.typeCameraDigit(press.characters)
                return .handled
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                if !ids.isEmpty {
                    Menu("Camera") {
                        ForEach(show.sortedCameras) { cam in
                            Button("\(cam.number)  \(cam.displayName)") {
                                model.selectedShotIDs = ids
                                model.useCamera(cam.id, newShot: false)
                            }
                        }
                    }
                    Button("Cut") { model.setTransition(.cut, for: ids) }
                    Button("Mix") { model.setTransition(.auto, for: ids) }
                    Divider()
                    Button("Duplicate") { model.selectedShotIDs = ids; model.duplicateSelectedShots() }
                    Button("Delete", role: .destructive) { model.selectedShotIDs = ids; model.deleteSelectedShots() }
                } else {
                    Button("New Shot") { model.addShot() }
                }
            }
            .onChange(of: model.scrollTarget) { _, target in
                guard let target else { return }
                scroll(proxy, to: target)
                DispatchQueue.main.async { model.scrollTarget = nil }
            }
        }
    }

    /// Typing goes to the shot list, and the restored or current selection is brought into view.
    private func revealSelection(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async { listFocused = true }
        // The list lays out its rows over the first few runloop passes, so scroll after it has.
        for delay in [0.15, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let first = rows.first(where: { model.selectedShotIDs.contains($0.id) }) {
                    proxy.scrollTo(first.id, anchor: .center)
                }
            }
        }
    }

    /// Targets are shot or section ids (as text). A List scrolls by its rows' own identity, so a
    /// section scrolls to its first shot (or its header when it has none).
    private func scroll(_ proxy: ScrollViewProxy, to target: String) {
        guard let uuid = UUID(uuidString: target) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            if rows.contains(where: { $0.id == uuid }) {
                proxy.scrollTo(uuid, anchor: .center)
            } else if let group = groups.first(where: { $0.section?.id == uuid }) {
                if let firstRow = group.rows.first {
                    proxy.scrollTo(firstRow.id, anchor: .top)
                } else {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }
}

struct SectionHeaderView: View {
    let item: RundownItem
    let section: SongSection?
    let shotCount: Int
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(spacing: 10) {
            if let section {
                CommitField(placeholder: "Section", value: section.name, font: .umd(14)) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.renameSection(section.id, to: t)
                    return true
                }
                .frame(maxWidth: 220, alignment: .leading)
                CommitField(placeholder: "Start", value: item.format(section.at), font: .readout(11), width: 70) { text in
                    model.setSectionPosition(section.id, text: text)
                }
                .help("Section start (\(positionHint))")
            } else {
                Text(item.sections.isEmpty ? "Shots" : "Before the first section")
                    .font(.umd(13))
                    .foregroundStyle(Gallery.dim)
            }
            Text("\(shotCount) \(shotCount == 1 ? "shot" : "shots")")
                .font(.umd(11))
                .foregroundStyle(Gallery.faint)
            Spacer()
            if let section {
                IconButton(symbol: "plus", help: "New shot at the end of \(section.name)") {
                    model.addShot(inSection: section.id)
                }
                Menu {
                    Button("Move Earlier") { model.nudgeSection(section.id, by: -1) }
                    Button("Move Later") { model.nudgeSection(section.id, by: 1) }
                    Divider()
                    Button("Delete Section", role: .destructive) { model.deleteSection(section.id) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Gallery.ink)
                        .frame(width: 24, height: 22)
                        .background(Gallery.key, in: RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Move or delete this section. Its shots move with it; deleting keeps the shots.")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: 4))
    }

    private var positionHint: String {
        switch item.timeBase {
        case .bars: return "bar.beat, e.g. 17.1"
        case .seconds: return "m:ss, e.g. 1:30"
        case .order: return "step number"
        }
    }
}

struct ShotRowView: View {
    let row: ShotRow
    let item: RundownItem
    let camera: Camera?
    let tally: TallyState
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(tally == .off ? Color.clear : tally.color)
                .frame(width: 3)
                .clipShape(Capsule())

            Text(String(format: "%02d", row.number))
                .font(.readout(12, weight: .semibold))
                .foregroundStyle(Gallery.dim)
                .frame(width: 24, alignment: .trailing)

            Text(item.format(row.cue.at))
                .font(.readout(12))
                .foregroundStyle(Gallery.ink)
                .frame(width: 58, alignment: .leading)

            CameraTile(camera: camera, missing: row.cue.cameraID != nil && camera == nil,
                       tally: tally, size: 38, compact: true)

            VStack(alignment: .leading, spacing: 0) {
                Text(camera?.displayName ?? (row.cue.cameraID == nil ? "No camera" : "Deleted camera"))
                    .font(.umd(12))
                    .foregroundStyle(camera == nil ? Gallery.amber : Gallery.ink)
                Text(camera?.operatorName ?? "")
                    .font(.umd(10))
                    .foregroundStyle(Gallery.dim)
            }
            .frame(width: 92, alignment: .leading)
            .lineLimit(1)

            VStack(alignment: .leading, spacing: 1) {
                CommitField(placeholder: "Describe the shot", value: row.cue.text, font: .system(size: 13, weight: .medium)) { text in
                    model.updateShot(row.id, "Edit Shot") { $0.text = text }
                    return true
                }
                CommitField(placeholder: "Operator note", value: row.cue.note, font: .system(size: 11)) { text in
                    model.updateShot(row.id, "Edit Operator Note") { $0.note = text }
                    return true
                }
                .foregroundStyle(Gallery.dim)
            }

            Spacer(minLength: 6)

            if !row.issues.isEmpty {
                Circle()
                    .fill(Gallery.amber.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .help(row.issues.map(\.message).joined(separator: "\n"))
            }

            Text(row.lengthSeconds.map { String(format: "%.1f s", $0) } ?? "")
                .font(.readout(11))
                .foregroundStyle(Gallery.dim)
                .frame(width: 52, alignment: .trailing)

            Button {
                model.setTransition(row.cue.transition == .cut ? .auto : .cut, for: [row.id])
            } label: {
                Pill(text: row.cue.transition == .cut ? "CUT" : "MIX",
                     color: row.cue.transition == .cut ? Gallery.dim : Gallery.steel,
                     filled: row.cue.transition == .auto)
                    .frame(width: 40)
            }
            .buttonStyle(.plain)
            .help("Click to switch between cut and mix (⌥⌘T)")
        }
        .padding(.vertical, 3)
        .padding(.trailing, 4)
        .background((camera?.swiftUIColor ?? Color.clear).opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Camera bank

/// The cameras as switcher keys. Red = camera of the selected shot, green = camera of the next shot.
struct CameraBankView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Cameras").font(.umd(12)).foregroundStyle(Gallery.dim)
                Text(model.selectedShotIDs.isEmpty ? "Click a camera to add a shot with it" : "Click to set the camera on the selected shot. Option-click adds a new shot.")
                    .font(.system(size: 11))
                    .foregroundStyle(Gallery.faint)
                Spacer()
                IconButton(symbol: "plus", help: "New camera") { model.addCamera() }
                IconButton(symbol: "slider.horizontal.3", help: "Manage cameras (⌥⌘C)") { model.cameraManagerOpen = true }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(show.sortedCameras) { cam in
                        Button {
                            model.useCamera(cam.id, newShot: NSEvent.modifierFlags.contains(.option))
                        } label: {
                            VStack(spacing: 3) {
                                CameraTile(camera: cam, tally: model.tally(forCamera: cam.id), size: 58)
                                Text(cam.operatorName.isEmpty ? " " : cam.operatorName)
                                    .font(.umd(10))
                                    .foregroundStyle(Gallery.dim)
                                    .lineLimit(1)
                                    .frame(width: 58)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if show.cameras.isEmpty {
                        Button("Add the first camera") { model.addCamera() }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .frame(height: 86)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Gallery.panel)
    }
}
