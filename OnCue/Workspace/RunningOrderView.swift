import SwiftUI
import OnCueCore

/// Left panel: the production and its running order (songs and segments, drag to reorder).
struct RunningOrderView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Space.xs) {
                CommitField(placeholder: "Production name", value: show.name, font: .system(size: 15, weight: .semibold)) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.renameShow(t)
                    return true
                }
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
            Text(String(format: "%02d", index))
                .font(.readout(11, weight: .semibold))
                .foregroundStyle(selected ? Gallery.ink : Gallery.faint)
                .frame(width: 18, alignment: .trailing)
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
