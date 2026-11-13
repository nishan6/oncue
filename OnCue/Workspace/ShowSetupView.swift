import SwiftUI
import OnCueCore

/// Production > Show Setup: switchers (main, sub-switchers, separate outputs), outputs,
/// Companion buttons, OSC targets and PTZ cameras. Described once per show.
struct ShowSetupView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab

    init(show: Show, model: WorkspaceModel, tab: Tab = .switchers) {
        self.show = show
        self.model = model
        _tab = State(initialValue: tab)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case switchers = "Switchers", outputs = "Outputs", tally = "Tally", osc = "OSC", ptz = "PTZ", monitors = "Monitors", controls = "Controls"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show setup").font(.ocTitle).foregroundStyle(Gallery.ink)
                    Text("Switchers, outputs and the systems OnCue sends cues to. Saved with the show.")
                        .font(.ocMeta).foregroundStyle(Gallery.dim)
                }
                Spacer()
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(Space.l)
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    switch tab {
                    case .switchers: switchersTab
                    case .outputs: outputsTab
                    case .tally: TallySetup(show: show, model: model)
                    case .osc: oscTab
                    case .ptz: ptzTab
                    case .monitors: MonitorsSetup(show: show, model: model)
                    case .controls: ControlsSetup(show: show, model: model)
                    }
                }
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(Gallery.hairline).frame(height: 1)
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
        .frame(width: 760, height: 620)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .tint(Gallery.selection)
        .onAppear { model.ensureMainSwitcher() }
    }

    // MARK: Switchers

    @ViewBuilder private var switchersTab: some View {
        let mainID = show.mainOutput?.switcherID
        ForEach(show.switchers) { config in
            SwitcherCard(show: show, config: config, isMain: config.id == mainID, model: model)
        }
        HStack(spacing: Space.s) {
            Button { model.edit("Add Sub-switcher") { $0.addSwitcher(name: "Sub-switcher", kind: .atem, role: .sub) } } label: {
                Label("Sub-switcher", systemImage: "plus")
            }
            .help("A switcher whose program feeds an input of another switcher")
            Button { model.edit("Add Output Switcher") { $0.addSwitcher(name: "Output switcher", kind: .atem, role: .output) } } label: {
                Label("Switcher for a separate output", systemImage: "plus")
            }
            .help("A switcher cutting its own output (LED wall, IMAG, broadcast) at the same time")
            if let main = mainID, !show.switchers.contains(where: { $0.mirrorOf == main }) {
                Button {
                    model.edit("Add Parallel Switcher") { $0.addParallelSwitcher(mirroring: main) }
                } label: {
                    Label("Parallel switcher (backup)", systemImage: "plus")
                }
                .help("A second switcher running in parallel: it gets every command the main one gets, and OnCue reads program and tally from it if the main one is lost")
            }
        }
        .buttonStyle(QuietButtonStyle())
    }

    // MARK: Outputs

    @ViewBuilder private var outputsTab: some View {
        Text("The first output is the main one: its shots are NOW and NEXT. Every other output has its own shot track, or mirrors the main cut.")
            .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
        ForEach(Array(show.outputs.enumerated()), id: \.element.id) { k, output in
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    CommitField(placeholder: "Output name", value: output.name, font: .ocHeading) { text in
                        let t = text.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return false }
                        model.edit("Rename Output") { $0.updateOutput(output.id) { $0.name = t } }
                        return true
                    }
                    if k == 0 { Pill(text: "MAIN", color: Gallery.selection) }
                    Spacer()
                    if k > 0 {
                        Button(role: .destructive) { model.edit("Delete Output") { $0.deleteOutput(output.id) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(QuietButtonStyle(destructive: true))
                    }
                }
                PropertyRow(label: "Switcher") {
                    Picker("Switcher", selection: Binding(get: { output.switcherID },
                                                          set: { id in model.edit("Change Output Switcher") { $0.updateOutput(output.id) { $0.switcherID = id } } })) {
                        ForEach(show.switchers) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden().frame(maxWidth: 240)
                }
                PropertyRow(label: "Bus") {
                    HStack {
                        Picker("Bus", selection: Binding(get: { output.bus },
                                                         set: { b in model.edit("Change Output Bus") { $0.updateOutput(output.id) { $0.bus = b } } })) {
                            Text("Program").tag(BusKind.program)
                            Text("Aux").tag(BusKind.aux)
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 160)
                        if output.bus == .aux {
                            Text("Aux").font(.ocMeta).foregroundStyle(Gallery.dim)
                            CommitField(placeholder: "1", value: "\(output.auxIndex + 1)", font: .readout(13), width: 40) { text in
                                guard let v = Int(text), v >= 1 else { return false }
                                model.edit("Change Aux") { $0.updateOutput(output.id) { $0.auxIndex = v - 1 } }
                                return true
                            }
                        }
                    }
                }
                if k > 0 {
                    Toggle("Mirror the main cut instead of its own track", isOn: Binding(get: { output.mirrorMain },
                        set: { v in model.edit("Change Mirror") { $0.updateOutput(output.id) { $0.mirrorMain = v } } }))
                        .toggleStyle(.checkbox)
                        .font(.ocMeta)
                }
            }
            .padding(Space.m)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        }
        Button {
            let name = "Output \(show.outputs.count + 1)"
            model.edit("Add Output") { $0.addOutput(name: name, switcherID: nil) }
        } label: {
            Label("Output", systemImage: "plus")
        }
        .buttonStyle(QuietButtonStyle())
    }

    // MARK: OSC

    @ViewBuilder private var oscTab: some View {
        Text("Systems that receive OSC cues from the script: Resolume, Disguise, CasparCG, lighting desks. OSC is sent over UDP from this Mac.")
            .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
        ForEach(show.oscTargets) { target in
            HStack(spacing: Space.s) {
                CommitField(placeholder: "Name", value: target.name, font: .ocBodyStrong, width: 180) { text in
                    guard !text.isEmpty else { return false }
                    model.edit("Rename OSC Target") { $0.updateOSCTarget(target.id) { $0.name = text } }
                    return true
                }
                CommitField(placeholder: "IP address", value: target.host, font: .readout(13), width: 150) { text in
                    guard !text.isEmpty else { return false }
                    model.edit("Change OSC Address") { $0.updateOSCTarget(target.id) { $0.host = text } }
                    return true
                }
                Text("Port").font(.ocMeta).foregroundStyle(Gallery.dim)
                CommitField(placeholder: "7000", value: "\(target.port)", font: .readout(13), width: 60) { text in
                    guard let v = Int(text), (1...65535).contains(v) else { return false }
                    model.edit("Change OSC Port") { $0.updateOSCTarget(target.id) { $0.port = v } }
                    return true
                }
                Spacer()
                IconButton(symbol: "trash", help: "Delete this target") { model.edit("Delete OSC Target") { $0.deleteOSCTarget(target.id) } }
            }
            .padding(Space.s)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        }
        Button {
            let name = "OSC target \(show.oscTargets.count + 1)"
            model.edit("Add OSC Target") { $0.addOSCTarget(name: name) }
        } label: {
            Label("OSC target", systemImage: "plus")
        }
        .buttonStyle(QuietButtonStyle())
    }

    // MARK: PTZ

    @ViewBuilder private var ptzTab: some View {
        Text("PTZ cameras whose presets the script recalls. Presets are numbered from 1.")
            .font(.ocMeta).foregroundStyle(Gallery.dim)
        ForEach(show.ptzCameras) { cam in
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    CommitField(placeholder: "Name", value: cam.name, font: .ocHeading, width: 200) { text in
                        guard !text.isEmpty else { return false }
                        model.edit("Rename PTZ Camera") { $0.updatePTZCamera(cam.id) { $0.name = text } }
                        return true
                    }
                    Spacer()
                    IconButton(symbol: "trash", help: "Delete this PTZ camera") { model.edit("Delete PTZ Camera") { $0.deletePTZCamera(cam.id) } }
                }
                PropertyRow(label: "Control") {
                    Picker("Protocol", selection: Binding(get: { cam.proto }, set: { p in model.edit("Change PTZ Protocol") { show in
                        show.updatePTZCamera(cam.id) { c in
                            c.proto = p
                            if p == .viscaIP { c.port = 52381 } else if p == .viscaTCP { c.port = 5678 } else if p == .panasonic { c.port = 80 }
                        }
                    } })) {
                        ForEach(PTZProtocol.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(maxWidth: 300)
                }
                switch cam.proto {
                case .panasonic, .viscaIP, .viscaTCP:
                    PropertyRow(label: "Address") {
                        HStack {
                            CommitField(placeholder: "192.168.0.10", value: cam.host, font: .readout(13), width: 150) { text in
                                guard !text.isEmpty else { return false }
                                model.edit("Change PTZ Address") { $0.updatePTZCamera(cam.id) { $0.host = text } }
                                return true
                            }
                            if cam.proto != .panasonic {
                                Text("Port").font(.ocMeta).foregroundStyle(Gallery.dim)
                                CommitField(placeholder: "52381", value: "\(cam.port)", font: .readout(13), width: 70) { text in
                                    guard let v = Int(text), (1...65535).contains(v) else { return false }
                                    model.edit("Change PTZ Port") { $0.updatePTZCamera(cam.id) { $0.port = v } }
                                    return true
                                }
                            }
                        }
                    }
                case .atemMacro:
                    PropertyRow(label: "Macros") {
                        HStack {
                            Text("Preset 1 runs macro").font(.ocMeta).foregroundStyle(Gallery.dim)
                            CommitField(placeholder: "1", value: "\(cam.macroBase + 1)", font: .readout(13), width: 50) { text in
                                guard let v = Int(text), v >= 1 else { return false }
                                model.edit("Change PTZ Macros") { $0.updatePTZCamera(cam.id) { $0.macroBase = v - 1 } }
                                return true
                            }
                            Picker("Switcher", selection: Binding(get: { cam.switcherID }, set: { id in model.edit("Change PTZ Switcher") { $0.updatePTZCamera(cam.id) { $0.switcherID = id } } })) {
                                Text("Main switcher").tag(UUID?.none)
                                ForEach(show.switchers) { Text($0.name).tag(UUID?.some($0.id)) }
                            }
                            .labelsHidden().frame(width: 160)
                        }
                    }
                case .companion:
                    PropertyRow(label: "Buttons") {
                        CompanionButtonField(button: cam.companionStart, version: .v3) { b in
                            model.edit("Change PTZ Buttons") { $0.updatePTZCamera(cam.id) { $0.companionStart = b } }
                        }
                    }
                    Text("Preset 1 presses this button; later presets continue along the row.").font(.ocMeta).foregroundStyle(Gallery.faint)
                }
            }
            .padding(Space.m)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        }
        Button {
            let name = "PTZ \(show.ptzCameras.count + 1)"
            model.edit("Add PTZ Camera") { $0.addPTZCamera(name: name) }
        } label: {
            Label("PTZ camera", systemImage: "plus")
        }
        .buttonStyle(QuietButtonStyle())
    }
}

