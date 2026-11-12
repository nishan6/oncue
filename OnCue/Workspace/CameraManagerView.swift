import SwiftUI
import OnCueCore

/// Swatch that opens the camera colour choices.
struct CameraColorButton: View {
    let camera: Camera
    @ObservedObject var model: WorkspaceModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(camera.swiftUIColor)
                .frame(width: 34, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Colour of camera \(camera.number)'s shots")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Camera \(camera.number) colour").font(.umd(12)).foregroundStyle(Gallery.dim)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 6), spacing: 6) {
                    ForEach(CameraPalette.colors, id: \.self) { hex in
                        Button {
                            model.updateCamera(camera.id, "Change Camera Colour") { $0.color = hex }
                            open = false
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 22)
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.white, lineWidth: camera.resolvedColor == hex ? 2 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Use the default for camera \(camera.number)") {
                    model.updateCamera(camera.id, "Change Camera Colour") { $0.color = "" }
                    open = false
                }
                .disabled(camera.color.isEmpty)
            }
            .padding(14)
        }
    }
}

/// Sheet for the production's cameras: colour, number, name, operator for this show, switcher input.
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
                TableColumn("Colour") { cam in
                    CameraColorButton(camera: cam, model: model)
                }
                .width(60)
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
        .frame(minWidth: 780, minHeight: 460)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private func deleteSelection() {
        for id in selection { model.deleteCamera(id) }
        selection = []
    }
}
