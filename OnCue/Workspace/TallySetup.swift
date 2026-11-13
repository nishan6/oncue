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
