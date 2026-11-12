import SwiftUI
import AppKit
import OnCueCore

/// Centre panel for one song or segment: header, then the timeline, the shot list or both, and the
/// camera palette.
struct ItemEditorView: View {
    static let splitShotHeight: CGFloat = 96
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let groups = show.shotGroups(forItem: item.id)
        let rows = groups.flatMap(\.rows)
        VStack(spacing: 0) {
            ItemHeaderView(item: item, rows: rows, runLength: show.runLength(forItem: item.id), model: model)
            VStack(spacing: 0) {
            switch model.editorMode {
            case .timeline:
                GeometryReader { geo in
                    let chrome = TimelineLayout.chromeHeight(for: item, hidden: model.hiddenLanes)
                    TimelineEditorView(show: show, item: item, model: model,
                                       shotHeight: min(max(geo.size.height - chrome - 8, 84), 300))
                }
            case .split:
                TimelineEditorView(show: show, item: item, model: model, shotHeight: Self.splitShotHeight)
                    .frame(height: TimelineLayout.chromeHeight(for: item, hidden: model.hiddenLanes) + Self.splitShotHeight + 6)
                Rectangle().fill(Gallery.hairline).frame(height: 1)
                ShotListView(show: show, item: item, groups: groups, rows: rows, model: model)
            case .list:
                SectionStripView(item: item, rows: rows, model: model)
                ShotListView(show: show, item: item, groups: groups, rows: rows, model: model)
            }
            }
            .transition(.opacity)
            .id(model.editorMode)
            CameraPaletteView(show: show, model: model)
        }
        .background(Gallery.base)
        .animation(.easeOut(duration: 0.16), value: model.editorMode)
    }
}

// MARK: - Header

struct ItemHeaderView: View {
    let item: RundownItem
    let rows: [ShotRow]
    let runLength: Double?
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(alignment: .center, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    KindTag(kind: item.kind)
                    CommitField(placeholder: "Title", value: item.title, font: .ocTitle) { text in
                        let t = text.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return false }
                        model.renameItem(item.id, to: t)
                        return true
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                }
                HStack(alignment: .top, spacing: Space.m) {
                    MetaItem(label: "Timing") { TimingMenu(item: item, model: model) }
                    if item.timeBase == .bars {
                        MetaItem(label: "Tempo") {
                            HStack(spacing: 0) {
                                CommitField(placeholder: "120", value: String(format: "%g", item.bpm), font: .readout(13), width: 40) { text in
                                    guard let v = Double(text), (20...400).contains(v) else { return false }
                                    model.updateItem("Change Tempo") { $0.bpm = v }
                                    return true
                                }
                                Text("BPM").font(.ocMeta).foregroundStyle(Gallery.faint)
                            }
                        }
                        MetaItem(label: "Meter") {
                            HStack(spacing: 0) {
                                CommitField(placeholder: "4", value: "\(item.beatsPerBar)", font: .readout(13), width: 16, alignment: .trailing) { text in
                                    guard let v = Int(text), (1...16).contains(v) else { return false }
                                    model.updateItem("Change Beats per Bar") { $0.beatsPerBar = v }
                                    return true
                                }
                                Text("/4").font(.readout(13)).foregroundStyle(Gallery.dim).padding(.leading, -4)
                            }
                        }
                    }
                    MetaItem(label: "Planned length") {
                        CommitField(placeholder: "m:ss", value: item.plannedDuration > 0 ? clockText(item.plannedDuration) : "",
                                    font: .readout(13), width: 52) { text in
                            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                                model.updateItem("Clear Planned Length") { $0.plannedDuration = 0 }
                                return true
                            }
                            guard let v = TimeFormat.parseSeconds(text), v >= 0 else { return false }
                            model.updateItem("Change Planned Length") { $0.plannedDuration = v }
                            return true
                        }
                    }
                    MetaItem(label: "Hard out") {
                        CommitField(placeholder: "HH:MM", value: item.hardOut, font: .readout(13), width: 52) { text in
                            let t = text.trimmingCharacters(in: .whitespaces)
                            guard t.isEmpty || TimeFormat.todayAt(t) != nil else { return false }
                            model.updateItem("Change Hard Out") { $0.hardOut = t }
                            return true
                        }
                    }
                }
            }
            Spacer(minLength: Space.m)
            HStack(spacing: Space.l) {
                Stat(value: "\(rows.count)", label: rows.count == 1 ? "shot" : "shots")
                if let runLength { Stat(value: clockText(runLength), label: "runs") }
            }
            Picker("View", selection: $model.editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Image(systemName: mode.symbol).help(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Timeline, timeline and list, or list (⌘1, ⌘2, ⌘3)")
            Button {
                model.enterLive()
            } label: {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(QuietButtonStyle(prominent: true))
            .disabled(rows.isEmpty)
            .help("Run this script in Live Mode (⌘L)")
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(Gallery.panel)
    }
}

/// Song or segment tag: a colour dot and the word.
struct KindTag: View {
    let kind: ItemKind

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(kind == .song ? Gallery.selection : Gallery.amber).frame(width: 6, height: 6)
            Text(kind.label).font(.ocLabel).foregroundStyle(Gallery.dim)
        }
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(Gallery.raised, in: Capsule())
    }
}

