import SwiftUI
import OnCueCore

/// Sheet for the production's cameras: number, name, operator for this show, switcher input.
struct CameraManagerView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cameras").font(.title(20)).foregroundStyle(Gallery.ink)
                    Text("Numbers are what you call on comms. Names and operators can change for every show.")
                        .font(.system(size: 12))
                        .foregroundStyle(Gallery.dim)
                }
                Spacer()
            }
            .padding(18)

            Table(show.sortedCameras, selection: $selection) {
                TableColumn("No.") { cam in
                    CommitField(placeholder: "No.", value: "\(cam.number)", font: .readout(13, weight: .semibold), width: 44) { text in
                        model.renumberCamera(cam.id, text: text)
                    }
                }
                .width(56)
                TableColumn("Name") { cam in
                    CommitField(placeholder: "Cam \(cam.number)", value: cam.name, font: .system(size: 13, weight: .medium)) { text in
                        model.updateCamera(cam.id, "Rename Camera") { $0.name = text }
                        return true
                    }
                }
                TableColumn("Operator") { cam in
                    CommitField(placeholder: "Who operates it", value: cam.operatorName, font: .system(size: 13)) { text in
                        model.updateCamera(cam.id, "Change Operator") { $0.operatorName = text }
                        return true
                    }
                }
                TableColumn("Switcher input") { cam in
                    CommitField(placeholder: "Input", value: "\(cam.input)", font: .readout(13), width: 50) { text in
                        guard let v = Int(text), v > 0 else { return false }
                        model.updateCamera(cam.id, "Change Switcher Input") { $0.input = v }
                        return true
                    }
                    .help("The switcher input this camera arrives on. Used later when OnCue drives the switcher.")
                }
                .width(110)
                TableColumn("Shots") { cam in
                    Text("\(show.shotCount(forCamera: cam.id))")
                        .font(.readout(12))
                        .foregroundStyle(Gallery.dim)
                }
                .width(54)
            }
            .onDeleteCommand { deleteSelection() }

            HStack(spacing: 10) {
                Button { model.addCamera() } label: { Label("New Camera", systemImage: "plus") }
                Button(role: .destructive) { deleteSelection() } label: { Label("Delete", systemImage: "minus") }
                    .disabled(selection.isEmpty)
                Spacer()
                Text("Deleting a camera keeps its shots; they show as \"no camera\".")
                    .font(.system(size: 11))
                    .foregroundStyle(Gallery.faint)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private func deleteSelection() {
        for id in selection { model.deleteCamera(id) }
        selection = []
    }
}
