import SwiftUI
import OnCueCore

/// Production › Versions: named snapshots kept inside the show file.
struct VersionsView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmRestore: ShowVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Versions").font(.ocTitle).foregroundStyle(Gallery.ink)
                Text("Snapshots kept inside this show file. OnCue also keeps one each time you enter Live Mode. macOS keeps its own history under File › Revert To.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)

            HStack(spacing: Space.s) {
                TextField("Name this version, e.g. After rehearsal", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Button("Save Version", action: save)
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.m)

            Rectangle().fill(Gallery.hairline).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if show.versions.isEmpty {
                        Text("No versions yet.").font(.ocBody).foregroundStyle(Gallery.faint).padding(.vertical, Space.l)
                    }
                    ForEach(show.versions.reversed()) { v in
                        HStack(spacing: Space.s) {
                            Image(systemName: v.automatic ? "clock.arrow.circlepath" : "bookmark")
                                .foregroundStyle(v.automatic ? Gallery.faint : Gallery.selection)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(v.name).font(.ocLabel).foregroundStyle(Gallery.ink)
                                Text(v.date.formatted(date: .abbreviated, time: .shortened)).font(.ocMeta).foregroundStyle(Gallery.faint)
                            }
                            Spacer()
                            Button("Restore…") { confirmRestore = v }.buttonStyle(QuietButtonStyle())
                            IconButton(symbol: "trash", help: "Delete this version") {
                                model.edit("Delete Version") { $0.deleteVersion(v.id) }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, Space.l)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)
        }
        .frame(width: 560, height: 520)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .confirmationDialog("Restore “\(confirmRestore?.name ?? "")”?", isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } })) {
            Button("Restore") {
                guard let v = confirmRestore else { return }
                do {
                    try checkRestorable(v)
                    model.edit("Restore Version") { s in
                        s.saveVersion(name: "Before restoring \(v.name)", automatic: true)
                        try? s.restoreVersion(v.id)
                    }
                } catch {
                    model.errorMessage = "That version couldn't be read: \(error.localizedDescription)"
                }
                confirmRestore = nil
            }
        } message: {
            Text("The show goes back to how it was. The current state is kept as a version first, and Edit › Undo also brings it back.")
        }
    }

    private func checkRestorable(_ v: ShowVersion) throws { _ = try show.show(in: v) }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        model.edit("Save Version") { $0.saveVersion(name: n) }
        name = ""
    }
}
