import SwiftUI
import OnCueCore

/// Show Setup › Tally: TSL UMD tally (and camera names) out to tally systems and multiviewers.
struct TallySetup: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("OnCue sends red for the camera on program and green for the one on preview, read back from the main switcher (or the parallel one after a failover), plus camera names for the UMDs. ATEM's own tally keeps working as before, including through the ATEM GPI and Tally Interface. Built from TSL's protocol documents; not yet tested on a real tally system.")
                .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            ForEach(show.tallyOutputs) { config in
                TallyOutputCard(config: config, show: show, model: model)
            }
            Text("TALLY IN").font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
            Text("A switcher or tally system reporting what is really on program (TSL over UDP). A cut OnCue didn't make pauses automation, as an ATEM's own read-back does. Use it for switchers OnCue drives through Companion.")
                .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            ForEach(show.tallyInputs) { config in
                TallyInputCard(config: config, show: show, model: model)
            }
            Button {
                var c = TallyInputConfig(name: "Tally in \(show.tallyInputs.count + 1)")
                c.switcherID = show.mainOutput?.switcherID
                model.edit("Add Tally Input") { $0.tallyInputs.append(c) }
            } label: { Label("Tally input", systemImage: "plus") }
            .buttonStyle(QuietButtonStyle())
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            Text("TALLY OUT").font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
            HStack(spacing: Space.s) {
                Button {
                    model.edit("Add Tally Output") { $0.tallyOutputs.append(TallyOutputConfig(name: "Tally \(show.tallyOutputs.count + 1)")) }
                } label: { Label("Tally output", systemImage: "plus") }
                Button {
                    var c = TallyOutputConfig(name: "Simulated tally")
                    c.simulated = true
                    model.edit("Add Simulated Tally") { $0.tallyOutputs.append(c) }
                } label: { Label("Simulated tally", systemImage: "plus") }
                .help("Shows in Live Mode what a tally system would get. Nothing leaves this Mac.")
            }
            .buttonStyle(QuietButtonStyle())
        }
    }
}

