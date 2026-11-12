import SwiftUI
import OnCueCore

/// Project › Versions: snapshots kept inside the project. Restoring never loses anything: the
/// current state is kept first, and the restore is itself a new version.
struct VersionsView: View {
    let project: Project
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmRestore: ProjectVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("VERSIONS").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
                Text("Kept inside this project. OnCue also keeps one on every ⌘S, before Live Mode, before big changes and at the first edit of each day. macOS keeps its own history under File › Revert To.")
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
                    if project.versions.isEmpty {
                        Text("No versions yet.").font(.ocBody).foregroundStyle(Gallery.faint).padding(.vertical, Space.l)
                    }
                    ForEach(project.versions.reversed()) { v in
                        HStack(spacing: Space.s) {
                            Image(systemName: v.automatic ? "clock.arrow.circlepath" : "bookmark")
                                .foregroundStyle(v.automatic ? Gallery.faint : Gallery.selection)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(v.name).font(.ocLabel).foregroundStyle(Gallery.ink)
                                MetaLine(parts: [v.date.formatted(date: .abbreviated, time: .shortened),
                                                 v.automatic ? "automatic" : "named",
                                                 v.author])
                            }
                            Spacer()
                            Button("Restore…") { confirmRestore = v }.buttonStyle(QuietButtonStyle())
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, Space.l)
            }

            HStack {
                Text("\(project.versions.count) versions").font(.ocMeta).foregroundStyle(Gallery.faint)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)
        }
        .frame(width: 580, height: 540)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .confirmationDialog("Restore “\(confirmRestore?.name ?? "")”?",
                            isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } })) {
            Button("Restore") {
                guard let v = confirmRestore else { return }
                do {
                    _ = try project.project(in: v)
                    model.editProject("Restore Version") { p in try? p.restoreVersion(v.id) }
                } catch {
                    model.errorMessage = "That version couldn't be read: \(error.localizedDescription)"
                }
                confirmRestore = nil
            }
        } message: {
            Text("The project goes back to how it was. The current state is kept as a version first, the restore is recorded as a new version, and every later version stays.")
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        model.editProject("Save Version") { $0.saveVersion(name: n) }
        name = ""
    }
}
