import SwiftUI
import OnCueCore

/// Right panel: properties of the selection: a shot, several shots, a lyric/note/FX cue, or the
/// song or segment when nothing is selected.
struct InspectorView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let item = show.item(model.selectedItemID) {
                    let rows = show.shotRows(forItem: item.id)
                    let selected = rows.filter { model.selectedShotIDs.contains($0.id) }
                    if let cueID = model.selectedCueID, let cue = show.cue(cueID, inItem: item.id),
                       let kind = show.trackKind(ofCue: cueID, inItem: item.id) {
                        CueInspector(show: show, item: item, cue: cue, kind: kind, model: model)
                    } else if selected.count == 1, let row = selected.first {
                        ShotInspector(show: show, item: item, row: row, next: next(after: row, in: rows), model: model)
                    } else if selected.count > 1 {
                        MultiShotInspector(show: show, rows: selected, model: model)
                    } else {
                        ItemInspector(show: show, item: item, model: model)
                    }
                } else {
                    Text("Nothing selected")
                        .font(.ocMeta)
                        .foregroundStyle(Gallery.faint)
                        .padding(Space.l)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.14), value: model.selectedShotIDs)
            .animation(.easeOut(duration: 0.14), value: model.selectedCueID)
        }
        .background(Gallery.panel)
    }

    private func next(after row: ShotRow, in rows: [ShotRow]) -> ShotRow? {
        guard let k = rows.firstIndex(where: { $0.id == row.id }), k + 1 < rows.count else { return nil }
        return rows[k + 1]
    }
}

/// Camera picker shown as a field: the camera's chip, name and operator. Opens a list of cameras.
private struct CameraField: View {
    let show: Show
    let camera: Camera?
    let missing: Bool
    let choose: (UUID?) -> Void
    @State private var open = false
    @State private var hovering = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: Space.s) {
                CameraChip(camera: camera, missing: missing, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(camera?.displayName ?? (missing ? "Deleted camera" : "Choose a camera"))
                        .font(.ocBodyStrong)
                        .foregroundStyle(camera == nil ? Gallery.amber : Gallery.ink)
                    if let op = camera?.operatorName, !op.isEmpty {
                        Text(op).font(.ocMeta).foregroundStyle(Gallery.faint)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Gallery.faint)
            }
            .padding(.horizontal, Space.s)
            .padding(.vertical, 6)
            .background(hovering ? Gallery.key : Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Or type the camera number with the timeline or shot list selected")
        .popover(isPresented: $open, arrowEdge: .leading) {
            CameraChoiceList(show: show, current: camera?.id) { id in
                open = false
                choose(id)
            }
        }
    }
}

/// List of the production's cameras to pick from.
struct CameraChoiceList: View {
    let show: Show
    let current: UUID?
    let choose: (UUID?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(show.sortedCameras) { cam in
                    Button { choose(cam.id) } label: {
                        HStack(spacing: Space.s) {
                            CameraChip(camera: cam, size: 20)
                            Text(cam.displayName).font(.ocBodyStrong).foregroundStyle(Gallery.ink)
                            Text(cam.operatorName).font(.ocMeta).foregroundStyle(Gallery.faint)
                            Spacer(minLength: Space.s)
                            if cam.id == current {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Gallery.selection)
                            }
                        }
                        .padding(.horizontal, Space.s)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .interactive()
                    }
                    .buttonStyle(.plain)
                }
                Rectangle().fill(Gallery.hairline).frame(height: 1).padding(.vertical, Space.xs)
                Button { choose(nil) } label: {
                    Text("No camera").font(.ocBody).foregroundStyle(Gallery.dim)
                        .padding(.horizontal, Space.s)
                        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                        .contentShape(Rectangle())
                        .interactive()
                }
                .buttonStyle(.plain)
            }
            .padding(Space.s)
        }
        .frame(width: 260)
        .frame(maxHeight: 360)
    }
}