/// Big number with a small label (header stats).
struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.readout(17, weight: .semibold)).foregroundStyle(Gallery.ink)
            Text(label).font(.ocMeta).foregroundStyle(Gallery.faint)
        }
    }
}

/// Timing (time base) as a borderless field that opens its three choices.
struct TimingMenu: View {
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 4) {
                Text(item.timeBase.label).font(.ocBodyStrong).foregroundStyle(Gallery.ink)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(Gallery.faint)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .interactive()
        }
        .buttonStyle(.plain)
        .help("How shot positions are measured. Changing it converts every position.")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(TimeBase.allCases) { base in
                    Button {
                        open = false
                        model.setTimeBase(base)
                    } label: {
                        HStack {
                            Text(base.label).font(.ocBodyStrong).foregroundStyle(Gallery.ink)
                            Spacer()
                            if base == item.timeBase {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Gallery.selection)
                            }
                        }
                        .padding(.horizontal, Space.s)
                        .frame(width: 180, height: 28)
                        .contentShape(Rectangle())
                        .interactive()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Space.s)
        }
    }
}

// MARK: - Section strip (list view)

/// The song structure as proportional blocks. Click to jump, drag a block onto another to move
/// that section (with its shots) before it, drop on the end cap to move it last.
struct SectionStripView: View {
    let item: RundownItem
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let sections = item.sortedSections
        HStack(spacing: Space.s) {
            if sections.isEmpty {
                Text("No sections yet. Sections group shots by verse, chorus, bridge.")
                    .font(.ocMeta)
                    .foregroundStyle(Gallery.faint)
                Spacer()
            } else {
                GeometryReader { geo in
                    let lengths = spanLengths(for: sections)
                    let total = max(lengths.reduce(0, +), 0.0001)
                    let available = max(geo.size.width - CGFloat(sections.count - 1) * 2 - 30, 60)
                    HStack(spacing: 2) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { k, section in
                            let width = max(available * CGFloat(lengths[k] / total), 44)
                            sectionBlock(section, shots: rows.filter { $0.sectionID == section.id }.count)
                                .frame(width: width)
                        }
                        endCap
                    }
                }
                .frame(height: 34)
            }
            IconButton(symbol: "plus", help: "New section (⌥⌘E)") { model.addSection() }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(Gallery.panel)
    }

    private func sectionBlock(_ section: SongSection, shots: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(section.name).font(.ocLabel).foregroundStyle(Gallery.ink).lineLimit(1)
            Text("\(item.format(section.at))  ·  \(shots) \(shots == 1 ? "shot" : "shots")")
                .font(.readout(10, weight: .regular))
                .foregroundStyle(Gallery.faint)
                .lineLimit(1)
        }
        .padding(.horizontal, Space.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(alignment: .leading) { Rectangle().fill(Gallery.dim.opacity(0.6)).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
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
        RoundedRectangle(cornerRadius: Radius.s)
            .strokeBorder(Gallery.divider, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: 24)
            .overlay(Image(systemName: "arrow.right.to.line").font(.system(size: 9)).foregroundStyle(Gallery.faint))
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
                                .listRowInsets(EdgeInsets(top: 0, leading: Space.s, bottom: 0, trailing: Space.m))
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
            .background(Gallery.base)
            .environment(\.defaultMinListRowHeight, 44)
            .overlay {
                if rows.isEmpty {
                    VStack(spacing: Space.s) {
                        Image(systemName: "video.badge.plus").font(.system(size: 26, weight: .light)).foregroundStyle(Gallery.faint)
                        Text("No shots yet").font(.ocHeading).foregroundStyle(Gallery.ink)
                        Text("Click a camera below, or select this list and press Return.")
                            .font(.ocMeta)
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
        if model.editorMode == .list { DispatchQueue.main.async { listFocused = true } }
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
        HStack(spacing: Space.s) {
            if let section {
                CommitField(placeholder: "Section", value: section.name, font: .ocHeading) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.renameSection(section.id, to: t)
                    return true
                }
                .frame(maxWidth: 220, alignment: .leading)
                CommitField(placeholder: "Start", value: item.format(section.at), font: .readout(11), width: 64) { text in
                    model.setSectionPosition(section.id, text: text)
                }
                .help("Section start (\(positionHint))")
            } else {
                Text(item.sections.isEmpty ? "Shots" : "Before the first section")
                    .font(.ocHeading)
                    .foregroundStyle(Gallery.dim)
                    .padding(.leading, 5)
            }
            Text("\(shotCount) \(shotCount == 1 ? "shot" : "shots")")
                .font(.ocMeta)
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Gallery.dim)
                        .frame(width: 24, height: 22)
                        .interactive()
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Move or delete this section. Its shots move with it; deleting keeps the shots.")
            }
        }
        .padding(.top, Space.s)
        .padding(.bottom, Space.xxs)
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
        HStack(spacing: Space.m) {
            Text(String(format: "%02d", row.number))
                .font(.readout(11))
                .foregroundStyle(Gallery.faint)
                .frame(width: 20, alignment: .trailing)

            Text(item.format(row.cue.at))
                .font(.readout(12))
                .foregroundStyle(Gallery.dim)
                .frame(width: 52, alignment: .leading)

            CameraChip(camera: camera, missing: row.cue.cameraID != nil && camera == nil, size: 26)

            VStack(alignment: .leading, spacing: 0) {
                Text(camera?.displayName ?? (row.cue.cameraID == nil ? "No camera" : "Deleted camera"))
                    .font(.ocBodyStrong)
                    .foregroundStyle(camera == nil ? Gallery.amber : Gallery.ink)
                if let op = camera?.operatorName, !op.isEmpty {
                    Text(op).font(.ocMeta).foregroundStyle(Gallery.faint)
                }
            }
            .frame(width: 96, alignment: .leading)
            .lineLimit(1)

            VStack(alignment: .leading, spacing: 0) {
                CommitField(placeholder: "Describe the shot", value: row.cue.text, font: .ocBody) { text in
                    model.updateShot(row.id, "Edit Shot") { $0.text = text }
                    return true
                }
                CommitField(placeholder: "Add a note for the operator", value: row.cue.note, font: .ocMeta) { text in
                    model.updateShot(row.id, "Edit Operator Note") { $0.note = text }
                    return true
                }
                .opacity(row.cue.note.isEmpty ? 0.55 : 0.85)
            }

            Spacer(minLength: Space.xs)

            TallyTag(state: tally)

            if !row.issues.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Gallery.amber)
                    .help(row.issues.map(\.message).joined(separator: "\n"))
            }

            Text(row.lengthSeconds.map { String(format: "%.1f s", $0) } ?? "NEXT")
                .font(.readout(11.5, weight: .medium))
                .foregroundStyle(Gallery.dim)
                .frame(width: 50, alignment: .trailing)

            Button {
                model.setTransition(row.cue.transition == .cut ? .auto : .cut, for: [row.id])
            } label: {
                Pill(text: row.cue.transition == .cut ? "CUT" : "MIX",
                     color: row.cue.transition == .cut ? Gallery.dim : Gallery.selection,
                     filled: row.cue.transition == .auto)
                    .frame(width: 36)
            }
            .buttonStyle(.plain)
            .help("Click to switch between cut and mix (⌥⌘T)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Space.xs)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(camera?.swiftUIColor ?? Gallery.key)
                .frame(width: 3)
                .padding(.vertical, 7)
        }
    }
}

