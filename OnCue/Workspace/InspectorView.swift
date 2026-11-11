import SwiftUI
import OnCueCore

/// Right panel: properties of the selected shot(s), or of the song/segment when no shot is selected.
struct InspectorView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let item = show.item(model.selectedItemID) {
                    let rows = show.shotRows(forItem: item.id)
                    let selected = rows.filter { model.selectedShotIDs.contains($0.id) }
                    if selected.count == 1, let row = selected.first {
                        ShotInspector(show: show, item: item, row: row, next: next(after: row, in: rows), model: model)
                    } else if selected.count > 1 {
                        MultiShotInspector(show: show, rows: selected, model: model)
                    } else {
                        ItemInspector(show: show, item: item, model: model)
                    }
                } else {
                    Text("Nothing selected").foregroundStyle(Gallery.dim)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Gallery.panel)
    }

    private func next(after row: ShotRow, in rows: [ShotRow]) -> ShotRow? {
        guard let k = rows.firstIndex(where: { $0.id == row.id }), k + 1 < rows.count else { return nil }
        return rows[k + 1]
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.umd(11)).foregroundStyle(Gallery.dim)
            content
        }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                CameraTile(number: camera?.number, name: camera?.displayName ?? "No camera",
                           operatorName: camera?.operatorName ?? "", tally: .current, size: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shot \(row.number)")
                        .font(.title(20))
                        .foregroundStyle(Gallery.ink)
                    Text(sectionName)
                        .font(.umd(12))
                        .foregroundStyle(Gallery.dim)
                    if let next {
                        HStack(spacing: 6) {
                            Circle().fill(Gallery.next).frame(width: 7, height: 7)
                            Text("Next: \(show.camera(next.cue.cameraID).map { "\($0.number) \($0.displayName)" } ?? "no camera")")
                                .font(.umd(11))
                                .foregroundStyle(Gallery.dim)
                        }
                    }
                }
            }

            InspectorSection(title: "Camera") {
                Menu {
                    ForEach(show.sortedCameras) { cam in
                        Button("\(cam.number)  \(cam.label)") { model.useCamera(cam.id, newShot: false) }
                    }
                    Divider()
                    Button("No camera") {
                        model.updateShot(row.id, "Clear Camera") { $0.cameraID = nil }
                    }
                } label: {
                    Text(camera.map { "\($0.number)  \($0.label)" } ?? "Choose a camera")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .help("Or type the camera number with the shot list selected")
            }

            HStack(alignment: .top, spacing: 12) {
                InspectorSection(title: "Position") {
                    CommitField(placeholder: "Position", value: item.format(row.cue.at), font: .readout(14, weight: .semibold), width: 90) { text in
                        model.setShotPosition(row.id, text: text)
                    }
                    .help(positionHint)
                }
                InspectorSection(title: "Length") {
                    Text(row.lengthSeconds.map { String(format: "%.1f s", $0) } ?? "–")
                        .font(.readout(14, weight: .semibold))
                        .foregroundStyle(Gallery.ink)
                }
            }

            InspectorSection(title: "Transition") {
                Picker("Transition", selection: Binding(get: { row.cue.transition },
                                                         set: { model.setTransition($0, for: [row.id]) })) {
                    Text("Cut").tag(TransitionKind.cut)
                    Text("Mix").tag(TransitionKind.auto)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            InspectorSection(title: "Shot description") {
                CommitTextArea(placeholder: "What the audience sees", value: row.cue.text) { text in
                    model.updateShot(row.id, "Edit Shot") { $0.text = text }
                }
            }

            InspectorSection(title: "Note for the operator") {
                CommitTextArea(placeholder: "Framing, movement, timing", value: row.cue.note) { text in
                    model.updateShot(row.id, "Edit Operator Note") { $0.note = text }
                }
            }

            if !row.issues.isEmpty {
                InspectorSection(title: "Check") {
                    ForEach(row.issues, id: \.self) { issue in
                        HStack(spacing: 6) {
                            Circle().fill(Gallery.amber).frame(width: 6, height: 6)
                            Text(issue.message).font(.system(size: 12)).foregroundStyle(Gallery.ink)
                        }
                    }
                }
            }

            HStack {
                Button("Duplicate") { model.duplicateSelectedShots() }
                Spacer()
                Button("Delete Shot", role: .destructive) { model.deleteSelectedShots() }
            }
            .controlSize(.small)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("\(rows.count) shots selected")
                .font(.title(18))
                .foregroundStyle(Gallery.ink)
            InspectorSection(title: "Set camera on all") {
                Menu("Choose a camera") {
                    ForEach(show.sortedCameras) { cam in
                        Button("\(cam.number)  \(cam.label)") { model.useCamera(cam.id, newShot: false) }
                    }
                }
            }
            InspectorSection(title: "Transition") {
                HStack {
                    Button("All cuts") { model.setTransition(.cut) }
                    Button("All mixes") { model.setTransition(.auto) }
                }
            }
            HStack {
                Button("Duplicate") { model.duplicateSelectedShots() }
                Spacer()
                Button("Delete Shots", role: .destructive) { model.deleteSelectedShots() }
            }
            .controlSize(.small)
        }
    }
}

private struct ItemInspector: View {
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.title)
                .font(.title(18))
                .foregroundStyle(Gallery.ink)
            Text("Select a shot to edit it. With the shot list selected, press Return for a new shot and type a camera number to set it.")
                .font(.system(size: 12))
                .foregroundStyle(Gallery.dim)
                .fixedSize(horizontal: false, vertical: true)

            InspectorSection(title: "Sections") {
                if item.sections.isEmpty {
                    Text("None yet").foregroundStyle(Gallery.faint)
                }
                List {
                    ForEach(item.sortedSections) { section in
                        HStack {
                            Text(section.name).font(.umd(13)).foregroundStyle(Gallery.ink)
                            Spacer()
                            Text(item.format(section.at)).font(.readout(11)).foregroundStyle(Gallery.dim)
                        }
                    }
                    .onMove { model.moveSections($0, $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(max(item.sections.count, 1)) * 26 + 8)
                Button("New Section") { model.addSection() }
                    .controlSize(.small)
            }

            let unused = show.unusedCameras(inItem: item.id)
            if !unused.isEmpty {
                InspectorSection(title: "Cameras not used here") {
                    Text(unused.map { "\($0.number) \($0.displayName)" }.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundStyle(Gallery.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            InspectorSection(title: "Notes") {
                CommitTextArea(placeholder: "Notes for this \(item.kind == .song ? "song" : "segment")", value: item.notes) { text in
                    model.updateItem("Edit Notes") { $0.notes = text }
                }
            }
        }
    }
}

/// Multi-line text that commits when editing ends (one undo step per edit, not per keystroke).
struct CommitTextArea: View {
    let placeholder: String
    let value: String
    let commit: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Gallery.ink)
            .lineLimit(2...8)
            .focused($focused)
            .padding(8)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(focused ? Gallery.steel : Gallery.hairline, lineWidth: 1))
            .onAppear { draft = value }
            .onChange(of: value) { _, new in if !focused { draft = new } }
            .onChange(of: focused) { _, f in if !f && draft != value { commit(draft) } }
    }
}
