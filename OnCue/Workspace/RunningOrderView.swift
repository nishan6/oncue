import SwiftUI
import OnCueCore

/// Left panel: the production and its running order (songs and segments, drag to reorder).
struct RunningOrderView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CommitField(placeholder: "Project name", value: model.project.name, font: .system(size: 15, weight: .semibold)) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.editProject("Rename Project") { $0.name = t }
                    return true
                }
                PlaylistBar(model: model)
                MetaLine(parts: [
                    "\(show.items.count) \(show.items.count == 1 ? "item" : "items")",
                    "\(show.cameraCount) \(show.cameraCount == 1 ? "camera" : "cameras")",
                    "\(totalShots) shots",
                    totalRun > 0 ? clockText(totalRun) : ""
                ])
                .padding(.leading, 5)
            }
            .padding(.horizontal, Space.m)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)

            PanelHeader(title: "Running order") {
                IconButton(symbol: "plus", help: "New song after the selection (⌥⌘N)") { model.addSong() }
            }

            List(selection: $model.selectedItemID) {
                ForEach(Array(show.items.enumerated()), id: \.element.id) { index, item in
                    RunningOrderRow(index: index + 1, item: item,
                                    shotCount: show.shotRows(forItem: item.id).count,
                                    runLength: show.runLength(forItem: item.id),
                                    strip: ShotStrip.segments(show: show, item: item),
                                    selected: model.selectedItemID == item.id,
                                    renaming: model.renamingItemID == item.id,
                                    model: model)
                        .tag(item.id)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Rename") { model.renamingItemID = item.id }
                            Button("Duplicate") { model.duplicateItem(item.id) }
                            Menu("Status") {
                                ForEach(SceneStatus.allCases) { st in
                                    Button(st.label) { model.updateScene(item.id) { $0.status = st } }
                                }
                            }
                            Button("Renumber Scenes…") { model.renumberPromptOpen = true }
                            Divider()
                            Button("New Song After") { model.selectedItemID = item.id; model.addSong() }
                            Button("New Segment After") { model.selectedItemID = item.id; model.addSegment() }
                            Divider()
                            Button("Delete", role: .destructive) { model.deleteItem(item.id) }
                        }
                }
                .onMove { model.moveItems($0, $1) }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let id = model.selectedItemID { model.deleteItem(id) }
            }

            Rectangle().fill(Gallery.hairline).frame(height: 1)
            HStack(spacing: Space.s) {
                Button { model.addSong() } label: { Label("Song", systemImage: "plus") }
                    .help("New song after the selection (⌥⌘N)")
                Button { model.addSegment() } label: { Label("Segment", systemImage: "plus") }
                    .help("New segment after the selection (⌥⇧⌘N)")
                Spacer()
            }
            .buttonStyle(QuietButtonStyle())
            .padding(Space.m)
        }
        .background(Gallery.panel)
    }

    private var totalShots: Int {
        show.items.reduce(0) { $0 + show.shotRows(forItem: $1.id).count }
    }

    private var totalRun: Double {
        show.items.reduce(0) { $0 + (show.runLength(forItem: $1.id) ?? 0) }
    }
}

/// The item's shots as a thin bar of camera colours, proportional to their length.
struct ShotStrip: View {
    struct Segment: Hashable {
        let start: Double
        let length: Double
        let color: String?
    }
    let segments: [Segment]

    static func segments(show: Show, item: RundownItem) -> [Segment] {
        let spans = show.shotSpans(forItem: item.id)
        guard let last = spans.last else { return [] }
        let origin = item.timeBase == .order ? 1.0 : 0.0
        let total = max(last.end - origin, 0.0001)
        return spans.map { span in
            Segment(start: (span.start - origin) / total, length: (span.end - span.start) / total,
                    color: show.camera(span.row.cue.cameraID)?.resolvedColor)
        }
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5), with: .color(Gallery.well))
            for seg in segments {
                let rect = CGRect(x: seg.start * size.width, y: 0, width: max(seg.length * size.width - 0.5, 0.5), height: size.height)
                context.fill(Path(rect), with: .color(seg.color.map { Color(hex: $0) } ?? Gallery.key))
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }
}

