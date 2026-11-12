import SwiftUI
import AppKit
import OnCueCore

/// New song or segment: asks for its number, title, artist, status and start timecode every time.
struct NewSceneSheet: View {
    let kind: ItemKind
    let project: Project
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var number = ""
    @State private var artist = ""
    @State private var status: SceneStatus = .unset
    @State private var start: SceneNumbering.StartChoice = .projectDefault
    @State private var loaded = false

    private var previous: RundownItem? {
        let at = show.itemIndex(model.selectedItemID)
        return at.map { show.items[$0] } ?? show.items.last
    }

    private var startTimecode: String? {
        SceneNumbering.startTimecode(start, number: number, previous: previous,
                                     defaults: project.properties.sceneDefaults, rate: project.frameRate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(kind == .song ? "NEW SONG" : "NEW SEGMENT").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Form {
                TextField("Name", text: $title)
                TextField("Artist", text: $artist)
                TextField("Number", text: $number)
                Picker("Status", selection: $status) {
                    ForEach(SceneStatus.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Starting timecode", selection: $start) {
                    ForEach(SceneNumbering.StartChoice.allCases) { Text($0.label).tag($0) }
                }
                LabeledContent("") {
                    if let tc = startTimecode {
                        Text(tc).font(.readout(13, weight: .semibold)).foregroundStyle(Gallery.ink)
                    } else {
                        Text(start == .hourPerNumber ? "Needs a whole scene number from 0 to 23"
                             : "The previous scene has no starting timecode")
                            .font(.ocMeta).foregroundStyle(Gallery.amber)
                    }
                }
                LabeledContent("Duration") {
                    Text(TimeFormat.hms(Double(project.properties.sceneDefaults.durationSeconds)))
                        .font(.readout(12)).foregroundStyle(Gallery.dim)
                }
            }
            HStack {
                Text("Tracks, length and chase come from Project Properties › Scene defaults.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Add") {
                    model.addScene(kind: kind, title: title.trimmingCharacters(in: .whitespaces),
                                   number: number.trimmingCharacters(in: .whitespaces),
                                   artist: artist.trimmingCharacters(in: .whitespaces),
                                   status: status, startTimecode: startTimecode)
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || startTimecode == nil)
            }
        }
        .padding(Space.l)
        .frame(width: 520)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            number = model.proposedNumber()
            artist = project.artist
            loaded = true
        }
    }
}

/// An older single-file show was opened. It is never saved over: OnCue asks whether it becomes a
/// new project or a playlist in an existing project, keeps a copy of the original in the backup
/// folder, and leaves the original file as it was.
struct LegacyShowSheet: View {
    let show: Show
    let originalURL: URL?
    @ObservedObject var model: WorkspaceModel
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.openDocument) private var openDocument
    @State private var target: URL?
    @State private var error: String?

    private var projects: [LibraryEntry] {
        library.entries.filter { !$0.isLegacy && $0.problem == nil && !library.isOpen($0.url) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("OLDER SHOW FILE").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Text("“\(show.name)” was made before projects and playlists. Bring it in as a new project, or add it to an existing project as a playlist. The original file stays exactly as it is, and a copy goes to the backup folder first.")
                .font(.ocBody).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            if library.folder == nil {
                Text("Choose a projects folder first (in the Project Library).").font(.ocMeta).foregroundStyle(Gallery.amber)
            }
            HStack {
                Button("Open as a New Project") { bringIn(into: nil) }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(library.folder == nil)
                Spacer()
            }
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            Text("Or add it as a playlist to:").font(.ocMeta).foregroundStyle(Gallery.dim)
            List(projects, selection: $target) { entry in
                HStack {
                    Text(entry.name).font(.ocBody)
                    Spacer()
                    Text("\(entry.sceneCount) scenes · \(entry.frameRate.label)").font(.ocMeta).foregroundStyle(Gallery.faint)
                }
                .tag(entry.url)
            }
            .frame(height: 160)
            .scrollContentBackground(.hidden)
            .background(Gallery.well)
            if let error {
                Text(error).font(.ocMeta).foregroundStyle(Gallery.amber)
            }
            HStack {
                Button("Close Without Opening") { closeWindow() }.buttonStyle(QuietButtonStyle())
                Spacer()
                Button("Add as Playlist") { if let target { bringIn(into: target) } }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(target == nil)
            }
        }
        .padding(Space.l)
        .frame(width: 560)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear { library.refresh() }
    }

    private func bringIn(into existing: URL?) {
        do {
            keepOriginal()
            let url: URL
            if let existing {
                guard case .project(var p) = try ProjectPackage.read(at: existing) else {
                    throw ShowFileError.invalidContent("that file is not a project")
                }
                p.saveVersion(name: "Before adding “\(show.name)”", automatic: true, reason: "Before migration")
                _ = p.addPlaylist(from: show)
                try ProjectPackage.write(p, to: existing)
                url = existing
            } else {
                guard let folder = library.folder else { return }
                url = try ProjectLibrary.create(Project(migrating: show), in: folder)
            }
            library.refresh()
            Task {
                try? await openDocument(at: url)
                closeWindow()
            }
        } catch {
            self.error = "That didn't work: \(error.localizedDescription)"
        }
    }

    /// A copy of the original file in the backup folder, before anything is made from it.
    private func keepOriginal() {
        guard let originalURL else { return }
        let dir = LibraryModel.backupRoot.appendingPathComponent("Older shows", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: ".")
        let copy = dir.appendingPathComponent("\(originalURL.deletingPathExtension().lastPathComponent) \(stamp).oncue")
        try? FileManager.default.copyItem(at: originalURL, to: copy)
    }

    private func closeWindow() {
        let doc = NSDocumentController.shared.documents.first { $0.fileURL == originalURL }
        doc?.close()
    }
}