/// One switcher: type, address, role, and for sub-switchers where they feed.
struct SwitcherCard: View {
    let show: Show
    let config: SwitcherConfig
    let isMain: Bool
    @ObservedObject var model: WorkspaceModel
    @State private var companionOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                CommitField(placeholder: "Switcher name", value: config.name, font: .ocHeading, width: 240) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    update("Rename Switcher") { $0.name = t }
                    return true
                }
                Pill(text: isMain ? "MAIN" : (config.mirrorOf != nil ? "PARALLEL" : (config.role == .sub ? "SUB" : "OUTPUT")),
                     color: isMain ? Gallery.selection : Gallery.dim)
                Spacer()
                if !isMain {
                    IconButton(symbol: "trash", help: "Delete this switcher") {
                        model.edit("Delete Switcher") { $0.deleteSwitcher(config.id) }
                    }
                }
            }
            PropertyRow(label: "Type") {
                Picker("Type", selection: Binding(get: { config.kind }, set: { k in update("Change Switcher Type") { $0.kind = k } })) {
                    ForEach(SwitcherKind.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().frame(maxWidth: 260)
            }
            switch config.kind {
            case .atem:
                PropertyRow(label: "IP address") {
                    HStack {
                        CommitField(placeholder: "192.168.10.240", value: config.host, font: .readout(13), width: 170) { text in
                            let t = text.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return false }
                            update("Change Switcher Address") { $0.host = t }
                            return true
                        }
                        Picker("M/E", selection: Binding(get: { config.me }, set: { v in update("Change M/E") { $0.me = v } })) {
                            ForEach(0..<4) { Text("M/E \($0 + 1)").tag($0) }
                        }
                        .labelsHidden().frame(width: 100)
                    }
                }
            case .companion:
                PropertyRow(label: "Buttons") {
                    Button("Map Companion buttons…") { companionOpen = true }
                        .buttonStyle(QuietButtonStyle())
                }
                Text("Companion's address is set per Mac in Settings. Companion reports no tally back, so manual cuts on it cannot pause automation.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
            case .simulator:
                Text("A switcher inside OnCue for rehearsing: cuts are instant, mixes take a second. Nothing leaves this Mac.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            }
            if let mirrorOf = config.mirrorOf {
                PropertyRow(label: "Mirrors") {
                    Picker("Mirrors", selection: Binding(get: { Optional(mirrorOf) }, set: { id in update("Change Parallel Switcher") { $0.mirrorOf = id } })) {
                        ForEach(show.switchers.filter { $0.id != config.id && $0.mirrorOf == nil }) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden().frame(width: 220)
                }
                Text("Gets every command the switcher it mirrors gets, on the same inputs. Wire its program to your router or backup record.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
            }
            if show.switchers.contains(where: { $0.mirrorOf == config.id }) {
                PropertyRow(label: "If lost") {
                    HStack {
                        Picker("Failover", selection: Binding(get: { config.failover }, set: { v in update("Change Failover") { $0.failover = v } })) {
                            ForEach(FailoverPolicy.allCases) { Text("Fail over \($0.label.lowercased())").tag($0) }
                        }
                        .labelsHidden().frame(width: 220)
                        Text("after").font(.ocMeta).foregroundStyle(Gallery.dim)
                        CommitField(placeholder: "2", value: String(format: "%g", config.failoverTimeout), font: .readout(13), width: 50) { text in
                            guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v >= 0.2, v <= 60 else { return false }
                            update("Change Failover Time") { $0.failoverTimeout = v }
                            return true
                        }
                        Text("s without contact").font(.ocMeta).foregroundStyle(Gallery.dim)
                    }
                }
            }
            if config.role == .sub && !isMain {
                PropertyRow(label: "Feeds") {
                    HStack {
                        Picker("Feeds", selection: Binding(get: { config.parentID }, set: { id in update("Change Feed") { $0.parentID = id } })) {
                            Text("Nothing").tag(UUID?.none)
                            ForEach(show.switchers.filter { $0.id != config.id }) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                        .labelsHidden().frame(width: 200)
                        Text("on input").font(.ocMeta).foregroundStyle(Gallery.dim)
                        CommitField(placeholder: "10", value: config.feedInput > 0 ? "\(config.feedInput)" : "", font: .readout(13), width: 50) { text in
                            guard let v = Int(text), v > 0 else { return false }
                            update("Change Feed Input") { $0.feedInput = v }
                            return true
                        }
                    }
                }
            }
            let cams = show.sortedCameras.filter { ($0.switcherID ?? show.mainOutput?.switcherID) == (config.mirrorOf ?? config.id) }
            Text(cams.isEmpty ? "No cameras on this switcher" : "Cameras: " + cams.map { "\($0.number) (in \($0.input))" }.joined(separator: ", "))
                .font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(2)
        }
        .padding(Space.m)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        .sheet(isPresented: $companionOpen) {
            CompanionMappingView(show: show, config: config, model: model)
        }
    }

    private func update(_ action: String, _ change: @escaping (inout SwitcherConfig) -> Void) {
        model.edit(action) { $0.updateSwitcher(config.id) { change(&$0) } }
    }
}

/// Companion buttons per switcher input (preview, program) plus Cut and Auto.
struct CompanionMappingView: View {
    let show: Show
    let config: SwitcherConfig
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let version = CompanionVersion(rawValue: MachineProfileStore().profile.companionVersion) ?? .v3
        let current = show.switcher(config.id) ?? config
        let inputs = show.sortedCameras.filter { ($0.switcherID ?? show.mainOutput?.switcherID) == config.id }.map(\.input).filter { $0 > 0 }
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Companion buttons · \(current.name)").font(.ocTitle).foregroundStyle(Gallery.ink)
                Text(version == .v3 ? "Page / row / column of each button in Companion 3." : "Page / bank of each button in Companion 2.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
            .padding(Space.l)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack {
                        Text("Cut").font(.ocLabel).frame(width: 90, alignment: .leading)
                        CompanionButtonField(button: current.companion.cut, version: version) { b in
                            model.edit("Map Cut") { $0.updateSwitcher(config.id) { $0.companion.cut = b } }
                        }
                    }
                    HStack {
                        Text("Auto").font(.ocLabel).frame(width: 90, alignment: .leading)
                        CompanionButtonField(button: current.companion.auto, version: version) { b in
                            model.edit("Map Auto") { $0.updateSwitcher(config.id) { $0.companion.auto = b } }
                        }
                    }
                    Rectangle().fill(Gallery.hairline).frame(height: 1).padding(.vertical, Space.xs)
                    ForEach(inputs, id: \.self) { input in
                        let buttons = current.companion.buttons(for: input) ?? CompanionInputButtons(input: input)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input \(input)").font(.ocLabel).foregroundStyle(Gallery.ink)
                            HStack {
                                Text("Preview").font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 90, alignment: .leading)
                                CompanionButtonField(button: buttons.preview, version: version) { b in
                                    model.edit("Map Preview Button") { $0.updateCompanionButtons(switcherID: config.id, input: input) { $0.preview = b } }
                                }
                            }
                            HStack {
                                Text("Program").font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 90, alignment: .leading)
                                CompanionButtonField(button: buttons.program, version: version) { b in
                                    model.edit("Map Program Button") { $0.updateCompanionButtons(switcherID: config.id, input: input) { $0.program = b } }
                                }
                            }
                        }
                    }
                    if inputs.isEmpty {
                        Text("No cameras are on this switcher yet. Assign cameras under Cameras.").font(.ocMeta).foregroundStyle(Gallery.faint)
                    }
                }
                .padding(Space.l)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }
            .padding(Space.m)
        }
        .frame(width: 560, height: 560)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }
}

