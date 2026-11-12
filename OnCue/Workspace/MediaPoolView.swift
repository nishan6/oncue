import SwiftUI
import AppKit
import AVFoundation
import OnCueCore

/// The Media rail panel: the project's Media Pool. Files are linked where they are, never copied.
struct MediaPoolPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @State private var kind: MediaKind?
    @State private var search = ""
    @State private var selection: UUID?
    @State private var clearOpen = false
    @State private var missingCache: Set<UUID> = []

    private var pool: [MediaAsset] { model.project.media }

    private var visible: [MediaAsset] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return pool.filter { a in
            (kind == nil || a.kind == kind) && (q.isEmpty || a.name.lowercased().contains(q) || a.fileName.lowercased().contains(q))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let project = model.project
        VStack(alignment: .leading, spacing: 0) {
            DeckPanelTitle(title: "Media") {
                Button { importFiles() } label: { Label("Import", systemImage: "plus") }
                    .buttonStyle(QuietButtonStyle())
                    .help("Add files to the pool. They stay where they are on disk.")
            }
            HStack(spacing: Space.s) {
                Menu {
                    Button("All kinds") { kind = nil }
                    Divider()
                    ForEach(MediaKind.allCases) { k in Button(k.label) { kind = k } }
                } label: { Text(kind?.label ?? "All kinds").font(.ocMeta) }
                .menuStyle(.borderlessButton).fixedSize()
                TextField("Search", text: $search).textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, Space.l).padding(.bottom, Space.s)

            if pool.isEmpty {
                Text("No media yet. Import song audio, click tracks, PGM recordings, player clips and stills. Files are linked where they are, not copied.")
                    .font(.ocMeta).foregroundStyle(Deck.faint).padding(Space.l)
                Spacer()
            } else {
                List(visible, selection: $selection) { asset in
                    let usage = project.mediaUsage(asset)
                    let missing = missingCache.contains(asset.id)
                    HStack(spacing: Space.s) {
                        Image(systemName: missing ? "exclamationmark.triangle.fill" : asset.kind.symbol)
                            .foregroundStyle(missing ? Deck.warn : Deck.dim).frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(asset.name).font(.ocBody).foregroundStyle(Deck.ink).lineLimit(1)
                            Text(detail(asset, usage: usage, missing: missing)).font(.ocMeta)
                                .foregroundStyle(missing ? Deck.warn : Deck.faint).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if usage.isEmpty {
                            Text("unused").font(.ocTag).foregroundStyle(Deck.faint)
                        }
                    }
                    .tag(asset.id)
                    .contextMenu { menu(asset, usage: usage) }
                    .help(asset.path)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            footer
        }
        .onAppear {
            // Songs' audio and recordings loaded before the pool existed join it.
            let p = model.project
            if p.playlists.flatMap(\.items).contains(where: { m in m.media.map { med in !p.media.contains { $0.path == med.path } } ?? false }) {
                model.editProject("Add Song Media to Pool") { $0.collectItemMedia() }
            }
            refreshMissing()
        }
        .onChange(of: pool) { _, _ in refreshMissing() }
        .sheet(isPresented: $clearOpen) { ClearUnusedSheet(assets: project.unusedMedia, model: model) }
    }

    private func detail(_ a: MediaAsset, usage: [MediaUsage], missing: Bool) -> String {
        var parts = [a.kind.label]
        if let d = a.duration { parts.append(TimeFormat.mmss(d)) }
        if missing { parts.append("missing") }
        else if !usage.isEmpty { parts.append(Set(usage.map(\.itemTitle)).sorted().joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func menu(_ asset: MediaAsset, usage: [MediaUsage]) -> some View {
        Menu("Kind") {
            ForEach(MediaKind.allCases) { k in
                Button(k.label) { model.editProject("Change Media Kind") { p in
                    if let i = p.media.firstIndex(where: { $0.id == asset.id }) { p.media[i].kind = k }
                } }
            }
        }
        Button("Relink…") { relink(asset) }
        if let url = asset.resolvedURL() {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        Divider()
        Button("Remove from Pool") {
            model.editProject("Remove Media") { $0.media.removeAll { $0.id == asset.id } }
        }
        .disabled(!usage.isEmpty)
    }

    private var footer: some View {
        HStack(spacing: Space.s) {
            Text("\(pool.count) \(pool.count == 1 ? "file" : "files")").font(.ocMeta).foregroundStyle(Deck.faint)
            if !missingCache.isEmpty {
                Button("Relink \(missingCache.count) Missing…") { relinkFolder() }
                    .buttonStyle(QuietButtonStyle())
                    .help("Choose a folder: missing files with the same names are found in it and its subfolders")
            }
            Spacer()
            Button("Clear Unused…") { clearOpen = true }
                .buttonStyle(QuietButtonStyle())
                .disabled(model.project.unusedMedia.isEmpty)
        }
        .padding(Space.m)
    }

    private func refreshMissing() {
        missingCache = Set(pool.filter { $0.resolvedURL() == nil }.map(\.id))
    }

    // MARK: Actions

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add to Pool"
        panel.message = "Song audio, click tracks, PGM recordings, player clips and stills. They stay where they are."
        guard panel.runModal() == .OK else { return }
        var files: [(path: String, bookmark: Data?, kind: MediaKind, duration: Double?)] = []
        var skipped: [String] = []
        for url in panel.urls {
            guard let kind = MediaKind.guess(for: url) else { skipped.append(url.lastPathComponent); continue }
            let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            var duration: Double?
            if kind != .still {
                let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
                if seconds.isFinite, seconds > 0 { duration = seconds }
            }
            files.append((url.path, bookmark, kind, duration))
        }
        if !files.isEmpty { model.editProject("Import Media") { $0.importMedia(files) } }
        if !skipped.isEmpty {
            model.errorMessage = "Not added (not audio, video or an image OnCue knows): " + skipped.joined(separator: ", ")
        }
    }

    private func relink(_ asset: MediaAsset) {
        let panel = NSOpenPanel()
        panel.prompt = "Relink"
        panel.message = "Where is “\(asset.fileName)” now?"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        model.editProject("Relink Media") { $0.relink(asset.id, to: url.path, bookmark: bookmark) }
    }

    private func relinkFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Search Here"
        panel.message = "Missing files with the same names are looked for in this folder and its subfolders."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        var candidates: [String] = []
        if let e = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let url as URL in e {
                candidates.append(url.path)
                if candidates.count > 200_000 { break }
            }
        }
        let missing = pool.filter { missingCache.contains($0.id) }
        let found = MediaRelink.matches(missing: missing, candidates: candidates)
        guard !found.isEmpty else {
            model.errorMessage = "None of the \(missing.count) missing files were found in \(folder.lastPathComponent)."
            return
        }
        model.editProject("Relink Media") { p in
            for (id, path) in found {
                let bookmark = try? URL(fileURLWithPath: path).bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                p.relink(id, to: path, bookmark: bookmark)
            }
        }
        let left = missing.count - found.count
        if left > 0 {
            model.errorMessage = "Relinked \(found.count). \(left) still missing: not found, or more than one file with that name (relink those one by one)."
        }
    }
}

/// Clear Unused: lists the files, then removes them from the pool and moves them to the Trash.
struct ClearUnusedSheet: View {
    let assets: [MediaAsset]
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("CLEAR UNUSED MEDIA").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Text("Nothing in this project uses these \(assets.count) \(assets.count == 1 ? "file" : "files"). They are removed from the pool and moved to the Trash, where you can still get them back. OnCue can't see other projects: if another project uses one of these files, it will show it as missing.")
                .font(.ocBody).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(assets) { a in
                        HStack {
                            Image(systemName: a.kind.symbol).foregroundStyle(Gallery.dim)
                            Text(a.fileName).font(.ocBody)
                            Spacer()
                            Text(a.resolvedURL() == nil ? "already missing" : (a.path as NSString).deletingLastPathComponent)
                                .font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1).truncationMode(.head)
                        }
                    }
                }
            }
            .frame(height: 200)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Remove and Move to Trash") { clear() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
            }
        }
        .padding(Space.l)
        .frame(width: 560)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private func clear() {
        var failed: [String] = []
        var cleared: Set<UUID> = []
        for a in assets {
            guard let url = a.resolvedURL() else { cleared.insert(a.id); continue }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                cleared.insert(a.id)
            } catch {
                failed.append(a.fileName)
            }
        }
        let ids = cleared
        model.editProject("Clear Unused Media") { $0.media.removeAll { ids.contains($0.id) } }
        if !failed.isEmpty { model.errorMessage = "Couldn't move to the Trash, so kept in the pool: " + failed.joined(separator: ", ") }
        dismiss()
    }
}
