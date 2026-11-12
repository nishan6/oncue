import SwiftUI
import AppKit
import OnCueCore

/// Show › Trigger Routes: incoming OSC, MIDI, MIDI Show Control and Art-Net mapped to OnCue
/// actions, with Learn, a monitor of what arrives, checks, and Test (in Live Mode).
struct TriggerRoutesView: View {
    let project: Project
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var monitor = TriggerMonitor()
    @State private var selection: UUID?
    @State private var learning = false
    @State private var testValue = ""

    private var routes: [TriggerRoute] { project.properties.triggerRoutes }
    private var issues: [TriggerIssue] { project.triggerIssues() }
    private var live: Bool { model.engine != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRIGGER ROUTES").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
                    Text("Stream Deck via Companion, grandMA3, a playback rig or a MIDI pedal driving OnCue. OSC arrives on this Mac's OSC port (\(oscPort)); MIDI from every connected source; Art-Net on UDP 6454. The built-in /oncue/… addresses keep working alongside these routes.")
                        .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            HStack(spacing: 0) {
                routeList.frame(width: 300)
                Rectangle().fill(Gallery.hairline).frame(width: 1)
                ScrollView {
                    if let index = routes.firstIndex(where: { $0.id == selection }) {
                        RouteEditor(route: routes[index], project: project, model: model,
                                    issues: issues.filter { $0.routeID == routes[index].id },
                                    learning: $learning, testValue: $testValue, live: live,
                                    learn: { startLearn(for: routes[index].id) })
                            .padding(Space.l)
                    } else {
                        Text(routes.isEmpty ? "No routes yet. Add one, or press Learn and send something from your desk or Stream Deck." : "Select a route.")
                            .font(.ocBody).foregroundStyle(Gallery.faint).padding(Space.xl)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            monitorStrip.frame(height: 150)
        }
        .frame(width: 1000, height: 680)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            if selection == nil { selection = routes.first?.id }
            startMonitor()
        }
        .onDisappear { monitor.stop() }
        .onChange(of: routes) { _, new in monitor.update(routes: new) }
    }

    private var oscPort: Int { MachineProfileStore().profile.oscControlPort }

    private func startMonitor() {
        guard !live else { return }
        let universes = Set(routes.filter { $0.input.kind == .artNet }.map(\.input.universe))
        monitor.start(oscPort: oscPort, routes: routes, artNetUniverses: universes.isEmpty ? [0] : universes)
    }

    private func startLearn(for id: UUID) {
        guard !live else { return }
        learning = true
        monitor.onLearn = { event in
            learning = false
            model.editProject("Learn Trigger") { p in
                guard let i = p.properties.triggerRoutes.firstIndex(where: { $0.id == id }) else { return }
                let threshold = p.properties.triggerRoutes[i].input.threshold
                var input = TriggerInput.learned(from: event)
                if input.kind == p.properties.triggerRoutes[i].input.kind { input.threshold = threshold }
                p.properties.triggerRoutes[i].input = input
                if p.properties.triggerRoutes[i].name.isEmpty { p.properties.triggerRoutes[i].name = event.summary }
            }
        }
    }

    // MARK: List

    private var routeList: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(routes) { route in
                    let routeIssues = issues.filter { $0.routeID == route.id }
                    HStack(spacing: Space.s) {
                        Image(systemName: route.enabled ? "circle.fill" : "circle")
                            .font(.system(size: 7)).foregroundStyle(route.enabled ? Gallery.next : Gallery.faint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(route.name.isEmpty ? "Untitled route" : route.name).font(.ocBody).lineLimit(1)
                            Text("\(route.input.summary) → \(actionSummary(route.action))")
                                .font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if routeIssues.contains(where: { $0.level == .error }) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Gallery.tally)
                        } else if !routeIssues.isEmpty {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(Gallery.amber)
                        }
                    }
                    .tag(route.id)
                    .contextMenu {
                        Button("Duplicate") { duplicate(route) }
                        Button("Delete", role: .destructive) { delete(route.id) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            HStack(spacing: Space.s) {
                Menu {
                    ForEach(TriggerInputKind.allCases) { kind in
                        Button(kind.label) { add(kind) }
                    }
                } label: { Label("Add route", systemImage: "plus") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                if let selection {
                    IconButton(symbol: "trash", help: "Delete this route") { delete(selection) }
                }
            }
            .padding(Space.m)
        }
        .background(Gallery.well)
    }

    private func add(_ kind: TriggerInputKind) {
        var route = TriggerRoute(input: TriggerInput(kind: kind))
        if kind == .osc { route.input.address = "/" }
        if kind == .artNet { route.input.number = 1 }
        model.editProject("Add Trigger Route") { $0.properties.triggerRoutes.append(route) }
        selection = route.id
    }

    private func duplicate(_ route: TriggerRoute) {
        var copy = route
        copy.id = UUID()
        copy.name = route.name.isEmpty ? "" : route.name + " copy"
        model.editProject("Duplicate Trigger Route") { $0.properties.triggerRoutes.append(copy) }
        selection = copy.id
    }

    private func delete(_ id: UUID) {
        model.editProject("Delete Trigger Route") { $0.properties.triggerRoutes.removeAll { $0.id == id } }
        selection = routes.first { $0.id != id }?.id
    }

    private func actionSummary(_ a: TriggerAction) -> String {
        switch a.kind {
        case .command:
            return a.command.needsCamera ? "\(a.command.label.replacingOccurrences(of: " N", with: "")) \(a.cameraNumber > 0 ? "\(a.cameraNumber)" : "from value")" : a.command.label
        case .jumpToItem, .jumpToSection, .fireCue:
            return a.kind.label + (a.target == .fromValue ? " (from value)" : "")
        default:
            return a.kind.label
        }
    }

    // MARK: Monitor

    private var monitorStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.s) {
                Text("INCOMING").font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
                if live {
                    Text("Live Mode is listening on these ports: test routes from your desk and watch Live.").font(.ocMeta).foregroundStyle(Gallery.dim)
                } else if learning {
                    Text("Learning: send the trigger now…").font(.ocMeta).foregroundStyle(Gallery.amber)
                } else if monitor.listening {
                    Text("Listening. Nothing is sent to switchers from here.").font(.ocMeta).foregroundStyle(Gallery.dim)
                }
                ForEach(monitor.problems, id: \.self) { Text($0).font(.ocMeta).foregroundStyle(Gallery.amber) }
                Spacer()
                Button("Clear") { monitor.clear() }.buttonStyle(QuietButtonStyle()).disabled(monitor.arrivals.isEmpty)
            }
            .padding(.horizontal, Space.l).padding(.vertical, Space.s)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(monitor.arrivals) { a in
                        HStack(spacing: Space.m) {
                            Text(a.date.formatted(date: .omitted, time: .standard)).font(.readout(11)).foregroundStyle(Gallery.faint)
                            Text(a.event.kind.label).font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 120, alignment: .leading)
                            Text(a.event.summary).font(.readout(11)).foregroundStyle(Gallery.ink)
                            Spacer()
                            Text(a.routes.isEmpty ? "no route" : "→ " + a.routes.joined(separator: ", "))
                                .font(.ocMeta).foregroundStyle(a.routes.isEmpty ? Gallery.faint : Gallery.next)
                        }
                        .padding(.horizontal, Space.l)
                        .frame(height: 20)
                    }
                }
            }
        }
        .background(Gallery.well)
    }
}

