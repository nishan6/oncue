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
            case .calls: callFields
            case .player: playerFields
            case .device: deviceFields
            default: EmptyView()
            }
            PropertyRow(label: kind == .lyrics ? "Lyric" : (kind == .notes ? "Note" : (kind == .calls ? "Call" : "Label"))) {
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

    // MARK: Cues (calls)

    @ViewBuilder private var callFields: some View {
        PropertyRow(label: "For") {
            Picker("For", selection: Binding(get: { cue.callRole }, set: { r in model.updateCue(cue.id, "Change Cue Role") { $0.callRole = r } })) {
                Text("Everyone").tag("")
                ForEach(model.project.properties.roles) { Text($0.name).tag($0.name) }
                if !cue.callRole.isEmpty, !model.project.properties.roles.contains(where: { $0.name == cue.callRole }) {
                    Text(cue.callRole).tag(cue.callRole)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
        }
    }

    // MARK: Device commands

    @ViewBuilder private var deviceFields: some View {
        let targets = show.deviceTargets
        let target = targets.first { $0.id == cue.sendTargetID }
        let send = cue.send ?? DeviceSend(kind: target?.kind.sendKinds.first ?? .text)
        PropertyRow(label: "Target") {
            Picker("Target", selection: Binding(get: { cue.sendTargetID }, set: { id in
                model.updateCue(cue.id, "Change Device Target") { c in
                    c.sendTargetID = id
                    let kinds = targets.first { $0.id == id }?.kind.sendKinds ?? [.text]
                    if c.send == nil || !kinds.contains(c.send!.kind) { c.send = DeviceSend(kind: kinds[0]) }
                    if let t = targets.first(where: { $0.id == id }), t.kind == .console,
                       let first = t.console.kind.actions.first, !t.console.kind.actions.contains(c.send!.console.kind) {
                        c.send!.console = ConsoleAction(kind: first)
                    }
                }
            })) {
                Text("Choose…").tag(UUID?.none)
                ForEach(targets) { Text("\($0.name) (\($0.kind.label))").tag(UUID?.some($0.id)) }
            }
            .labelsHidden().frame(maxWidth: 240)
        }
        if targets.isEmpty {
            Text("Add targets in Show Setup › Devices: a grandMA3 over MIDI, a projector on serial, Companion over HTTP…")
                .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
        }
        if let target {
            if target.kind.sendKinds.count > 1 {
                PropertyRow(label: "Send") {
                    Picker("Send", selection: Binding(get: { send.kind }, set: { k in setSend { $0.kind = k } })) {
                        ForEach(target.kind.sendKinds) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(maxWidth: 200)
                }
            }
            switch send.kind {
            case .midiNote, .midiCC, .midiProgram:
                PropertyRow(label: "Channel") { intField(send.channel, 1...16) { v in setSend { $0.channel = v } } }
                PropertyRow(label: send.kind == .midiProgram ? "Program" : (send.kind == .midiNote ? "Note" : "CC")) {
                    intField(send.number, send.kind == .midiProgram ? 1...128 : 0...127) { v in setSend { $0.number = v } }
                }
                if send.kind != .midiProgram {
                    PropertyRow(label: send.kind == .midiNote ? "Velocity" : "Value") { intField(send.value, 0...127) { v in setSend { $0.value = v } } }
                }
            case .msc:
                PropertyRow(label: "Command") {
                    Picker("", selection: Binding(get: { send.msc }, set: { v in setSend { $0.msc = v } })) {
                        ForEach(MSCCommand.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 120)
                }
                PropertyRow(label: "Cue") { textField("12.5", send.mscCue) { v in setSend { $0.mscCue = v } } }
                PropertyRow(label: "Cue list") { textField("optional", send.mscList) { v in setSend { $0.mscList = v } } }
                PropertyRow(label: "Device ID") { intField(send.mscDevice, 0...127) { v in setSend { $0.mscDevice = v } } }
            case .text:
                PropertyRow(label: "String") { textField("e.g. PLAY\\r or \\x02POW\\x03", send.text) { v in setSend { $0.text = v } } }
                Text("\\r \\n \\t and \\xHH work in the string. The target adds its line ending (\(target.lineEnding.label)).")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            case .http:
                PropertyRow(label: "Method") {
                    Picker("", selection: Binding(get: { send.method }, set: { v in setSend { $0.method = v } })) {
                        ForEach(HTTPMethod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 160)
                }
                PropertyRow(label: "Path") { textField("/api/location/1/0/0/press", send.path) { v in setSend { $0.path = v } } }
                if send.method != .get {
                    PropertyRow(label: "Body") { textField("optional", send.body) { v in setSend { $0.body = v } } }
                }
            case .console:
                let console = target.console.kind
                let a = send.console
                PropertyRow(label: "Action") {
                    Picker("", selection: Binding(get: { a.kind }, set: { v in setSend { $0.console.kind = v } })) {
                        ForEach(console.actions) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 220)
                }
                switch a.kind {
                case .goCue, .goNext:
                    PropertyRow(label: console == .grandMA2 ? "Executor" : (console == .avolites ? "Playback" : "Sequence")) { intField(a.list, 1...9999) { v in setSend { $0.console.list = v } } }
                    if a.kind == .goCue {
                        PropertyRow(label: "Cue") {
                            CommitField(placeholder: "12", value: String(format: "%g", a.number), font: .readout(13), width: 70) { text in
                                guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v >= 0 else { return false }
                                setSend { $0.console.number = v }
                                return true
                            }
                        }
                    }
                case .command:
                    PropertyRow(label: "Command") { textField("e.g. Go+ Sequence 5", a.text) { v in setSend { $0.console.text = v } } }
                case .scene, .column:
                    PropertyRow(label: a.kind == .scene ? "Scene" : "Column") { intField(Int(a.number), 0...9999) { v in setSend { $0.console.number = Double(v) } } }
                case .mute, .fader:
                    PropertyRow(label: "Channel") { intField(a.channel, 1...128) { v in setSend { $0.console.channel = v } } }
                    if a.kind == .mute {
                        PropertyRow(label: "State") {
                            Picker("", selection: Binding(get: { a.on }, set: { v in setSend { $0.console.on = v } })) {
                                Text("Mute").tag(true)
                                Text("Unmute").tag(false)
                            }
                            .labelsHidden().pickerStyle(.segmented).frame(width: 160)
                        }
                    } else {
                        PropertyRow(label: "Level dB") {
                            CommitField(placeholder: "0", value: String(format: "%g", a.level), font: .readout(13), width: 70) { text in
                                guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v <= 10 else { return false }
                                setSend { $0.console.level = v }
                                return true
                            }
                        }
                    }
                case .take, .takeOut, .cueGraphic:
                    PropertyRow(label: "Take ID") { intField(Int(a.number), 0...99999) { v in setSend { $0.console.number = Double(v) } } }
                    if a.kind != .takeOut {
                        PropertyRow(label: "Framebuffer") { intField(a.list, 1...16) { v in setSend { $0.console.list = v } } }
                        PropertyRow(label: "Layer") { intField(a.channel, -99...99) { v in setSend { $0.console.channel = v } } }
                    }
                case .clearLayer:
                    if console == .xpression {
                        PropertyRow(label: "Framebuffer") { intField(a.list, 1...16) { v in setSend { $0.console.list = v } } }
                    }
                    PropertyRow(label: "Layer") { intField(a.channel, 0...99) { v in setSend { $0.console.channel = v } } }
                case .playClip:
                    PropertyRow(label: "Layer") { intField(a.channel, 1...99) { v in setSend { $0.console.channel = v } } }
                    PropertyRow(label: "Clip") { intField(Int(a.number), 1...999) { v in setSend { $0.console.number = Double(v) } } }
                case .next:
                    EmptyView()
                }
            case .hyperDeck:
                PropertyRow(label: "Action") {
                    Picker("", selection: Binding(get: { send.hyperDeck }, set: { v in setSend { $0.hyperDeck = v } })) {
                        ForEach(HyperDeckAction.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 160)
                }
                if send.hyperDeck == .gotoClip {
                    PropertyRow(label: "Clip") { intField(send.clip, 1...9999) { v in setSend { $0.clip = v } } }
                }
                if send.hyperDeck == .record {
                    PropertyRow(label: "File name") { textField("Deck's own naming", send.recordName) { v in setSend { $0.recordName = v } } }
                }
            case .dmx:
                PropertyRow(label: "Channel") { intField(send.dmxChannel, 1...512) { v in setSend { $0.dmxChannel = v } } }
                PropertyRow(label: "Level") { intField(send.dmxLevel, 0...255) { v in setSend { $0.dmxLevel = v } } }
                PropertyRow(label: "Fade") {
                    CommitField(placeholder: "0", value: String(format: "%g", send.dmxFade), font: .readout(13), width: 60) { text in
                        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v >= 0, v <= 600 else { return false }
                        setSend { $0.dmxFade = v }
                        return true
                    }
                }
            }
            HStack {
                Button("Send Now") { model.engine?.sendDevice(send, target: target.id) }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(model.engine == nil)
                Text(target.simulated ? "Simulated target: nothing leaves this Mac." : (model.engine == nil ? "Send Now works in Live Mode." : ""))
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            }
        }
    }

    private func setSend(_ change: @escaping (inout DeviceSend) -> Void) {
        let kind = show.deviceTargets.first { $0.id == cue.sendTargetID }?.kind.sendKinds.first ?? .text
        model.updateCue(cue.id, "Change Device Command") { c in
            var s = c.send ?? DeviceSend(kind: kind)
            change(&s)
            c.send = s
        }
    }

    private func intField(_ value: Int, _ range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        CommitField(placeholder: "\(range.lowerBound)", value: String(value), font: .readout(13), width: 64) { text in
            guard let v = Int(text.trimmingCharacters(in: .whitespaces)), range.contains(v) else { return false }
            set(v)
            return true
        }
    }

    private func textField(_ placeholder: String, _ value: String, set: @escaping (String) -> Void) -> some View {
        CommitField(placeholder: placeholder, value: value, font: .readout(13)) { text in
            set(text)
            return true
        }
    }

    // MARK: Media Player Control

    @ViewBuilder private var playerFields: some View {
        let action = cue.playerAction ?? .play
        PropertyRow(label: "Action") {
            Picker("Action", selection: Binding(get: { action }, set: { a in model.updateCue(cue.id, "Change Player Action") { $0.playerAction = a } })) {
                ForEach(PlayerAction.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
        }
        PropertyRow(label: "Player") {
            CommitField(placeholder: "e.g. MP1", value: cue.playerName, font: .ocBody) { text in
                model.updateCue(cue.id, "Change Player") { $0.playerName = text.trimmingCharacters(in: .whitespaces) }
                return true
            }
        }
        if action == .load || action == .play {
            PropertyRow(label: "Clip") {
                CommitField(placeholder: "Clip name or number", value: cue.clip, font: .ocBody) { text in
                    model.updateCue(cue.id, "Change Clip") { $0.clip = text.trimmingCharacters(in: .whitespaces) }
                    return true
                }
            }
        }
        if action == .jump {
            PropertyRow(label: "To") {
                CommitField(placeholder: "0:00", value: TimeFormat.mmss(cue.jumpTo), font: .readout(13), width: 70) { text in
                    guard let v = TimeFormat.parseSeconds(text), v >= 0 else { return false }
                    model.updateCue(cue.id, "Change Jump Time") { $0.jumpTo = v }
                    return true
                }
            }
        }
        Text("Scripted and shown in Live Mode. Not sent to a player yet: player connections come with hardware testing.")
            .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
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
        case .calls: return "e.g. LX 14 GO"
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
        case .calls: return "Cue"
        case .player: return "Player cue"
        case .device: return "Device command"
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
        case .calls:
            let call = cue.text.isEmpty ? "Cue" : cue.text
            return cue.callRole.isEmpty ? call : "\(cue.callRole.uppercased()) · \(call)"
        case .device:
            let target = deviceTargets.first { $0.id == cue.sendTargetID }?.name ?? "No target"
            return "\(target): \(cue.send?.summary ?? "nothing set")" + suffix
        case .player:
            let action = cue.playerAction ?? .play
            var parts = [cue.playerName.isEmpty ? "Player" : cue.playerName, action.short]
            if (action == .load || action == .play), !cue.clip.isEmpty { parts.append(cue.clip) }
            if action == .jump { parts.append(TimeFormat.mmss(cue.jumpTo)) }
            return parts.joined(separator: " ") + suffix
        default:
            return cue.text.isEmpty ? "Note" : cue.text
        }
    }
}