/// A Companion button address: on/off plus page and row/column (v3) or bank (v2).
struct CompanionButtonField: View {
    let button: CompanionButton
    let version: CompanionVersion
    let apply: (CompanionButton) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(get: { button.enabled }, set: { v in var b = button; b.enabled = v; apply(b) }))
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()
            field("Page", button.page, min: 1) { v in var b = button; b.page = v; b.enabled = true; apply(b) }
            if version == .v3 {
                field("Row", button.row, min: 0) { v in var b = button; b.row = v; b.enabled = true; apply(b) }
                field("Col", button.column, min: 0) { v in var b = button; b.column = v; b.enabled = true; apply(b) }
            } else {
                field("Bank", button.bank, min: 1) { v in var b = button; b.bank = v; b.enabled = true; apply(b) }
            }
        }
        .opacity(button.enabled ? 1 : 0.6)
    }

    private func field(_ label: String, _ value: Int, min: Int, apply: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.ocMeta).foregroundStyle(Gallery.faint)
            CommitField(placeholder: "\(min)", value: "\(value)", font: .readout(12), width: 34) { text in
                guard let v = Int(text), v >= min else { return false }
                apply(v)
                return true
            }
        }
    }
}


/// MIDI controller mapping with MIDI learn (APC40 mkII defaults).
struct ControlsSetup: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @State private var learning: (ControlCommand, Int)?
    @State private var session: MIDILearnSession?

    var body: some View {
        let source = MachineProfileStore().profile.controllerSource
        VStack(alignment: .leading, spacing: Space.m) {
            Text(source.isEmpty ? "Choose the controller in Settings (This Mac) to use MIDI learn."
                 : "Controller: \(source). Click Learn, then press the pad, button or knob.")
                .font(.ocMeta).foregroundStyle(source.isEmpty ? Gallery.amber : Gallery.dim)
            HStack {
                Button("Reset to APC40 mkII layout") { model.edit("Reset Controls") { $0.resetMIDIBindingsToAPC40() } }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                if learning != nil {
                    Text("Waiting for a press…").font(.ocLabel).foregroundStyle(Gallery.amber)
                    Button("Cancel") { stopLearning() }.buttonStyle(QuietButtonStyle())
                }
            }
            Text("Actions").sectionLabel()
            ForEach(ControlCommand.allCases.filter { !$0.needsCamera }) { command in
                row(command, camera: 0, title: command.label)
            }
            Text("Cameras").sectionLabel().padding(.top, Space.s)
            ForEach(show.sortedCameras) { cam in
                row(.takeCamera, camera: cam.number, title: "Take camera \(cam.number) · \(cam.displayName)")
            }
        }
        .onDisappear { stopLearning() }
    }

    private func row(_ command: ControlCommand, camera: Int, title: String) -> some View {
        let binding = show.midiBindings.first { $0.command == command && $0.cameraNumber == camera }
        let isLearning = learning.map { $0.0 == command && $0.1 == camera } ?? false
        return HStack(spacing: Space.s) {
            Text(title).font(.ocBody).foregroundStyle(Gallery.ink).frame(maxWidth: .infinity, alignment: .leading)
            Text(binding.map { "\($0.isCC ? "CC" : "Note") \($0.number) · ch \($0.channel + 1)" } ?? "Not mapped")
                .font(.readout(11)).foregroundStyle(binding == nil ? Gallery.faint : Gallery.dim)
                .frame(width: 130, alignment: .trailing)
            Button(isLearning ? "Press…" : "Learn") { startLearning(command, camera: camera) }
                .buttonStyle(QuietButtonStyle(prominent: isLearning))
            IconButton(symbol: "xmark", help: "Remove this mapping") {
                model.edit("Remove Control") { $0.removeMIDIBinding(command, camera: camera) }
            }
            .opacity(binding == nil ? 0.3 : 1)
            .disabled(binding == nil)
        }
        .padding(.vertical, 2)
    }

    private func startLearning(_ command: ControlCommand, camera: Int) {
        let source = MachineProfileStore().profile.controllerSource
        guard !source.isEmpty else { model.errorMessage = "Choose the controller in Settings (This Mac) first."; return }
        learning = (command, camera)
        let s = MIDILearnSession(source: source)
        s.onMessage = { channel, number, isCC in
            guard let target = learning else { return }
            model.edit("Map Control") { $0.setMIDIBinding(target.0, camera: target.1, channel: channel, number: number, isCC: isCC) }
            stopLearning()
        }
        session = s
    }

    private func stopLearning() {
        session?.onMessage = nil
        session = nil
        learning = nil
    }
}


