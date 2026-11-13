import SwiftUI
import OnCueCore

/// Go Live… (⌥⌘L): everything about starting Live Mode on one screen. The scene to start on, the
/// switcher mode, and whether the crew page and the monitors start with it. ⌘L goes live straight
/// away with the same choices.
struct GoLiveSheet: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var itemID: UUID?
    @State private var mode: OutputMode = .display

    var body: some View {
        let main = show.switchers.first { $0.role == .main } ?? show.switchers.first
        let item = show.item(itemID)
        let shots = itemID.map { show.shotRows(forItem: $0) } ?? []
        let noCamera = shots.filter { $0.cue.cameraID == nil }.count
        VStack(alignment: .leading, spacing: Space.m) {
            Text("GO LIVE").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Form {
                Picker("Start on", selection: $itemID) {
                    ForEach(Array(show.items.enumerated()), id: \.element.id) { k, i in
                        Text("\(i.number.isEmpty ? "\(k + 1)" : i.number). \(i.title)").tag(Optional(i.id))
                    }
                }
                Picker("Switcher mode", selection: $mode) {
                    ForEach(OutputMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(modeHelp).font(.ocMeta).foregroundStyle(mode == .cut ? Gallery.amber : Gallery.faint)
                Toggle("Start the crew page", isOn: setting(\.liveStartsCrew))
                Toggle(show.settings.monitors.isEmpty ? "Open the operator monitors (none set up in Show Setup)"
                       : "Open the operator monitors (\(show.settings.monitors.count))", isOn: setting(\.liveOpensMonitors))
                    .disabled(show.settings.monitors.isEmpty)
            }
            VStack(alignment: .leading, spacing: 4) {
                fact("Switcher", main.map { "\($0.name)" + ($0.host.isEmpty ? "" : " · \($0.host)") + ($0.kind == .simulator ? " (nothing real is switched)" : "") } ?? "none set up", warn: main == nil)
                fact("Cameras", "\(show.cameras.count)", warn: show.cameras.isEmpty)
                fact("Shots in \(item?.title ?? "this scene")", noCamera == 0 ? "\(shots.count)" : "\(shots.count), \(noCamera) without a camera", warn: shots.isEmpty || noCamera > 0)
            }
            .padding(Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
            HStack {
                Button("Pre-show Check…") { dismiss(); DispatchQueue.main.async { model.preShowCheckOpen = true } }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Go Live") { go() }
                    .buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
                    .disabled(itemID == nil)
            }
        }
        .padding(Space.l)
        .frame(width: 520)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            itemID = model.selectedItemID ?? show.items.first?.id
            mode = model.lastLiveMode ?? .display
        }
    }

    private var modeHelp: String {
        switch mode {
        case .display: return "OnCue shows the calls and sends nothing to the switcher."
        case .preview: return "OnCue puts the next shot on preview; you cut."
        case .cut: return "OnCue cuts on the script once you press GO."
        }
    }

    private func setting(_ key: WritableKeyPath<ShowSettings, Bool>) -> Binding<Bool> {
        Binding(get: { show.settings[keyPath: key] },
                set: { v in model.edit("Live Mode Options") { $0.settings[keyPath: key] = v } })
    }

    private func fact(_ label: String, _ value: String, warn: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: warn ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(warn ? Gallery.amber : Gallery.next).font(.system(size: 11))
            Text(label).font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 150, alignment: .leading)
            Text(value).font(.ocMeta).foregroundStyle(Gallery.ink)
        }
    }

    private func go() {
        model.selectedItemID = itemID
        model.lastLiveMode = mode
        dismiss()
        DispatchQueue.main.async { if !model.isLive { model.enterLive() } }
    }
}