private struct TallyOutputCard: View {
    let config: TallyOutputConfig
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                CommitField(placeholder: "Name", value: config.name, font: .ocHeading, width: 220) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    update("Rename Tally Output") { $0.name = t }
                    return true
                }
                if config.simulated { Pill(text: "SIMULATED", color: Gallery.amber) }
                Spacer()
                Toggle("On", isOn: Binding(get: { config.enabled }, set: { v in update("Turn Tally Output \(v ? "On" : "Off")") { $0.enabled = v } }))
                    .toggleStyle(.switch)
                IconButton(symbol: "trash", help: "Delete this tally output") {
                    model.edit("Delete Tally Output") { $0.tallyOutputs.removeAll { $0.id == config.id } }
                }
            }
            PropertyRow(label: "Protocol") {
                HStack {
                    Picker("", selection: Binding(get: { config.version }, set: { v in update("Change Tally Protocol") { $0.version = v } })) {
                        ForEach(TSLVersion.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 160)
                    Picker("", selection: Binding(get: { config.transport }, set: { v in update("Change Tally Transport") { $0.transport = v } })) {
                        ForEach(TallyTransport.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 110)
                    .disabled(config.version != .v50)
                    .help("TCP is only defined for TSL 5.0")
                }
            }
            if !config.simulated {
                PropertyRow(label: "Send to") {
                    HStack {
                        CommitField(placeholder: "192.168.10.50", value: config.host, font: .readout(13), width: 170) { text in
                            update("Change Tally Address") { $0.host = text.trimmingCharacters(in: .whitespaces) }
                            return true
                        }
                        Text("port").font(.ocMeta).foregroundStyle(Gallery.dim)
                        CommitField(placeholder: "8900", value: String(config.port), font: .readout(13), width: 70) { text in
                            guard let p = Int(text), (1...65535).contains(p) else { return false }
                            update("Change Tally Port") { $0.port = p }
                            return true
                        }
                        if config.version == .v50 {
                            Text("screen").font(.ocMeta).foregroundStyle(Gallery.dim)
                            CommitField(placeholder: "0", value: String(config.screen), font: .readout(13), width: 50) { text in
                                guard let s = Int(text), s >= 0 else { return false }
                                update("Change Tally Screen") { $0.screen = s }
                                return true
                            }
                        }
                    }
                }
            }
            PropertyRow(label: "Tally number") {
                Picker("", selection: Binding(get: { config.indexMode }, set: { v in update("Change Tally Numbering") { $0.indexMode = v } })) {
                    ForEach(TallyIndexMode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 260)
            }
            Toggle("Send camera names to the UMDs (\"1 Wide – Arjun\")", isOn: Binding(get: { config.sendNames }, set: { v in update("Change UMD Names") { $0.sendNames = v } }))
                .toggleStyle(.checkbox)
            Toggle("Simulated: nothing leaves this Mac", isOn: Binding(get: { config.simulated }, set: { v in update("Change Tally Simulation") { $0.simulated = v } }))
                .toggleStyle(.checkbox)
        }
        .padding(Space.m)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func update(_ name: String, _ change: @escaping (inout TallyOutputConfig) -> Void) {
        model.edit(name) { s in
            if let i = s.tallyOutputs.firstIndex(where: { $0.id == config.id }) { change(&s.tallyOutputs[i]) }
        }
    }
}

/// Live Mode: failover prompt, the failover log and what each tally output is showing.
struct LiveDeviceStrip: View {
    let show: Show
    @ObservedObject var engine: EngineController

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let id = engine.failoverPrompt, let config = show.switchers.first(where: { $0.id == id }) {
                HStack(spacing: Space.m) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.black)
                    Text("\(config.name) lost. Fail over to \(show.switchers.first { $0.mirrorOf == id }?.name ?? "the parallel switcher")?")
                        .font(.ocBodyStrong).foregroundStyle(.black)
                    Spacer()
                    Button("Not Now") { engine.dismissFailoverPrompt() }.buttonStyle(QuietButtonStyle())
                    Button("Fail Over") { engine.failover(id) }
                        .buttonStyle(QuietButtonStyle(prominent: true))
                        .keyboardShortcut("f", modifiers: [.command, .shift])
                }
                .padding(Space.m)
                .background(Gallery.amber, in: RoundedRectangle(cornerRadius: Radius.m))
            }
            ForEach(Array(engine.failedOver.keys), id: \.self) { main in
                let mirror = engine.failedOver[main].flatMap { m in show.switchers.first { $0.id == m } }
                Label("FAILED OVER: reading program and tally from \(mirror?.name ?? "the parallel switcher")", systemImage: "arrow.triangle.branch")
                    .font(.ocTag).foregroundStyle(Gallery.amber)
            }
            if let sent = engine.recentDeviceSends.first, sent.simulated || sent.error != nil {
                HStack(spacing: Space.s) {
                    Text(sent.simulated ? "SIMULATED" : "DEVICE ERROR").font(.ocTag).tracking(0.6)
                        .foregroundStyle(sent.error != nil ? Gallery.tally : Gallery.faint)
                    Text("\(sent.target): \(sent.summary)").font(.ocMeta).foregroundStyle(Gallery.dim)
                    if let error = sent.error { Text(error).font(.ocMeta).foregroundStyle(Gallery.tally) }
                }
            }
            ForEach(engine.consoleReadBack, id: \.name) { console in
                HStack(spacing: Space.s) {
                    Text(console.name.uppercased()).font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
                    Text(console.summary).font(.ocMeta).foregroundStyle(Gallery.dim)
                }
            }
            ForEach(show.tallyOutputs.filter(\.simulated)) { output in
                if let now = engine.tallyNow(output.id) {
                    HStack(spacing: 4) {
                        Text("SIMULATED TALLY").font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
                        ForEach(now.states, id: \.index) { t in
                            Text("\(t.index)")
                                .font(.readout(11, weight: .bold))
                                .foregroundStyle(t.program || t.preview ? .black : Gallery.dim)
                                .frame(width: 26, height: 20)
                                .background(t.program ? Gallery.tally : (t.preview ? Gallery.next : Gallery.raised),
                                            in: RoundedRectangle(cornerRadius: 3))
                                .help(t.text)
                        }
                    }
                }
            }
        }
    }
}

