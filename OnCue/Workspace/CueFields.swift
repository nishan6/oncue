import SwiftUI
import OnCueCore

/// Editing fields for a lyric, note, FX, control, OSC or PTZ cue. Used in the timeline's quick
/// editor and in the inspector. Pickers apply at once; text applies on Return or when focus leaves.
struct CueFields: View {
    let kind: TrackKind
    let cue: Cue
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            switch kind {
            case .fx: fxFields
            case .control: controlFields
            case .osc: oscFields
            case .ptz: ptzFields
            default: EmptyView()
            }
            PropertyRow(label: kind == .lyrics ? "Lyric" : (kind == .notes ? "Note" : "Label")) {
                CommitField(placeholder: placeholder, value: cue.text, font: .ocBody) { text in
                    model.updateCue(cue.id, "Edit Cue") { $0.text = text }
                    return true
                }
            }
        }
    }

    // MARK: FX

    @ViewBuilder private var fxFields: some View {
        let action = cue.fxAction ?? .macro
        PropertyRow(label: "Action") {
            Picker("Action", selection: Binding(get: { action }, set: { a in model.updateCue(cue.id, "Change FX Action") { $0.fxAction = a } })) {
                ForEach(FXAction.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
        }
        if action != .fadeToBlack {
            PropertyRow(label: indexLabel(action)) {
                number(value: cue.fxIndex + 1, min: 1) { v in model.updateCue(cue.id, "Change FX Number") { $0.fxIndex = v - 1 } }
            }
        }
        if action == .auxSource {
            PropertyRow(label: "Input") {
                number(value: cue.fxValue, min: 1) { v in model.updateCue(cue.id, "Change Aux Input") { $0.fxValue = v } }
            }
        }
        PropertyRow(label: "Switcher") {
            Text(show.switcher(show.item(model.selectedItemID)?.tracks.first { $0.cues.contains { $0.id == cue.id } }?.switcherID)?.name
                 ?? show.switcher(show.mainOutput?.switcherID)?.name ?? "Main switcher")
                .font(.ocMeta).foregroundStyle(Gallery.dim).padding(.leading, 5)
        }
    }

    private func indexLabel(_ action: FXAction) -> String {
        switch action {
        case .macro: return "Macro"
        case .dskOn, .dskOff, .dskAuto: return "DSK"
        case .keyOn, .keyOff: return "Key"
        case .auxSource: return "Aux"
        case .fadeToBlack: return ""
        }
    }

    // MARK: Control

    @ViewBuilder private var controlFields: some View {
        let action = cue.controlAction ?? .loadNext
        PropertyRow(label: "Action") {
            Picker("Action", selection: Binding(get: { action }, set: { a in model.updateCue(cue.id, "Change Control Action") { $0.controlAction = a } })) {
                ForEach(ControlAction.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
        }
        if action == .jump {
            PropertyRow(label: "Go to") {
                Picker("Item", selection: Binding(get: { cue.jumpItemID }, set: { id in model.updateCue(cue.id, "Change Jump") { $0.jumpItemID = id } })) {
                    Text("Choose…").tag(UUID?.none)
                    ForEach(show.items) { Text($0.title).tag(UUID?.some($0.id)) }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }
        }
        Text(controlHelp(action)).font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
    }

    private func controlHelp(_ action: ControlAction) -> String {
        switch action {
        case .loadNext: return "When reached, the next song or segment loads and stands by."
        case .stop: return "When reached, OnCue stops following the timing source."
        case .wait: return "When reached, OnCue holds until you press GO."
        case .jump: return "When reached, the chosen song or segment loads and stands by."
        }
    }

    // MARK: OSC

    @ViewBuilder private var oscFields: some View {
        PropertyRow(label: "Target") {
            Picker("Target", selection: Binding(get: { cue.oscTargetID }, set: { id in model.updateCue(cue.id, "Change OSC Target") { $0.oscTargetID = id } })) {
                Text("No target").tag(UUID?.none)
                ForEach(show.oscTargets) { Text("\($0.name) (\($0.host):\($0.port))").tag(UUID?.some($0.id)) }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
        }
        PropertyRow(label: "Address") {
            CommitField(placeholder: "/composition/columns/1/connect", value: cue.oscAddress, font: .readout(12)) { text in
                let t = text.trimmingCharacters(in: .whitespaces)
                guard t.isEmpty || t.hasPrefix("/") else { return false }
                model.updateCue(cue.id, "Change OSC Address") { $0.oscAddress = t }
                return true
            }
        }
        PropertyRow(label: "Arguments") {
            CommitField(placeholder: "1  0.5  \"text\"", value: cue.oscArgs, font: .readout(12)) { text in
                model.updateCue(cue.id, "Change OSC Arguments") { $0.oscArgs = text }
                return true
            }
        }
        if show.oscTargets.isEmpty {
            Text("Add OSC targets under Production > Show Setup.").font(.ocMeta).foregroundStyle(Gallery.amber)
        }
    }

    // MARK: PTZ

    @ViewBuilder private var ptzFields: some View {
        PropertyRow(label: "Camera") {
            Picker("Camera", selection: Binding(get: { cue.ptzCameraID }, set: { id in model.updateCue(cue.id, "Change PTZ Camera") { $0.ptzCameraID = id } })) {
                Text("Choose…").tag(UUID?.none)
                ForEach(show.ptzCameras) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
        }
        PropertyRow(label: "Preset") {
            number(value: cue.ptzPreset, min: 1) { v in model.updateCue(cue.id, "Change PTZ Preset") { $0.ptzPreset = v } }
        }
        if show.ptzCameras.isEmpty {
            Text("Add PTZ cameras under Production > Show Setup.").font(.ocMeta).foregroundStyle(Gallery.amber)
        }
    }

    // MARK: Helpers

    private func number(value: Int, min: Int, apply: @escaping (Int) -> Void) -> some View {
        CommitField(placeholder: "\(min)", value: "\(value)", font: .readout(13), width: 60) { text in
            guard let v = Int(text.trimmingCharacters(in: .whitespaces)), v >= min else { return false }
            apply(v)
            return true
        }
    }

    private var placeholder: String {
        switch kind {
        case .lyrics: return "Lyric line"
        case .fx: return "e.g. band name lower third"
        case .notes: return "Note for the gallery"
        default: return "Optional label"
        }
    }
}

extension TrackKind {
    /// Display name of a cue on this track.
    var cueTitle: String {
        switch self {
        case .lyrics: return "Lyric"
        case .fx: return "FX cue"
        case .control: return "Control cue"
        case .osc: return "OSC cue"
        case .ptz: return "PTZ cue"
        case .shots: return "Shot"
        case .notes: return "Note"
        }
    }
}

extension Show {
    /// One-line description of a cue for timeline blocks.
    func cueLabel(_ cue: Cue, kind: TrackKind) -> String {
        let suffix = cue.text.isEmpty ? "" : ": \(cue.text)"
        switch kind {
        case .fx:
            let action = cue.fxAction ?? .macro
            let number: String
            switch action {
            case .fadeToBlack: number = ""
            case .auxSource: number = " \(cue.fxIndex + 1) ← \(cue.fxValue)"
            default: number = " \(cue.fxIndex + 1)"
            }
            return action.label + number + suffix
        case .control:
            let action = cue.controlAction ?? .loadNext
            if action == .jump, let target = item(cue.jumpItemID) { return "Jump to \(target.title)" + suffix }
            return action.label + suffix
        case .osc:
            let target = oscTarget(cue.oscTargetID)?.name ?? "No target"
            return "\(target) \(cue.oscAddress.isEmpty ? "(no address)" : cue.oscAddress)"
        case .ptz:
            let cam = ptz(cue.ptzCameraID)?.name ?? "No camera"
            return "\(cam) · preset \(cue.ptzPreset)" + suffix
        case .lyrics:
            return cue.text.isEmpty ? "Lyric" : cue.text
        default:
            return cue.text.isEmpty ? "Note" : cue.text
        }
    }
}
