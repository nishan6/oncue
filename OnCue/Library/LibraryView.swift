import SwiftUI
import OnCueCore

/// The window OnCue opens on: every project in the projects folder, with pins, an Archive tab,
/// search, and the operations on each project.
struct LibraryView: View {
    @ObservedObject var library: LibraryModel
    @Environment(\.openDocument) private var openDocument
    @State private var newProjectOpen = false
    @State private var renaming: LibraryEntry?
    @State private var trashing: LibraryEntry?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            if library.folder == nil {
                firstLaunch
            } else {
                columnsHeader
                list
            }
        }
        .frame(minWidth: 860, minHeight: 480)
        .background(Gallery.base)
        .preferredColorScheme(.dark)
        .tint(Gallery.selection)
        .onAppear { library.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in library.refresh() }
        .sheet(isPresented: $newProjectOpen) {
            NewProjectSheet(library: library) { url in open(url) }
        }
        .sheet(item: $renaming) { entry in
            RenameProjectSheet(entry: entry) { library.rename(entry, to: $0) }
        }
        .confirmationDialog("Move “\(trashing?.name ?? "")” to the Trash?",
                            isPresented: Binding(get: { trashing != nil }, set: { if !$0 { trashing = nil } })) {
            Button("Move to Trash", role: .destructive) {
                if let t = trashing { library.moveToTrash(t) }
                trashing = nil
            }
        } message: {
            Text("You can get it back from the Trash. Its copies in the OnCue Backups folder stay.")
        }
        .alert("Can't do that", isPresented: Binding(get: { library.errorMessage != nil },
                                                      set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROJECTS").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
                if let folder = library.folder {
                    Text(folder.path).font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            if library.folder != nil {
                Picker("", selection: $library.showArchived) {
                    Text("Projects").tag(false)
                    Text("Archive (\(library.archivedCount))").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                TextField("Search name, artist, venue", text: $library.search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Change Folder…") { library.chooseFolder() }
                    .buttonStyle(QuietButtonStyle())
                Button { newProjectOpen = true } label: { Label("New Project", systemImage: "plus") }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        .padding(.horizontal, Space.l)
        .frame(height: 64)
        .background(Gallery.panel)
    }

    private var firstLaunch: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "folder.badge.plus").font(.system(size: 36, weight: .light)).foregroundStyle(Gallery.faint)
            Text("Where should OnCue keep your projects?").font(.ocTitle).foregroundStyle(Gallery.ink)
            Text("Pick any folder, on this Mac or an external drive. Each project is one .oncue file in it, and backups go to an OnCue Backups folder beside them. You can change this later.")
                .font(.ocBody).foregroundStyle(Gallery.dim).multilineTextAlignment(.center).frame(maxWidth: 460)
            Button("Choose Folder…") { library.chooseFolder() }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var columnsHeader: some View {
        HStack(spacing: Space.m) {
            Text("").frame(width: 16)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Artist").frame(width: 140, alignment: .leading)
            Text("Venue").frame(width: 130, alignment: .leading)
            Text("Show date").frame(width: 90, alignment: .leading)
            Text("Rate").frame(width: 64, alignment: .leading)
            Text("Scenes").frame(width: 52, alignment: .trailing)
            Text("Last edited").frame(width: 110, alignment: .trailing)
            Text("").frame(width: 24)
        }
        .font(.ocMeta)
        .foregroundStyle(Gallery.faint)
        .padding(.horizontal, Space.l + Space.s)
        .frame(height: 28)
    }

    private var list: some View {
        Group {
            if library.visible.isEmpty {
                VStack(spacing: Space.s) {
                    Text(library.showArchived ? "No archived projects." : (library.search.isEmpty ? "No projects yet." : "No projects match."))
                        .font(.ocBody).foregroundStyle(Gallery.faint)
                    if !library.showArchived && library.search.isEmpty {
                        Button("New Project…") { newProjectOpen = true }.buttonStyle(QuietButtonStyle(prominent: true))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(library.visible) { entry in
                    LibraryRow(entry: entry, isOpen: library.isOpen(entry.url))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { open(entry.url) }
                        .contextMenu { menu(entry) }
                        .overlay(alignment: .trailing) {
                            Menu { menu(entry) } label: { Image(systemName: "ellipsis.circle") }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .frame(width: 24)
                        }
                        .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder private func menu(_ entry: LibraryEntry) -> some View {
        Button("Open") { open(entry.url) }
        Divider()
        Button(entry.pinned ? "Unpin" : "Pin") { library.setPinned(entry, !entry.pinned) }
        if !entry.isLegacy {
            Button("Rename…") { renaming = entry }
            Button("Duplicate") { library.duplicate(entry) }
        }
        Button(entry.archived ? "Restore from Archive" : "Archive") { library.setArchived(entry, !entry.archived) }
        Divider()
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
        Divider()
        Button("Move to Trash…", role: .destructive) { trashing = entry }
    }

    private func open(_ url: URL) {
        Task {
            do {
                try await openDocument(at: url)
            } catch {
                library.errorMessage = "Opening didn't work: \(error.localizedDescription)"
            }
        }
    }
}

private struct LibraryRow: View {
    let entry: LibraryEntry
    let isOpen: Bool

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: entry.pinned ? "pin.fill" : "doc")
                .font(.system(size: 11))
                .foregroundStyle(entry.pinned ? Gallery.selection : Gallery.faint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.ocBodyStrong).foregroundStyle(Gallery.ink).lineLimit(1)
                    if entry.isLegacy { badge("Older show", Gallery.amber) }
                    if isOpen { badge("Open", Gallery.next) }
                }
                if let problem = entry.problem {
                    Text(problem).font(.ocMeta).foregroundStyle(Gallery.amber).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.artist.isEmpty ? "–" : entry.artist).frame(width: 140, alignment: .leading).lineLimit(1)
            Text(entry.venue.isEmpty ? "–" : entry.venue).frame(width: 130, alignment: .leading).lineLimit(1)
            Text(entry.showDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–").frame(width: 90, alignment: .leading)
            Text(entry.frameRate.label).font(.readout(12)).frame(width: 64, alignment: .leading)
            Text("\(entry.sceneCount)").font(.readout(12)).frame(width: 52, alignment: .trailing)
            Text(entry.editedAt.formatted(.relative(presentation: .named))).frame(width: 110, alignment: .trailing).lineLimit(1)
            Color.clear.frame(width: 24)
        }
        .font(.ocBody)
        .foregroundStyle(Gallery.dim)
        .padding(.vertical, 6)
        .help(entry.url.path)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.6), lineWidth: 1))
    }
}

/// New project: name (required), artist, venue, show date and frame rate.
struct NewProjectSheet: View {
    @ObservedObject var library: LibraryModel
    let created: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var artist = ""
    @State private var venue = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var rate: FrameRate = .r25

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("NEW PROJECT").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Form {
                TextField("Name", text: $name)
                TextField("Artist", text: $artist)
                TextField("Venue", text: $venue)
                HStack {
                    Toggle("Show date", isOn: $hasDate)
                    if hasDate { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }
                }
                LabeledContent("Frame rate") { FrameRatePicker(rate: $rate) }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Create") {
                    if let url = library.create(name: name, artist: artist, venue: venue, showDate: hasDate ? date : nil, rate: rate) {
                        dismiss()
                        created(url)
                    }
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Space.l)
        .frame(width: 460)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }
}

struct RenameProjectSheet: View {
    let entry: LibraryEntry
    let rename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("RENAME PROJECT").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder).onAppear { name = entry.name }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Rename") { rename(name); dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Space.l)
        .frame(width: 380)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }
}