private struct ShotInspector: View {
    let show: Show
    let item: RundownItem
    let row: ShotRow
    let next: ShotRow?
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let camera = show.camera(row.cue.cameraID)
        let missing = row.cue.cameraID != nil && camera == nil
        VStack(alignment: .leading, spacing: 0) {
            // Identity: the shot in its camera's colour.
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(alignment: .center, spacing: Space.m) {
                    CameraChip(camera: camera, missing: missing, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Shot \(row.number)").font(.ocTitle).foregroundStyle(Gallery.ink)
                        MetaLine(parts: [sectionName, item.format(row.cue.at)])
                    }
                }
                if let next {
                    let nextCam = show.camera(next.cue.cameraID)
                    HStack(spacing: Space.s) {
                        TallyTag(state: .next)
                        CameraChip(camera: nextCam, size: 16)
                        Text(nextCam.map { $0.displayName } ?? "No camera")
                            .font(.ocLabel)
                            .foregroundStyle(Gallery.dim)
                        if !next.cue.text.isEmpty {
                            Text(next.cue.text).font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((camera?.swiftUIColor ?? Gallery.key).opacity(0.10))
            .overlay(alignment: .top) {
                Rectangle().fill(camera?.swiftUIColor ?? Gallery.key).frame(height: 3)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Gallery.hairline).frame(height: 1) }

            InspectorGroup(title: "Camera") {
                CameraField(show: show, camera: camera, missing: missing) { id in
                    if let id { model.useCamera(id, newShot: false) } else {
                        model.updateShot(row.id, "Clear Camera") { $0.cameraID = nil }
                    }
                }
            }

            InspectorGroup(title: "Timing") {
                PropertyRow(label: "Position") {
                    CommitField(placeholder: "Position", value: item.format(row.cue.at), font: .readout(13), width: 90) { text in
                        model.setShotPosition(row.id, text: text)
                    }
                    .help(positionHint)
                }
                PropertyRow(label: "Length") {
                    Text(row.lengthSeconds.map { String(format: "%.1f s", $0) } ?? "Until NEXT")
                        .font(.readout(13))
                        .foregroundStyle(Gallery.ink)
                        .padding(.leading, 5)
                }
                PropertyRow(label: "Transition") {
                    Picker("Transition", selection: Binding(get: { row.cue.transition },
                                                             set: { model.setTransition($0, for: [row.id]) })) {
                        Text("Cut").tag(TransitionKind.cut)
                        Text("Mix").tag(TransitionKind.auto)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                }
            }

            InspectorGroup(title: "Description") {
                CommitTextArea(placeholder: "What the audience sees", value: row.cue.text) { text in
                    model.updateShot(row.id, "Edit Shot") { $0.text = text }
                }
            }

            InspectorGroup(title: "Note for the operator") {
                CommitTextArea(placeholder: "Framing, movement, timing", value: row.cue.note) { text in
                    model.updateShot(row.id, "Edit Operator Note") { $0.note = text }
                }
            }

            let shotComments = show.comments.filter { $0.cueID == row.id }
            if !shotComments.isEmpty {
                InspectorGroup(title: "Crew comments") {
                    ForEach(shotComments) { comment in
                        CommentRow(comment: comment, model: model)
                    }
                }
            }

            if !row.issues.isEmpty {
                InspectorGroup(title: "Check") {
                    ForEach(row.issues, id: \.self) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.ocMeta)
                            .foregroundStyle(Gallery.amber)
                    }
                }
            }

            HStack(spacing: Space.s) {
                Button { model.duplicateSelectedShots() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    .buttonStyle(QuietButtonStyle())
                    .help("Duplicate (⌘D)")
                Spacer()
                Button(role: .destructive) { model.deleteSelectedShots() } label: { Label("Delete", systemImage: "trash") }
                    .buttonStyle(QuietButtonStyle(destructive: true))
                    .help("Delete (⌫)")
            }
            .padding(Space.l)
        }
    }

    private var sectionName: String {
        item.sections.first { $0.id == row.sectionID }?.name ?? (item.sections.isEmpty ? item.title : "Before the first section")
    }

    private var positionHint: String {
        switch item.timeBase {
        case .bars: return "Bar.beat, e.g. 17.1"
        case .seconds: return "Minutes and seconds, e.g. 1:30"
        case .order: return "Step number"
        }
    }
}

private struct MultiShotInspector: View {
    let show: Show
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorGroup(title: nil) {
                Text("\(rows.count) shots").font(.ocTitle).foregroundStyle(Gallery.ink)
                HStack(spacing: 3) {
                    ForEach(rows.prefix(16)) { row in
                        CameraChip(camera: show.camera(row.cue.cameraID), size: 16)
                    }
                }
            }
            InspectorGroup(title: "Camera for all") {
                CameraField(show: show, camera: nil, missing: false) { id in
                    if let id { model.useCamera(id, newShot: false) }
                }
            }
            InspectorGroup(title: "Transition for all") {
                HStack(spacing: Space.s) {
                    Button("All cuts") { model.setTransition(.cut) }
                    Button("All mixes") { model.setTransition(.auto) }
                }
                .buttonStyle(QuietButtonStyle())
            }
            HStack(spacing: Space.s) {
                Button { model.duplicateSelectedShots() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Button(role: .destructive) { model.deleteSelectedShots() } label: { Label("Delete", systemImage: "trash") }
                    .buttonStyle(QuietButtonStyle(destructive: true))
            }
            .padding(Space.l)
        }
    }
}

