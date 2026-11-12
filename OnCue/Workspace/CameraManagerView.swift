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
                    Text("Cameras").font(.ocTitle).foregroundStyle(Gallery.ink)
                    Text("Numbers are what you call on comms. Colours, names and operators can change for every show.")
                        .font(.ocMeta)
                        .foregroundStyle(Gallery.dim)
                }
                Spacer()
            }
            .padding(Space.l)

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
                TableColumn("Switcher") { cam in
                    Picker("Switcher", selection: Binding(get: { cam.switcherID ?? show.mainOutput?.switcherID },
                                                          set: { id in model.updateCamera(cam.id, "Change Camera Switcher") { $0.switcherID = id } })) {
                        ForEach(show.switchers) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden()
                }
                .width(140)
                TableColumn("Input") { cam in
                    CommitField(placeholder: "Input", value: "\(cam.input)", font: .readout(13), width: 50) { text in
                        guard let v = Int(text), v > 0 else { return false }
                        model.updateCamera(cam.id, "Change Switcher Input") { $0.input = v }
                        return true
                    }
                    .help("The input this camera arrives on, on its switcher.")
                }
                .width(56)
                TableColumn("Also on") { cam in
                    ExtraInputsButton(show: show, camera: cam, model: model)
                }
                .width(120)
                TableColumn("Shots") { cam in
                    Text("\(show.shotCount(forCamera: cam.id))")
                        .font(.readout(12))
                        .foregroundStyle(Gallery.dim)
                }
                .width(54)
            }
            .onDeleteCommand { deleteSelection() }

            HStack(spacing: Space.s) {
                Button { model.addCamera() } label: { Label("New Camera", systemImage: "plus") }
                    .buttonStyle(QuietButtonStyle())
                Button(role: .destructive) { deleteSelection() } label: { Label("Delete", systemImage: "trash") }
                    .buttonStyle(QuietButtonStyle(destructive: true))
                    .disabled(selection.isEmpty)
                Spacer()
                Text("Deleting a camera keeps its shots; they show as \"no camera\".")
                    .font(.ocMeta)
                    .foregroundStyle(Gallery.faint)
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.m)
        }
        .frame(minWidth: 780, minHeight: 460)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .tint(Gallery.selection)
    }

    private func deleteSelection() {
        for id in selection { model.deleteCamera(id) }
        selection = []
    }
}


/// The same camera on other switchers (split or DA'd to separate outputs).
struct ExtraInputsButton: View {
    let show: Show
    let camera: Camera
    @ObservedObject var model: WorkspaceModel
    @State private var open = false

    var body: some View {
        let others = show.switchers.filter { $0.id != (camera.switcherID ?? show.mainOutput?.switcherID) }
        Button {
            open = true
        } label: {
            Text(camera.extraInputs.isEmpty ? (others.isEmpty ? "–" : "Add…")
                 : camera.extraInputs.compactMap { e in show.switcher(e.switcherID).map { "\($0.name) \(e.input)" } }.joined(separator: ", "))
                .font(.ocMeta)
                .foregroundStyle(camera.extraInputs.isEmpty ? Gallery.faint : Gallery.ink)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(others.isEmpty)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Camera \(camera.number) on other switchers").sectionLabel()
                ForEach(others) { sw in
                    HStack {
                        Text(sw.name).font(.ocBody).frame(width: 160, alignment: .leading)
                        CommitField(placeholder: "Input", value: camera.extraInputs.first { $0.switcherID == sw.id }.map { "\($0.input)" } ?? "",
                                    font: .readout(13), width: 60) { text in
                            let t = text.trimmingCharacters(in: .whitespaces)
                            let v = t.isEmpty ? 0 : (Int(t) ?? -1)
                            guard v >= 0 else { return false }
                            model.edit("Change Camera Input") { $0.setExtraInput(camera: camera.id, switcherID: sw.id, input: v) }
                            return true
                        }
                    }
                }
                Text("Leave empty if the camera does not reach that switcher.").font(.ocMeta).foregroundStyle(Gallery.faint)
            }
            .padding(Space.l)
        }
    }
}
