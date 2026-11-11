import SwiftUI
import OnCueCore

/// Left panel: production name and the running order (songs and segments, drag to reorder).
struct RunningOrderView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Production")
                    .font(.umd(11))
                    .foregroundStyle(Gallery.dim)
                CommitField(placeholder: "Production name", value: show.name, font: .title(17)) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    model.renameShow(t)
                    return true
                }
                HStack(spacing: 10) {
                    stat("\(show.items.count)", show.items.count == 1 ? "item" : "items")
                    stat("\(show.cameraCount)", show.cameraCount == 1 ? "camera" : "cameras")
                    stat("\(totalShots)", totalShots == 1 ? "shot" : "shots")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Gallery.hairline).frame(height: 1)

            PanelHeader(title: "Running order")

            List(selection: $model.selectedItemID) {
                ForEach(Array(show.items.enumerated()), id: \.element.id) { index, item in
                    RunningOrderRow(index: index + 1, item: item,
                                    shotCount: show.shotRows(forItem: item.id).count,
                                    selected: model.selectedItemID == item.id,
                                    renaming: model.renamingItemID == item.id,
                                    model: model)
                        .tag(item.id)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
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
            HStack(spacing: 8) {
                Button { model.addSong() } label: { Label("Song", systemImage: "plus") }
                    .help("New song after the selection (⌥⌘N)")
                Button { model.addSegment() } label: { Label("Segment", systemImage: "plus") }
                    .help("New segment after the selection (⌥⇧⌘N)")
                Spacer()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Gallery.ink)
            .padding(10)
        }
        .background(Gallery.panel)
    }

    private var totalShots: Int {
        show.items.reduce(0) { $0 + show.shotRows(forItem: $1.id).count }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value).font(.readout(11, weight: .semibold)).foregroundStyle(Gallery.ink)
            Text(label).font(.system(size: 11)).foregroundStyle(Gallery.dim)
        }
    }
}

struct RunningOrderRow: View {
    let index: Int
    let item: RundownItem
    let shotCount: Int
    let selected: Bool
    let renaming: Bool
    @ObservedObject var model: WorkspaceModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(.readout(12, weight: .semibold))
                .foregroundStyle(selected ? Gallery.ink : Gallery.faint)
                .frame(width: 22, alignment: .trailing)

            Rectangle()
                .fill(item.kind == .song ? Gallery.steel : Gallery.amber)
                .frame(width: 3, height: 30)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                if renaming {
                    TextField("Title", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .focused($focused)
                        .onAppear { draft = item.title; focused = true }
                        .onSubmit { model.renameItem(item.id, to: draft); model.renamingItemID = nil }
                        .onExitCommand { model.renamingItemID = nil }
                        .onChange(of: focused) { _, f in if !f { model.renamingItemID = nil } }
                } else {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Gallery.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text(item.kind == .song ? "Song" : "Segment")
                    Text(meta)
                }
                .font(.umd(10))
                .foregroundStyle(Gallery.dim)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(shotCount)")
                    .font(.readout(13, weight: .semibold))
                    .foregroundStyle(shotCount == 0 ? Gallery.faint : Gallery.ink)
                Text(shotCount == 1 ? "shot" : "shots")
                    .font(.umd(9))
                    .foregroundStyle(Gallery.dim)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts: [String] = []
        switch item.timeBase {
        case .bars: parts.append("\(Int(item.bpm.rounded())) BPM  \(item.beatsPerBar)/4")
        case .seconds: if item.plannedDuration > 0 { parts.append(TimeFormat.mmss(item.plannedDuration).replacingOccurrences(of: ".0", with: "")) }
        case .order: parts.append("NEXT order")
        }
        if !item.hardOut.isEmpty { parts.append("out \(item.hardOut)") }
        return parts.joined(separator: "   ")
    }
}