private struct ItemInspector: View {
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorGroup(title: nil) {
                KindTag(kind: item.kind)
                Text(item.title).font(.ocTitle).foregroundStyle(Gallery.ink)
                Text("Select a shot to edit it. Double-click a track on the timeline to add a shot, lyric, note or FX cue. Return adds a shot; typing a number sets its camera.")
                    .font(.ocMeta)
                    .foregroundStyle(Gallery.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            InspectorGroup(title: "Scene") {
                SceneFieldRow(label: "Number") {
                    CommitField(placeholder: "–", value: item.number, width: 90) { text in
                        model.updateScene(item.id, "Scene Number") { $0.number = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
                SceneFieldRow(label: "Artist") {
                    CommitField(placeholder: "–", value: item.artist, font: .ocBody) { text in
                        model.updateScene(item.id, "Scene Artist") { $0.artist = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
                SceneFieldRow(label: "Status") {
                    Picker("", selection: Binding(get: { item.status },
                                                  set: { st in model.updateScene(item.id, "Scene Status") { $0.status = st } })) {
                        ForEach(SceneStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                SceneFieldRow(label: "Frame rate") {
                    Picker("", selection: Binding(get: { item.frameRate?.key ?? "" },
                                                  set: { key in
                                                      let rate = key.isEmpty ? nil : FrameRate(key: key)
                                                      model.updateScene(item.id, "Scene Frame Rate") { $0.frameRate = rate }
                                                  })) {
                        Text("Project (\(model.project.frameRate.label))").tag("")
                        ForEach(FrameRate.presets) { Text($0.label).tag($0.key) }
                        if let own = item.frameRate, !FrameRate.presets.contains(own) { Text(own.label).tag(own.key) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            InspectorGroup(title: "Sections") {
                if item.sections.isEmpty {
                    Text("None yet").font(.ocMeta).foregroundStyle(Gallery.faint)
                } else {
                    List {
                        ForEach(item.sortedSections) { section in
                            HStack {
                                Text(section.name).font(.ocBody).foregroundStyle(Gallery.ink)
                                Spacer()
                                Text(item.format(section.at)).font(.readout(11)).foregroundStyle(Gallery.faint)
                            }
                        }
                        .onMove { model.moveSections($0, $1) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(item.sections.count) * 26 + 6)
                }
                Button { model.addSection() } label: { Label("New Section", systemImage: "plus") }
                    .buttonStyle(QuietButtonStyle())
            }

            let unused = show.unusedCameras(inItem: item.id)
            if !unused.isEmpty {
                InspectorGroup(title: "Cameras not used here") {
                    FlowChips(cameras: unused)
                }
            }

            InspectorGroup(title: "Notes") {
                CommitTextArea(placeholder: "Notes for this \(item.kind == .song ? "song" : "segment")", value: item.notes, minLines: 3) { text in
                    model.updateItem("Edit Notes") { $0.notes = text }
                }
            }
        }
    }
}

/// Camera chips with names, wrapping into rows.
private struct FlowChips: View {
    let cameras: [Camera]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Space.s, alignment: .leading)], alignment: .leading, spacing: Space.s) {
            ForEach(cameras) { cam in
                HStack(spacing: 6) {
                    CameraChip(camera: cam, size: 18)
                    Text(cam.displayName).font(.ocMeta).foregroundStyle(Gallery.dim).lineLimit(1)
                }
            }
        }
    }
}

/// A lyric, note, FX, control, OSC or PTZ cue, or a shot on a separate output, selected on the timeline.
private struct CueInspector: View {
    let show: Show
    let item: RundownItem
    let cue: Cue
    let kind: TrackKind
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let outputID = kind == .shots ? show.outputID(ofCue: cue.id, inItem: item.id) : nil
        let lane: TimelineLane = outputID.map { .output($0) } ?? .forKind(kind)
        VStack(alignment: .leading, spacing: 0) {
            InspectorGroup(title: nil) {
                HStack(spacing: Space.s) {
                    Image(systemName: lane.symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(lane.tone)
                    Text(kind.cueTitle).font(.ocTitle).foregroundStyle(Gallery.ink)
                }
                MetaLine(parts: [outputID.flatMap { show.output($0)?.name } ?? lane.label + " track", item.format(cue.at)])
            }
            .overlay(alignment: .top) { Rectangle().fill(lane.tone).frame(height: 3) }

            InspectorGroup(title: "Timing") {
                PropertyRow(label: "Position") {
                    CommitField(placeholder: "Position", value: item.format(cue.at), font: .readout(13), width: 90) { text in
                        guard let pos = item.parse(text), pos >= 0 else { return false }
                        model.moveCue(cue.id, to: pos)
                        return true
                    }
                }
            }
            if kind == .shots {
                InspectorGroup(title: "Camera") {
                    Picker("Camera", selection: Binding(get: { cue.cameraID },
                                                        set: { id in model.updateCue(cue.id, "Set Camera") { $0.cameraID = id } })) {
                        Text("No camera").tag(UUID?.none)
                        ForEach(show.sortedCameras) { Text("\($0.number)  \($0.label)").tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden()
                    PropertyRow(label: "Transition") {
                        Picker("Transition", selection: Binding(get: { cue.transition },
                                                                 set: { t in model.updateCue(cue.id, "Change Transition") { $0.transition = t } })) {
                            Text("Cut").tag(TransitionKind.cut)
                            Text("Mix").tag(TransitionKind.auto)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 150)
                    }
                    CommitTextArea(placeholder: "Description", value: cue.text) { text in
                        model.updateCue(cue.id, "Edit Shot") { $0.text = text }
                    }
                }
            } else {
                InspectorGroup(title: "Cue") {
                    CueFields(kind: kind, cue: cue, show: show, model: model)
                }
            }
            HStack {
                Spacer()
                Button(role: .destructive) { model.deleteSelectedCue() } label: { Label("Delete \(kind.cueTitle)", systemImage: "trash") }
                    .buttonStyle(QuietButtonStyle(destructive: true))
            }
            .padding(Space.l)
        }
    }
}

/// A comment from the crew page or script review: resolve it or delete it.
struct CommentRow: View {
    let comment: Comment
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Button {
                model.edit(comment.resolved ? "Reopen Comment" : "Resolve Comment") {
                    $0.setCommentResolved(comment.id, !comment.resolved)
                }
            } label: {
                Image(systemName: comment.resolved ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(comment.resolved ? Gallery.next : Gallery.faint)
            }
            .buttonStyle(.plain)
            .help(comment.resolved ? "Reopen" : "Mark as resolved")
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.text)
                    .font(.ocBody)
                    .foregroundStyle(comment.resolved ? Gallery.faint : Gallery.ink)
                    .strikethrough(comment.resolved, color: Gallery.faint)
                    .fixedSize(horizontal: false, vertical: true)
                MetaLine(parts: [comment.author, comment.date.formatted(date: .abbreviated, time: .shortened)])
            }
            Spacer(minLength: 0)
            Button {
                model.edit("Delete Comment") { $0.deleteComment(comment.id) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Gallery.faint)
            }
            .buttonStyle(.plain)
            .help("Delete comment")
        }
        .padding(Space.s)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.s))
    }
}

/// A label and its control, in a row.
private struct SceneFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Space.s) {
            Text(label).font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 74, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}