/// Operator monitors: crew views opened on this Mac's extra displays (HDMI to the monitors at
/// camera positions or backstage) while in Live Mode.
struct MonitorsSetup: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @State private var screens = NSScreen.screens.map(\.localizedName)

    var body: some View {
        Text("Crew views shown full screen on this Mac's other displays during Live Mode. Open them from Live Mode with Monitors.")
            .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
        ForEach(show.settings.monitors) { monitor in
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    CommitField(placeholder: "Name", value: monitor.name, font: .ocBodyStrong, width: 180) { text in
                        guard !text.isEmpty else { return false }
                        model.edit("Rename Monitor") { $0.updateMonitor(monitor.id) { $0.name = text } }
                        return true
                    }
                    Picker("Shows", selection: Binding(get: { monitor.kind }, set: { k in model.edit("Change Monitor View") { $0.updateMonitor(monitor.id) { $0.kind = k } } })) {
                        ForEach(MonitorKind.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                    Spacer()
                    IconButton(symbol: "trash", help: "Delete this monitor") { model.edit("Delete Monitor") { $0.deleteMonitor(monitor.id) } }
                }
                HStack(spacing: Space.s) {
                    Text("Display").font(.ocMeta).foregroundStyle(Gallery.dim)
                    Picker("Display", selection: Binding(get: { monitor.screenName }, set: { n in model.edit("Change Monitor Display") { $0.updateMonitor(monitor.id) { $0.screenName = n } } })) {
                        Text("A window on this screen").tag("")
                        ForEach(Array(Set(screens + [monitor.screenName]).filter { !$0.isEmpty }).sorted(), id: \.self) { name in
                            Text(screens.contains(name) ? name : "\(name) (not connected)").tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 260)
                }
                if monitor.kind == .cameras {
                    HStack(spacing: 4) {
                        Text("Cameras").font(.ocMeta).foregroundStyle(Gallery.dim)
                        ForEach(show.sortedCameras) { cam in
                            let on = monitor.cameraIDs.contains(cam.id)
                            Button {
                                model.edit(on ? "Remove Camera from Monitor" : "Add Camera to Monitor") { s in
                                    s.updateMonitor(monitor.id) { m in
                                        if on { m.cameraIDs.removeAll { $0 == cam.id } } else { m.cameraIDs.append(cam.id) }
                                    }
                                }
                            } label: {
                                Text("\(cam.number)")
                                    .font(.readout(12, weight: .bold))
                                    .frame(width: 26, height: 22)
                                    .foregroundStyle(on ? Gallery.well : Gallery.dim)
                                    .background(on ? cam.swiftUIColor : Gallery.key, in: RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help(cam.displayName)
                        }
                    }
                }
            }
            .padding(Space.s)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        }
        Button {
            let name = "Monitor \(show.settings.monitors.count + 1)"
            model.edit("Add Monitor") { $0.addMonitor(name: name, kind: .gallery) }
        } label: {
            Label("Monitor", systemImage: "plus")
        }
        .buttonStyle(QuietButtonStyle())
        .onAppear { screens = NSScreen.screens.map(\.localizedName) }
    }
}
