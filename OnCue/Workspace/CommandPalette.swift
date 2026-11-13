import SwiftUI
import OnCueCore

/// ⌘K: one box to jump to any song or shot, or open any tool. Type part of a title, a shot's
/// words, "cam 3" for camera 3's shots, "#12" for shot 12, or a tool's name. ↑↓ and Return.
struct CommandPalette: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    struct Entry: Identifiable {
        enum Kind { case song, shot, tool }
        let id: String
        let kind: Kind
        let title: String
        let detail: String
        let symbol: String
        let search: String
        let run: () -> Void
    }

    var body: some View {
        let results = Array(matches.prefix(40))
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(Gallery.faint)
                TextField("Jump to a song or shot, or open a tool…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17 * TextScale.factor))
                    .focused($focused)
                    .onSubmit { run(results) }
                    .onKeyPress(.downArrow) { highlighted = min(highlighted + 1, max(results.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { highlighted = max(highlighted - 1, 0); return .handled }
                    .onExitCommand { dismiss() }
            }
            .padding(Space.m)
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        if results.isEmpty {
                            Text("Nothing matches “\(query)”").font(.ocMeta).foregroundStyle(Gallery.faint).padding(Space.m)
                        }
                        ForEach(Array(results.enumerated()), id: \.element.id) { k, e in
                            Button { highlighted = k; run(results) } label: {
                                HStack(spacing: Space.s) {
                                    Image(systemName: e.symbol).frame(width: 18).foregroundStyle(Gallery.dim)
                                    Text(e.title).font(.ocBody).foregroundStyle(Gallery.ink).lineLimit(1)
                                    Spacer(minLength: Space.s)
                                    Text(e.detail).font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                                }
                                .padding(.horizontal, Space.m)
                                .padding(.vertical, 7)
                                .background(k == highlighted ? Gallery.selection.opacity(0.25) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: Radius.s))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(k)
                        }
                    }
                    .padding(Space.s)
                }
                .onChange(of: highlighted) { _, k in proxy.scrollTo(k) }
            }
        }
        .frame(width: 620, height: 420)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
    }

    private func run(_ results: [Entry]) {
        guard results.indices.contains(highlighted) else { return }
        let e = results[highlighted]
        dismiss()
        DispatchQueue.main.async { e.run() }
    }

    private var matches: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = entries(query: q)
        guard !q.isEmpty else { return all.filter { $0.kind != .shot } }
        // "cam 3" / "#12" are exact; otherwise every word typed must appear.
        let words = q.split(separator: " ").map(String.init)
        return all.filter { e in words.allSatisfy { e.search.contains($0) } }
            .sorted { a, b in
                let ap = a.title.lowercased().hasPrefix(q), bp = b.title.lowercased().hasPrefix(q)
                return ap != bp ? ap : false
            }
    }

    private func entries(query q: String) -> [Entry] {
        var out: [Entry] = []
        for (k, item) in show.items.enumerated() {
            let number = item.number.isEmpty ? "\(k + 1)" : item.number
            out.append(Entry(id: "song-\(item.id)", kind: .song, title: item.title,
                             detail: "\(item.kind == .song ? "Song" : "Segment") \(number) · \(show.shotRows(forItem: item.id).count) shots",
                             symbol: item.kind == .song ? "music.note" : "rectangle.split.3x1",
                             search: "\(item.title) \(number) \(item.kind == .song ? "song" : "segment")".lowercased()) {
                model.selectedItemID = item.id
            })
        }
        // Shots: the selected song's, or every song's when the query names a camera or shot number.
        let everywhere = q.hasPrefix("cam") || q.hasPrefix("#")
        let items = everywhere ? show.items : show.items.filter { $0.id == model.selectedItemID }
        let vocab = model.project.properties.shots
        for item in items {
            for row in show.shotRows(forItem: item.id) {
                let cam = show.camera(row.cue.cameraID)
                let camText = cam.map { "cam \($0.number)" } ?? "no camera"
                let details = row.cue.detailLine(vocab)
                out.append(Entry(id: "shot-\(row.id)", kind: .shot,
                                 title: "#\(row.number)  " + (row.cue.text.isEmpty ? (cam?.displayName ?? "Shot") : row.cue.text),
                                 detail: [camText.capitalized, details, everywhere ? item.title : ""].filter { !$0.isEmpty }.joined(separator: " · "),
                                 symbol: "video",
                                 search: "#\(row.number) \(camText) \(cam?.displayName ?? "") \(row.cue.text) \(row.cue.note) \(details) \(item.title)".lowercased()) {
                    model.selectedItemID = item.id
                    model.selectedShotIDs = [row.id]
                    model.scrollTarget = row.id.uuidString
                })
            }
        }
        func tool(_ title: String, _ detail: String, _ symbol: String, _ run: @escaping () -> Void) {
            out.append(Entry(id: "tool-\(title)", kind: .tool, title: title, detail: detail, symbol: symbol,
                             search: (title + " " + detail).lowercased(), run: run))
        }
        tool(model.isLive ? "Exit Live Mode" : "Enter Live Mode", "⌘L", "dot.radiowaves.left.and.right") { model.toggleLive() }
        if !model.isLive { tool("Go Live…", "Scene, mode, crew page, monitors · ⌥⌘L", "play.circle") { model.goLiveOpen = true } }
        tool("Pre-show Check", "⌥⌘K", "checklist") { model.preShowCheckOpen = true }
        tool("Device Status", "⌥⌘D", "antenna.radiowaves.left.and.right") { model.deviceStatusOpen = true }
        tool("Show Setup", "Switchers, tally, devices, monitors · ⌥⌘S", "gearshape") { model.switcherSetupOpen = true }
        tool("Cameras", "Numbers, names, operators · ⌥⌘C", "video") { model.cameraManagerOpen = true }
        tool("Trigger Routes", "OSC, MIDI, Art-Net in · ⌥⌘R", "bolt") { model.triggerRoutesOpen = true }
        tool("Camera Plot", "⌥⌘P", "map") { model.plotOpen = true }
        tool("Export", "Call sheets, camera script, EDL · ⇧⌘E", "square.and.arrow.up") { model.exportOpen = true }
        tool("Project Properties", "Shot lists, scene defaults, timecode · ⌥⌘,", "slider.horizontal.3") { model.projectPropertiesOpen = true }
        tool("Versions", "Saved copies of the script", "clock.arrow.circlepath") { model.versionsOpen = true }
        tool("Tour", "Compare nights", "map") { model.tourOpen = true }
        tool("New Song", "⌥⌘N", "music.note") { model.addSong() }
        tool("New Segment", "⌥⇧⌘N", "rectangle.split.3x1") { model.addSegment() }
        tool("Timeline", "⌘1", "slider.horizontal.below.rectangle") { model.editorMode = .timeline }
        tool("Timeline and List", "⌘2", "rectangle.split.1x2") { model.editorMode = .split }
        tool("List", "⌘3", "list.bullet") { model.editorMode = .list }
        tool("Keyboard Shortcuts", "⌘/", "keyboard") { KeyboardShortcutsView.show() }
        return out
    }
}
