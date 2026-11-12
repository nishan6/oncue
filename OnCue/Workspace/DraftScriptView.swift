import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnCueCore

/// Where a draft script comes from.
enum DraftSource: Identifiable {
    case log(SwitchLog)
    case edl(text: String, name: String)

    var id: String {
        switch self {
        case .log(let l): return "log-" + l.fileName
        case .edl(_, let name): return "edl-" + name
        }
    }

    /// Production › Draft Script from Switch Log…
    static func chooseLog(model: WorkspaceModel) {
        SwitchLogPicker.choose { model.draftSource = .log($0) } failure: { model.errorMessage = $0 }
    }

    /// Production › Draft Script from EDL…
    static func chooseEDL(model: WorkspaceModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "edl") ?? .plainText, .plainText]
        panel.prompt = "Draft Script"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            model.errorMessage = "\(url.lastPathComponent) couldn't be read."
            return
        }
        model.draftSource = .edl(text: text, name: url.deletingPathExtension().lastPathComponent)
    }
}

/// Turns a switch log or an EDL into new songs and segments next to the originals.
struct DraftScriptView: View {
    let show: Show
    let source: DraftSource
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<UUID> = []
    @State private var label = "draft"
    @State private var fps = 25
    @State private var started = false

    private var plans: [DraftPlan] {
        switch source {
        case .log(let log): return show.draftPlans(from: log)
        case .edl(let text, let name): return show.draftPlan(fromEDL: text, fps: fps, title: name).map { [$0] } ?? []
        }
    }

    var body: some View {
        let plans = self.plans
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Draft script").font(.ocTitle).foregroundStyle(Gallery.ink)
                Text(subtitle).font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.l)

            if case .edl = source {
                PropertyRow(label: "Frame rate") {
                    Picker("Frame rate", selection: $fps) {
                        ForEach([24, 25, 30, 50, 60], id: \.self) { Text("\($0) fps").tag($0) }
                    }
                    .labelsHidden().frame(width: 110)
                }
                .padding(.horizontal, Space.l)
            } else {
                PropertyRow(label: "Name drafts") {
                    TextField("draft", text: $label).textFieldStyle(.roundedBorder).frame(width: 200)
                }
                .padding(.horizontal, Space.l)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if plans.isEmpty {
                        Text(emptyText).font(.ocBody).foregroundStyle(Gallery.faint).padding(.vertical, Space.l)
                    }
                    ForEach(plans) { plan in
                        let on = chosen.contains(plan.id)
                        Button {
                            if on { chosen.remove(plan.id) } else { chosen.insert(plan.id) }
                        } label: {
                            HStack(spacing: Space.s) {
                                Image(systemName: on ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(on ? Gallery.selection : Gallery.faint)
                                Text(plan.title).font(.ocBody).foregroundStyle(Gallery.ink)
                                Spacer()
                                Text("\(plan.cuts.count) shots").font(.ocMeta).foregroundStyle(Gallery.dim)
                                let unknown = plan.cuts.filter { $0.cameraID == nil }.count
                                if unknown > 0 {
                                    Text("\(unknown) without a camera").font(.ocMeta).foregroundStyle(Gallery.amber)
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.l)
            }

            HStack {
                Text("Drafts are added next to the originals. Nothing is overwritten.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button(chosen.count == 1 ? "Add 1 Draft" : "Add \(chosen.count) Drafts") {
                    let selected = plans.filter { chosen.contains($0.id) }
                    let name = label.trimmingCharacters(in: .whitespaces).isEmpty ? "draft" : label
                    var ids: [UUID] = []
                    model.edit("Draft Script") { ids = $0.applyDrafts(selected, label: name) }
                    if let first = ids.first { model.selectedItemID = first }
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty)
            }
            .padding(Space.l)
        }
        .frame(width: 560, height: 480)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !started else { return }
            started = true
            chosen = Set(plans.map(\.id))
            if case .log(let log) = source, !log.night.isEmpty { label = "draft, \(log.night)" }
            fps = Int(show.settings.ltcFPS.rounded())
            if ![24, 25, 30, 50, 60].contains(fps) { fps = 25 }
        }
        .onChange(of: fps) { _, _ in chosen = Set(self.plans.map(\.id)) }
    }

    private var subtitle: String {
        switch source {
        case .log(let log): return "From the switch log of \(log.nightName): the program cuts of each song or segment become its shots."
        case .edl(_, let name): return "From \(name): each video event becomes a shot. Cameras come from reel names like CAM3 or clip names starting with the camera number."
        }
    }

    private var emptyText: String {
        switch source {
        case .log: return "This log has no program cuts for songs in this show."
        case .edl: return "No video events found in this EDL."
        }
    }
}