// MARK: - Route editor

private struct RouteEditor: View {
    let route: TriggerRoute
    let project: Project
    @ObservedObject var model: WorkspaceModel
    let issues: [TriggerIssue]
    @Binding var learning: Bool
    @Binding var testValue: String
    let live: Bool
    let learn: () -> Void

    private var items: [RundownItem] { project.playlists.flatMap(\.items) }

    private func change(_ name: String, _ body: @escaping (inout TriggerRoute) -> Void) {
        let id = route.id
        model.editProject(name) { p in
            guard let i = p.properties.triggerRoutes.firstIndex(where: { $0.id == id }) else { return }
            body(&p.properties.triggerRoutes[i])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(spacing: Space.m) {
                CommitField(placeholder: "Name, e.g. MA3 cue → song", value: route.name, font: .ocBody) { text in
                    change("Rename Route") { $0.name = text.trimmingCharacters(in: .whitespaces) }
                    return true
                }
                Toggle("On", isOn: Binding(get: { route.enabled }, set: { v in change(v ? "Enable Route" : "Disable Route") { $0.enabled = v } }))
                    .toggleStyle(.switch)
            }
            ForEach(issues) { issue in
                Label(issue.message, systemImage: issue.level == .error ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .font(.ocMeta).foregroundStyle(issue.level == .error ? Gallery.tally : Gallery.amber)
            }
            section("WHEN THIS ARRIVES") { inputFields }
            section("ONCUE DOES THIS") { actionFields }
            section("TEST") {
                HStack(spacing: Space.s) {
                    TextField("Value", text: $testValue).textFieldStyle(.roundedBorder).frame(width: 80)
                        .help("The value the trigger would carry: a velocity, program number, cue number or DMX level")
                    Button("Run Now") {
                        model.engine?.perform(route.action, value: Double(testValue))
                    }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(!live)
                    Text(live ? "Runs the action in Live Mode right now." : "Test runs in Live Mode, where OnCue is connected to the switcher. Use Learn and the monitor below to check the input.")
                        .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
            content()
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Gallery.well, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    // MARK: Input

    @ViewBuilder private var inputFields: some View {
        let i = route.input
        HStack(spacing: Space.m) {
            Picker("Type", selection: Binding(get: { i.kind }, set: { k in change("Change Input") { r in
                let name = r.input.address
                r.input = TriggerInput(kind: k)
                if k == .osc { r.input.address = name.isEmpty ? "/" : name }
                if k == .artNet { r.input.number = 1 }
            } })) {
                ForEach(TriggerInputKind.allCases) { Text($0.label).tag($0) }
            }
            .frame(width: 240)
            Button(learning ? "Listening…" : "Learn") { learn() }
                .buttonStyle(QuietButtonStyle())
                .disabled(live || learning)
                .help(live ? "Leave Live Mode to learn" : "Fill this in from the next message that arrives")
        }
        switch i.kind {
        case .osc:
            field("Address") {
                CommitField(placeholder: "/gma3/cue/12", value: i.address, font: .readout(13)) { text in
                    change("Change Address") { $0.input.address = text.trimmingCharacters(in: .whitespaces) }
                    return true
                }
            }
            hint("End with * to match any ending (/gma3/cue/* matches every cue). The first number sent with it is the value.")
        case .midiNote, .midiCC:
            HStack(spacing: Space.l) {
                field(i.kind == .midiNote ? "Note" : "CC") { number(i.number, 0...127) { v in change("Change Number") { $0.input.number = v } } }
                field("Channel") { channelPicker(i.channel) }
                if i.kind == .midiCC {
                    field("Fires at") { number(i.threshold, 1...127) { v in change("Change Level") { $0.input.threshold = v } } }
                }
            }
            hint(i.kind == .midiNote ? "Fires on note on. The velocity is the value." : "Fires once as the value rises to the level; it must drop below it before it fires again.")
        case .midiProgram:
            field("Channel") { channelPicker(i.channel) }
            hint("Program 1 is the first program on most devices. The program number is the value: use it to choose song N.")
        case .msc:
            field("Command") {
                Picker("", selection: Binding(get: { i.msc }, set: { v in change("Change MSC Command") { $0.input.msc = v } })) {
                    ForEach(MSCCommand.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().frame(width: 140)
            }
            hint("Any MSC device ID. The cue number is the value (GO cue 12 → 12).")
        case .artNet:
            HStack(spacing: Space.l) {
                field("Universe") { number(i.universe, 0...32767) { v in change("Change Universe") { $0.input.universe = v } } }
                field("Channel") { number(i.number, 1...512) { v in change("Change DMX Channel") { $0.input.number = v } } }
                field("Fires at") { number(i.threshold, 1...255) { v in change("Change Level") { $0.input.threshold = v } } }
            }
            hint("Fires once as the level rises to the value set; it must drop below it before it fires again. Universe 0 is the first (Art-Net port address).")
        }
    }

    private func channelPicker(_ channel: Int) -> some View {
        Picker("", selection: Binding(get: { channel }, set: { v in change("Change Channel") { $0.input.channel = v } })) {
            Text("Any").tag(0)
            ForEach(1...16, id: \.self) { Text("\($0)").tag($0) }
        }
        .labelsHidden().frame(width: 80)
    }

    // MARK: Action

    @ViewBuilder private var actionFields: some View {
        let a = route.action
        Picker("Action", selection: Binding(get: { a.kind }, set: { k in change("Change Action") { $0.action.kind = k } })) {
            ForEach(TriggerActionKind.allCases) { Text($0.label).tag($0) }
        }
        .frame(width: 320)
        switch a.kind {
        case .command:
            HStack(spacing: Space.l) {
                field("Control") {
                    Picker("", selection: Binding(get: { a.command }, set: { v in change("Change Control") { $0.action.command = v } })) {
                        ForEach(ControlCommand.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 240)
                }
                if a.command.needsCamera {
                    field("Camera") {
                        Picker("", selection: Binding(get: { a.cameraNumber }, set: { v in change("Change Camera") { $0.action.cameraNumber = v } })) {
                            Text("From value").tag(0)
                            ForEach(project.cameras.sorted { $0.number < $1.number }) { Text("\($0.number) \($0.name)").tag($0.number) }
                        }
                        .labelsHidden().frame(width: 180)
                    }
                }
            }
            if a.command.needsCamera {
                hint("Camera override: takes the camera now, outside the script. In Auto cut this pauses automation until you resume.")
            }
        case .jumpToItem:
            targetPicker(a)
            if a.target == .fixed {
                field("Song or segment") {
                    Picker("", selection: Binding(get: { a.itemID }, set: { v in change("Change Target") { $0.action.itemID = v } })) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(items) { Text(label($0)).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden().frame(width: 320)
                }
            } else {
                hint("The value picks the song: a scene number that matches wins, otherwise the Nth in the running order.")
            }
        case .jumpToSection:
            targetPicker(a)
            if a.target == .fixed {
                field("Section") {
                    Picker("", selection: Binding(get: { a.sectionID }, set: { v in change("Change Target") { $0.action.sectionID = v } })) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(items.filter { !$0.sections.isEmpty }) { item in
                            Section(item.title) {
                                ForEach(item.sortedSections) { Text("\(item.title) · \($0.name)").tag(UUID?.some($0.id)) }
                            }
                        }
                    }
                    .labelsHidden().frame(width: 320)
                }
            } else {
                hint("The value picks section N of the song that is live.")
            }
        case .fireCue:
            targetPicker(a)
            if a.target == .fixed {
                field("Shot or cue") {
                    Picker("", selection: Binding(get: { a.cueID }, set: { v in change("Change Target") { $0.action.cueID = v } })) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(items) { item in
                            Section(item.title) {
                                ForEach(cueChoices(item), id: \.0) { Text($0.1).tag(UUID?.some($0.0)) }
                            }
                        }
                    }
                    .labelsHidden().frame(width: 320)
                }
                hint("Jumps the show to it, so it fires now.")
            } else {
                hint("The value picks shot N of the song that is live.")
            }
        case .markNote:
            field("Note") {
                CommitField(placeholder: "Empty: “Marked from <trigger>”", value: a.noteText, font: .ocBody) { text in
                    change("Change Note") { $0.action.noteText = text }
                    return true
                }
            }
            hint("Adds a note to the shot on air (Inspector › Reviews), with the time.")
        case .pauseChase, .resumeChase, .toggleChase:
            hint("While chase is paused OnCue ignores timecode and holds its place; resuming picks timecode up again.")
        case .holdLive:
            hint("Hold stops automation (the switcher stays where it is); the same trigger releases it.")
        case .goLive, .stopLive:
            EmptyView()
        }
    }

    private func targetPicker(_ a: TriggerAction) -> some View {
        Picker("", selection: Binding(get: { a.target }, set: { v in change("Change Target") { $0.action.target = v } })) {
            Text("A fixed one").tag(TriggerTargetSource.fixed)
            Text("From the trigger's value").tag(TriggerTargetSource.fromValue)
        }
        .pickerStyle(.segmented).labelsHidden().frame(width: 320)
    }

    private func label(_ item: RundownItem) -> String {
        item.number.isEmpty ? item.title : "\(item.number). \(item.title)"
    }

    private func cueChoices(_ item: RundownItem) -> [(UUID, String)] {
        var out: [(UUID, String)] = []
        for track in item.tracks {
            for (k, cue) in track.cues.sorted(by: { $0.at < $1.at }).enumerated() {
                let what = track.kind == .shots ? "Shot \(k + 1)" : track.kind.label
                let text = cue.text.isEmpty ? "" : " · \(cue.text)"
                out.append((cue.id, "\(item.title) · \(what) at \(item.format(cue.at))\(text)"))
            }
        }
        return out
    }

    // MARK: Small parts

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.ocMeta).foregroundStyle(Gallery.dim)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
    }

    private func number(_ value: Int, _ range: ClosedRange<Int>, set: @escaping (Int) -> Void) -> some View {
        CommitField(placeholder: "\(range.lowerBound)", value: "\(value)", font: .readout(13), width: 64) { text in
            guard let v = Int(text.trimmingCharacters(in: .whitespaces)), range.contains(v) else { return false }
            set(v)
            return true
        }
    }
}