struct RunningOrderRow: View {
    let index: Int
    let item: RundownItem
    let shotCount: Int
    let runLength: Double?
    let strip: [ShotStrip.Segment]
    let selected: Bool
    let renaming: Bool
    @ObservedObject var model: WorkspaceModel
    @State private var draft = ""
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Text(item.number.isEmpty ? String(format: "%02d", index) : item.number)
                .font(.readout(11, weight: .semibold))
                .foregroundStyle(selected ? Gallery.ink : Gallery.faint)
                .lineLimit(1)
                .frame(minWidth: 18, alignment: .trailing)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(item.kind == .song ? Gallery.selection : Gallery.amber).frame(width: 6, height: 6)
                    if renaming {
                        TextField("Title", text: $draft)
                            .textFieldStyle(.plain)
                            .font(.ocBodyStrong)
                            .focused($focused)
                            .onAppear { draft = item.title; focused = true }
                            .onSubmit { model.renameItem(item.id, to: draft); model.renamingItemID = nil }
                            .onExitCommand { model.renamingItemID = nil }
                            .onChange(of: focused) { _, f in if !f { model.renamingItemID = nil } }
                    } else {
                        Text(item.title)
                            .font(.ocBodyStrong)
                            .foregroundStyle(Gallery.ink)
                            .lineLimit(1)
                        if item.status != .unset { SceneStatusTag(status: item.status) }
                    }
                }
                MetaLine(parts: meta, font: .ocMeta, color: Gallery.dim)
                if !strip.isEmpty {
                    ShotStrip(segments: strip).padding(.top, 1)
                }
            }
            Spacer(minLength: Space.xs)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(shotCount)")
                    .font(.readout(12, weight: .semibold))
                    .foregroundStyle(shotCount == 0 ? Gallery.faint : Gallery.dim)
                if hovering {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Gallery.faint)
                        .help("Drag to reorder")
                }
            }
            .padding(.top, 1)
        }
        .padding(.vertical, Space.xs + 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help("\(item.title): \(shotCount) \(shotCount == 1 ? "shot" : "shots")")
    }

    private var meta: [String] {
        var parts: [String] = []
        if !item.artist.isEmpty { parts.append(item.artist) }
        switch item.timeBase {
        case .bars: parts.append("\(Int(item.bpm.rounded())) BPM")
        case .seconds: parts.append(item.kind.label)
        case .order: parts.append("NEXT")
        }
        if let runLength { parts.append(clockText(runLength)) }
        if !item.hardOut.isEmpty { parts.append("out \(item.hardOut)") }
        return parts
    }
}


/// Draft / WIP / OK / NOK on a scene.
struct SceneStatusTag: View {
    let status: SceneStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.6), lineWidth: 1))
            .accessibilityLabel("Status \(status.label)")
    }

    private var color: Color {
        switch status {
        case .ok: return Gallery.next
        case .nok: return Gallery.tally
        case .wip: return Gallery.amber
        case .draft, .unset: return Gallery.dim
        }
    }
}

/// The playlist this window edits, and the playlist operations.
struct PlaylistBar: View {
    @ObservedObject var model: WorkspaceModel
    @State private var naming: Naming?
    @State private var text = ""
    @State private var confirmDelete = false

    enum Naming: Identifiable {
        case new, rename(UUID)
        var id: String {
            switch self {
            case .new: return "new"
            case .rename(let id): return id.uuidString
            }
        }
    }

    var body: some View {
        let project = model.project
        let active = project.playlist(model.activePlaylistID) ?? project.playlists.first
        Menu {
            ForEach(project.playlists) { list in
                Button {
                    model.selectPlaylist(list.id)
                } label: {
                    if list.id == active?.id { Label(list.name, systemImage: "checkmark") } else { Text(list.name) }
                }
            }
            Divider()
            Button("New Playlist…") { text = ""; naming = .new }
            if let active {
                Button("Rename Playlist…") { text = active.name; naming = .rename(active.id) }
                Button("Duplicate Playlist") { model.duplicatePlaylist(active.id) }
                Button("Delete Playlist…") { confirmDelete = true }
                    .disabled(project.playlists.count < 2)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle").font(.system(size: 10))
                Text(active?.name ?? "Playlist").font(.ocLabel).lineLimit(1)
                Text("· \(project.playlists.count)").font(.ocMeta).foregroundStyle(Gallery.faint)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.leading, 5)
        .help("Playlists in this project")
        .alert(naming.map { if case .new = $0 { return "New Playlist" } else { return "Rename Playlist" } } ?? "",
               isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $text)
            Button("Cancel", role: .cancel) { naming = nil }
            Button("OK") {
                switch naming {
                case .new: model.addPlaylist(named: text.trimmingCharacters(in: .whitespaces))
                case .rename(let id): model.renamePlaylist(id, to: text)
                case nil: break
                }
                naming = nil
            }
        }
        .confirmationDialog("Delete “\(active?.name ?? "")”?", isPresented: $confirmDelete) {
            Button("Delete Playlist", role: .destructive) { if let active { model.deletePlaylist(active.id) } }
        } message: {
            Text("Its scenes are removed from the project. A version is kept first, so it can be restored from Versions, and Edit › Undo also brings it back.")
        }
    }
}
