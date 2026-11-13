import SwiftUI
import OnCueCore

/// Show › Device Status: every device the show uses and how it is doing right now. Live Mode
/// connects; outside it, the Pre-show check tests connections.
struct DeviceStatusView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEVICE STATUS").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
                    Text(model.engine == nil ? "Devices connect in Live Mode. To test them now, run the Pre-show check."
                         : "Live: updates as it happens. Every device is marked Built until it has been tested on the real thing.")
                        .font(.ocMeta).foregroundStyle(Gallery.dim)
                }
                Spacer()
                if model.engine == nil {
                    Button("Pre-show Check…") { dismiss(); DispatchQueue.main.async { model.preShowCheckOpen = true } }
                        .buttonStyle(QuietButtonStyle())
                }
                Button("Done") { dismiss() }.buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            ScrollView {
                if let engine = model.engine {
                    LiveDeviceList(show: show, engine: engine)
                        .padding(Space.l)
                } else {
                    plannedList.padding(Space.l)
                }
            }
        }
        .frame(width: 720, height: 560)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private var plannedList: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            section("SWITCHERS")
            ForEach(show.switchers) { s in row(s.name, s.kind.label + (s.host.isEmpty ? "" : " · \(s.host)"), nil) }
            if !show.tallyOutputs.isEmpty || !show.tallyInputs.isEmpty {
                section("TALLY")
                ForEach(show.tallyOutputs) { t in row(t.name, "\(t.version.label) out" + (t.simulated ? " · simulated" : " · \(t.host):\(t.port)"), nil) }
                ForEach(show.tallyInputs) { t in row(t.name, "\(t.version.label) in · UDP \(t.port)", nil) }
            }
            if !show.deviceTargets.isEmpty {
                section("DEVICES AND CONSOLES")
                ForEach(show.deviceTargets) { d in
                    row(d.name, (d.kind == .console ? d.console.kind.label : d.kind.label) + (d.simulated ? " · simulated" : ""), nil)
                }
            }
        }
    }
}

private struct LiveDeviceList: View {
    let show: Show
    @ObservedObject var engine: EngineController

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            section("SWITCHERS")
            ForEach(engine.status.switchers) { s in
                let config = show.switchers.first { $0.id == s.id }
                let detail: String = {
                    var parts = [config?.kind.label ?? ""]
                    if s.connected {
                        if let p = s.program { parts.append("PGM \(p)") }
                        if let v = s.preview { parts.append("PVW \(v)") }
                        if s.assumed { parts.append("assumed (no read-back)") }
                        if !s.modelName.isEmpty { parts.append(s.modelName) }
                    } else {
                        parts.append(s.connecting ? "connecting…" : "not connected")
                    }
                    if let mirror = engine.failedOver[s.id], let m = show.switchers.first(where: { $0.id == mirror }) {
                        parts.append("FAILED OVER to \(m.name)")
                    }
                    return parts.joined(separator: " · ")
                }()
                row(s.name, detail, s.connected)
            }
            if !show.tallyOutputs.isEmpty || !show.tallyInputs.isEmpty {
                section("TALLY")
                ForEach(show.tallyOutputs) { t in
                    let now = engine.tallyNow(t.id)
                    row(t.name, "\(t.version.label) out · \(now?.sent ?? 0) packets" + (t.simulated ? " · simulated" : "") + (now?.error.map { " · \($0)" } ?? ""),
                        now?.error == nil ? (t.enabled ? true : nil) : false)
                }
                ForEach(show.tallyInputs) { t in
                    let input = engine.tallyInProgram[t.id]
                    row(t.name, "\(t.version.label) in · " + (input.map { "program is input \($0)" } ?? "nothing received yet"), input != nil ? true : nil)
                }
            }
            if !show.deviceTargets.isEmpty {
                section("DEVICES AND CONSOLES")
                ForEach(show.deviceTargets) { d in
                    let last = engine.recentDeviceSends.first { $0.target == d.name }
                    let readBack = engine.consoleReadBack.first { $0.name == d.name }?.summary
                    var detail = d.kind == .console ? d.console.kind.label : d.kind.label
                    if d.simulated { detail += " · simulated" }
                    if let readBack { detail += " · reports: \(readBack)" }
                    if let last { detail += " · last: \(last.summary)" + (last.error.map { " (\($0))" } ?? "") }
                    return row(d.name, detail, last == nil ? nil : last?.error == nil)
                }
            }
            if !engine.failoverLog.isEmpty {
                section("FAILOVER LOG")
                ForEach(engine.failoverLog.reversed()) { e in
                    HStack(alignment: .top) {
                        Text(e.time.formatted(date: .omitted, time: .standard)).font(.readout(11)).foregroundStyle(Gallery.faint)
                        Text(e.message).font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private func section(_ title: String) -> some View {
    Text(title).font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint).padding(.top, Space.m)
}

/// ok: true = working, false = a problem, nil = unknown or idle.
private func row(_ name: String, _ detail: String, _ ok: Bool?) -> some View {
    HStack(alignment: .top, spacing: Space.s) {
        Circle().fill(ok == true ? Gallery.next : (ok == false ? Gallery.tally : Gallery.faint)).frame(width: 8, height: 8).padding(.top, 5)
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.ocBody).foregroundStyle(Gallery.ink)
            Text(detail).font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
    }
    .padding(Space.s)
    .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.s))
}