// MARK: - Camera palette

/// The cameras as source-selection controls. In Edit Mode the selected shot's camera is marked
/// SHOT (red, filled tag) and the next shot's camera NEXT (green, outlined tag).
struct CameraPaletteView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sources").font(.ocHeading).foregroundStyle(Gallery.ink)
                Text(model.selectedShotIDs.isEmpty ? "Click adds a shot" : "⌥-click adds a shot")
                    .font(.ocMeta)
                    .foregroundStyle(Gallery.faint)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    IconButton(symbol: "plus", help: "New camera") { model.addCamera() }
                    IconButton(symbol: "slider.horizontal.3", help: "Manage cameras (⌥⌘C)") { model.cameraManagerOpen = true }
                }
                .padding(.leading, -5)
            }
            .frame(width: 118, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Space.s) {
                    ForEach(show.sortedCameras) { cam in
                        SourceButton(camera: cam, tally: model.tally(forCamera: cam.id)) {
                            model.useCamera(cam.id, newShot: NSEvent.modifierFlags.contains(.option))
                        }
                    }
                    if show.cameras.isEmpty {
                        Button("Add the first camera") { model.addCamera() }
                            .buttonStyle(QuietButtonStyle())
                    }
                }
                .padding(.vertical, Space.xs)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .frame(height: 74)
        .background(Gallery.panel)
    }
}