private struct TallyInputCard: View {
    let config: TallyInputConfig
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                CommitField(placeholder: "Name", value: config.name, font: .ocHeading, width: 220) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    update("Rename Tally Input") { $0.name = t }
                    return true
                }
                Spacer()
                Toggle("On", isOn: Binding(get: { config.enabled }, set: { v in update("Turn Tally Input \(v ? "On" : "Off")") { $0.enabled = v } }))
                    .toggleStyle(.switch)
                IconButton(symbol: "trash", help: "Delete this tally input") {
                    model.edit("Delete Tally Input") { $0.tallyInputs.removeAll { $0.id == config.id } }
                }
            }
            PropertyRow(label: "Listen") {
                HStack {
                    Picker("", selection: Binding(get: { config.version }, set: { v in update("Change Tally Protocol") { $0.version = v } })) {
                        ForEach(TSLVersion.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 160)
                    Text("UDP port").font(.ocMeta).foregroundStyle(Gallery.dim)
                    CommitField(placeholder: "8901", value: String(config.port), font: .readout(13), width: 70) { text in
                        guard let p = Int(text), (1...65535).contains(p) else { return false }
                        update("Change Tally Port") { $0.port = p }
                        return true
                    }
                }
            }
            PropertyRow(label: "Reports") {
                Picker("", selection: Binding(get: { config.switcherID }, set: { v in update("Change Tally Switcher") { $0.switcherID = v } })) {
                    ForEach(show.switchers.filter { $0.mirrorOf == nil }) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                .labelsHidden().frame(width: 220)
            }
            PropertyRow(label: "Tally number") {
                Picker("", selection: Binding(get: { config.indexMode }, set: { v in update("Change Tally Numbering") { $0.indexMode = v } })) {
                    ForEach(TallyIndexMode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 260)
            }
        }
        .padding(Space.m)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func update(_ name: String, _ change: @escaping (inout TallyInputConfig) -> Void) {
        model.edit(name) { s in
            if let i = s.tallyInputs.firstIndex(where: { $0.id == config.id }) { change(&s.tallyInputs[i]) }
        }
    }
}

/// Show Setup › Devices: targets for Device commands cues.
struct DevicesSetup: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Gear that Device commands cues talk to: a grandMA3 or Ableton over MIDI / MSC, Companion or a playback server over TCP, UDP or HTTP, a projector or router on serial, house lights over Art-Net or sACN. Built from the protocol specs; each stays Built until tested on the real thing. Mark one Simulated to rehearse without it.")
                .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            ForEach(show.deviceTargets) { target in
                DeviceTargetCard(target: target, model: model)
            }
            Menu {
                ForEach(DeviceTargetKind.allCases) { kind in
                    Button(kind.label) {
                        model.edit("Add Device") { $0.deviceTargets.append(DeviceTarget(name: kind.label, kind: kind)) }
                    }
                }
            } label: { Label("Device", systemImage: "plus") }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

private struct DeviceTargetCard: View {
    let target: DeviceTarget
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                CommitField(placeholder: "Name", value: target.name, font: .ocHeading, width: 220) { text in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return false }
                    update("Rename Device") { $0.name = t }
                    return true
                }
                Pill(text: target.kind.label.uppercased(), color: Gallery.dim)
                if target.simulated { Pill(text: "SIMULATED", color: Gallery.amber) }
                Spacer()
                IconButton(symbol: "trash", help: "Delete this device") {
                    model.edit("Delete Device") { $0.deviceTargets.removeAll { $0.id == target.id } }
                }
            }
            switch target.kind {
            case .midi:
                PropertyRow(label: "Destination") {
                    CommitField(placeholder: "As macOS names it, e.g. IAC Driver Bus 1", value: target.midiDestination, font: .ocBody) { text in
                        update("Change MIDI Destination") { $0.midiDestination = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
            case .tcp, .udp:
                hostPort
                lineEnding
            case .console:
                PropertyRow(label: "Console") {
                    Picker("", selection: Binding(get: { target.console.kind }, set: { v in update("Change Console") { t in
                        t.console = ConsoleSettings(kind: v)
                        t.port = v.defaultPort
                    } })) {
                        ForEach(ConsoleKind.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 340)
                }
                hostPort
                switch target.console.kind {
                case .grandMA3:
                    PropertyRow(label: "OSC prefix") {
                        CommitField(placeholder: "gma3", value: target.console.prefix, font: .readout(13), width: 120) { text in
                            update("Change OSC Prefix") { $0.console.prefix = text.trimmingCharacters(in: .whitespaces) }
                            return true
                        }
                    }
                case .grandMA2:
                    PropertyRow(label: "Login") {
                        HStack {
                            CommitField(placeholder: "user", value: target.console.user, font: .ocBody, width: 140) { text in
                                update("Change Console User") { $0.console.user = text }
                                return true
                            }
                            CommitField(placeholder: "password", value: target.console.password, font: .ocBody, width: 140) { text in
                                update("Change Console Password") { $0.console.password = text }
                                return true
                            }
                        }
                    }
                case .allenHeath:
                    PropertyRow(label: "MIDI channel") {
                        CommitField(placeholder: "1", value: String(target.console.midiChannel), font: .readout(13), width: 50) { text in
                            guard let v = Int(text), (1...16).contains(v) else { return false }
                            update("Change Console MIDI Channel") { $0.console.midiChannel = v }
                            return true
                        }
                    }
                case .resolume:
                    PropertyRow(label: "Listen on") {
                        CommitField(placeholder: "7001", value: String(target.console.feedbackPort), font: .readout(13), width: 70) { text in
                            guard let v = Int(text), (1...65535).contains(v) else { return false }
                            update("Change Resolume Feedback Port") { $0.console.feedbackPort = v }
                            return true
                        }
                    }
                    Text("To see which clip is playing on each layer, turn on OSC Output in Resolume's Preferences › OSC and send it to this Mac on this port.")
                        .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
                case .yamahaRCP:
                    Toggle("TF series (scene library scene_a)", isOn: Binding(get: { target.console.yamahaTF }, set: { v in update("Change Yamaha Series") { $0.console.yamahaTF = v } }))
                        .toggleStyle(.checkbox)
                default:
                    EmptyView()
                }
                Text(target.console.kind.notes).font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
            case .hyperDeck:
                hostPort
                Text("Blackmagic HyperDeck Ethernet Protocol (port 9993). Turn on Remote in the deck's setup.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            case .http:
                PropertyRow(label: "Address") {
                    CommitField(placeholder: "http://192.168.10.20:8000", value: target.baseURL, font: .readout(13)) { text in
                        update("Change Device Address") { $0.baseURL = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
            case .serial:
                PropertyRow(label: "Port") {
                    CommitField(placeholder: "/dev/cu.usbserial-…", value: target.serialPath, font: .readout(13)) { text in
                        update("Change Serial Port") { $0.serialPath = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
                PropertyRow(label: "Baud") {
                    Picker("", selection: Binding(get: { target.baud }, set: { v in update("Change Baud Rate") { $0.baud = v } })) {
                        ForEach([1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200], id: \.self) { Text(String($0)).tag($0) }
                    }
                    .labelsHidden().frame(width: 120)
                }
                lineEnding
            case .artNet, .sACN:
                PropertyRow(label: "Universe") {
                    CommitField(placeholder: target.kind == .artNet ? "0" : "1", value: String(target.universe), font: .readout(13), width: 70) { text in
                        guard let u = Int(text), u >= 0, u <= (target.kind == .artNet ? 32767 : 63999) else { return false }
                        update("Change Universe") { $0.universe = u }
                        return true
                    }
                }
                PropertyRow(label: "Send to") {
                    CommitField(placeholder: target.kind == .artNet ? "Broadcast (empty) or a node's IP" : "Multicast (empty) or an IP", value: target.host, font: .readout(13)) { text in
                        update("Change DMX Address") { $0.host = text.trimmingCharacters(in: .whitespaces) }
                        return true
                    }
                }
            }
            Toggle("Simulated: nothing leaves this Mac", isOn: Binding(get: { target.simulated }, set: { v in update("Change Device Simulation") { $0.simulated = v } }))
                .toggleStyle(.checkbox)
        }
        .padding(Space.m)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private var hostPort: some View {
        PropertyRow(label: "Address") {
            HStack {
                CommitField(placeholder: "192.168.10.20", value: target.host, font: .readout(13), width: 170) { text in
                    update("Change Device Address") { $0.host = text.trimmingCharacters(in: .whitespaces) }
                    return true
                }
                Text("port").font(.ocMeta).foregroundStyle(Gallery.dim)
                CommitField(placeholder: "port", value: target.port > 0 ? String(target.port) : "", font: .readout(13), width: 70) { text in
                    guard let p = Int(text), (1...65535).contains(p) else { return false }
                    update("Change Device Port") { $0.port = p }
                    return true
                }
            }
        }
    }

    private var lineEnding: some View {
        PropertyRow(label: "Line ending") {
            Picker("", selection: Binding(get: { target.lineEnding }, set: { v in update("Change Line Ending") { $0.lineEnding = v } })) {
                ForEach(LineEnding.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden().pickerStyle(.segmented).frame(width: 240)
        }
    }

    private func update(_ name: String, _ change: @escaping (inout DeviceTarget) -> Void) {
        model.edit(name) { s in
            if let i = s.deviceTargets.firstIndex(where: { $0.id == target.id }) { change(&s.deviceTargets[i]) }
        }
    }
}
