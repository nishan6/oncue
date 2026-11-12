import SwiftUI
import OnCueCore

/// Sheet for the production's main switcher: type, address and M/E, and which cameras have inputs.
struct SwitcherSetupView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let config = show.switcher(show.mainOutput?.switcherID) ?? show.switchers.first
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Switcher").font(.ocTitle).foregroundStyle(Gallery.ink)
                Text("The switcher OnCue cuts in Live Mode. Cameras reach it on the inputs set under Cameras.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
            .padding(Space.l)

            if let config {
                VStack(alignment: .leading, spacing: Space.m) {
                    PropertyRow(label: "Name") {
                        CommitField(placeholder: "Main switcher", value: config.name, font: .ocBody) { text in
                            let t = text.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return false }
                            model.updateMainSwitcher("Rename Switcher") { $0.name = t }
                            return true
                        }
                    }
                    PropertyRow(label: "Type") {
                        Picker("Type", selection: Binding(get: { config.kind },
                                                          set: { k in model.updateMainSwitcher("Change Switcher Type") { $0.kind = k } })) {
                            ForEach(SwitcherKind.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                    switch config.kind {
                    case .atem:
                        PropertyRow(label: "IP address") {
                            CommitField(placeholder: "192.168.10.240", value: config.host, font: .readout(13), width: 180) { text in
                                let t = text.trimmingCharacters(in: .whitespaces)
                                guard !t.isEmpty else { return false }
                                model.updateMainSwitcher("Change Switcher Address") { $0.host = t }
                                return true
                            }
                        }
                        PropertyRow(label: "M/E") {
                            Picker("M/E", selection: Binding(get: { config.me },
                                                             set: { v in model.updateMainSwitcher("Change M/E") { $0.me = v } })) {
                                ForEach(0..<4) { Text("M/E \($0 + 1)").tag($0) }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 120)
                        }
                        note("OnCue talks to the ATEM directly on UDP port 9910, like ATEM Software Control. The Mac and the switcher must be on the same network.")
                    case .companion:
                        note("OnCue presses Companion buttons for preview, cut and auto. Companion's address is set per Mac in Settings. Companion reports no tally back, so manual cuts cannot pause automation. The per-input button mapping is not editable in this version yet.")
                    case .simulator:
                        note("A switcher inside OnCue for rehearsing at home: it behaves like an ATEM (cuts are instant, mixes take a second). Nothing leaves this Mac.")
                    }
                }
                .padding(.horizontal, Space.l)

                let missing = show.camerasWithoutInput
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Camera inputs").sectionLabel()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: Space.s, alignment: .leading)], alignment: .leading, spacing: Space.s) {
                        ForEach(show.sortedCameras) { cam in
                            HStack(spacing: 6) {
                                CameraChip(camera: cam, size: 18)
                                Text(cam.displayName).font(.ocMeta).foregroundStyle(Gallery.dim).lineLimit(1)
                                Spacer(minLength: 0)
                                Text(cam.input > 0 ? "In \(cam.input)" : "No input")
                                    .font(.readout(11)).foregroundStyle(cam.input > 0 ? Gallery.ink : Gallery.amber)
                            }
                        }
                    }
                    if !missing.isEmpty {
                        Label("\(missing.count) \(missing.count == 1 ? "camera has" : "cameras have") no switcher input: OnCue skips their shots.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.ocMeta).foregroundStyle(Gallery.amber)
                    }
                }
                .padding(Space.l)
            }

            Spacer(minLength: 0)
            HStack {
                Button("Cameras…") { dismiss(); DispatchQueue.main.async { model.cameraManagerOpen = true } }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.m)
        }
        .frame(width: 560, height: 520)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .tint(Gallery.selection)
        .onAppear { model.ensureMainSwitcher() }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
    }
}