/// One camera as a source key: the number in the camera's colour, name, operator, a colour bar
/// along the bottom, and a labelled tally tag. Without an action it is a display (Live Mode).
struct SourceButton: View {
    let camera: Camera
    let tally: TallyState
    var live = false
    var width: CGFloat = 132
    var height: CGFloat = 50
    var numeral: CGFloat = 22
    var action: (() -> Void)? = nil
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) { face }
                    .buttonStyle(SourcePressStyle(pressed: $pressed))
                    .onHover { hovering = $0 }
            } else {
                face
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.15), value: tally)
        .help(camera.operatorName.isEmpty ? "Camera \(camera.number), \(camera.displayName)"
              : "Camera \(camera.number), \(camera.displayName), operated by \(camera.operatorName)")
    }

    private var face: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(camera.number)")
                .font(.cameraNumeral(numeral))
                .foregroundStyle(camera.swiftUIColor)
                .minimumScaleFactor(0.6)
                .frame(minWidth: numeral * 0.9, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(camera.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Gallery.ink)
                    .lineLimit(1)
                Text(camera.operatorName.isEmpty ? " " : camera.operatorName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Gallery.faint)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.bottom, 2)
        .frame(width: width, height: height)
        .overlay(alignment: .topTrailing) {
            TallyTag(state: tally, live: live).padding(.top, 5).padding(.trailing, 5)
        }
        .background(background, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(alignment: .bottom) {
            Rectangle().fill(camera.swiftUIColor).frame(height: 3)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Radius.m, bottomTrailingRadius: Radius.m))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.m)
            .strokeBorder(tally == .off ? Color.white.opacity(hovering ? 0.12 : 0.05) : tally.color, lineWidth: tally == .off ? 1 : 2))
        .scaleEffect(pressed ? 0.97 : 1)
        .contentShape(Rectangle())
    }

    private var background: Color {
        switch tally {
        case .current: return Gallery.tally.opacity(0.17)
        case .next: return Gallery.next.opacity(0.11)
        case .off: return hovering ? Gallery.key : Gallery.raised
        }
    }
}

private struct SourcePressStyle: ButtonStyle {
    @Binding var pressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, p in pressed = p }
    }
}
