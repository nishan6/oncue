import SwiftUI
import OnCueCore

// Live Mode: the show engine running the script. NOW and NEXT dominate; the camera grid shows
// program (PGM) and preview (PVW) as the switcher reports them, or as the script has them when no
// switcher is connected. The status in the window toolbar shows the timing source and the switcher.

enum LivePalette {
    static let base = Color(hex: "#0A0B0D")
    static let panel = Color(hex: "#121317")
    static let raised = Color(hex: "#1A1C21")
}

struct LiveView: View {
    let show: Show
    @ObservedObject var engine: EngineController
    @ObservedObject var model: WorkspaceModel
    @FocusState private var focused: Bool
    @State private var typed = ""
    @State private var typedAt = Date.distantPast

    var body: some View {
        let status = engine.status
        let cursor = status.cursor
        let item = show.item(cursor.itemID)
        HStack(spacing: 0) {
            VStack(spacing: Space.l) {
                if status.following {
                    BackupBanner(linked: status.mainLinked) { model.takeOverFromMain() }
                }
                if let reason = status.pauseReason {
                    PausedBanner(reason: reason) { engine.resume() }
                }
                if status.freeMode {
                    FreeModeBanner(show: show, hints: status.hints) { engine.setFreeMode(false) }
                }
                if RundownTiming.applies(to: show) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        LiveRundownStrip(timing: RundownTiming(show: show, log: engine.log, itemID: cursor.itemID, now: context.date))
                    }
                }
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    VStack(spacing: Space.l) {
                        if let item {
                            LiveCountdownBar(show: show, reading: reading(item: item, status: status))
                            let calls = show.upcomingCalls(inItem: item.id, after: status.position)
                            if !calls.isEmpty { LiveCallsStrip(show: show, calls: calls, timed: status.secondsToNext != nil) }
                        }
                        NowNextPanels(show: show, item: item, cursor: cursor, takenAt: status.takenAt,
                                      secondsToNext: status.secondsToNext, now: context.date)
                    }
                }
                UpcomingStrip(show: show, cursor: cursor)
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    LiveCameraGrid(show: show, status: status,
                                   standby: item.flatMap { reading(item: $0, status: status).standbyCameraID },
                                   flash: Int(context.date.timeIntervalSinceReferenceDate * 3) % 2 == 0)
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Rectangle().fill(Gallery.hairline).frame(width: 1)
            LiveControls(show: show, item: item, engine: engine, model: model)
                .frame(width: 290)
        }
        .background(LivePalette.base)
        .animation(.easeOut(duration: 0.15), value: status.pauseReason)
        .animation(.easeOut(duration: 0.15), value: status.freeMode)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onKeyPress(.space) { engine.next(); return .handled }
        .onKeyPress(.rightArrow) { engine.next(); return .handled }
        .onKeyPress(.leftArrow) { engine.back(); return .handled }
        .onKeyPress(.return) {
            if status.transport == .running { engine.stop() } else { engine.go() }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "tTrRfFlLcCaAbB")) { press in
            switch press.characters.lowercased() {
            case "t": engine.tap()
            case "r": engine.resume()
            case "f": engine.setFreeMode(!status.freeMode)
            case "c": engine.perform(.take)
            case "a": engine.perform(.auto)
            case "b": engine.perform(.tapBeat)
            default: engine.toggleLoop()
            }
            return .handled
        }
        .onKeyPress(characters: .decimalDigits) { press in
            // Camera numbers go to preview ("1" then "2" quickly = camera 12); C cuts, A mixes.
            let now = Date()
            if now.timeIntervalSince(typedAt) > 0.8 { typed = "" }
            typedAt = now
            typed += press.characters
            if let n = Int(typed), show.camera(number: n) != nil {
                engine.perform(.previewCamera, camera: n)
            } else if let n = Int(press.characters), show.camera(number: n) != nil {
                typed = press.characters
                engine.perform(.previewCamera, camera: n)
            }
            return .handled
        }
        // Esc is the panic key: every output to display only. Leaving Live is ⌘L or Exit.
        .onExitCommand { engine.panic() }
        .sheet(isPresented: $model.cameraDownOpen) {
            CameraDownSheet(show: show, engine: engine, model: model)
        }
    }
}

/// Automation stopped because the director cut by hand.
extension LiveView {
    func reading(item: RundownItem, status: EngineStatus) -> CountdownReading {
        let p = model.project.properties
        return Countdown.reading(item: item, next: show.liveNext(status.cursor),
                                 position: status.secondsToNext == nil ? nil : status.position,
                                 secondsToNext: status.secondsToNext, settings: p.countdown, vocabulary: p.shots)
    }
}

/// Countdown across the top of Live Mode: next cut, next section and who is on standby.
struct LiveCountdownBar: View {
    let show: Show
    let reading: CountdownReading

    var body: some View {
        HStack(spacing: Space.xl) {
            field("NEXT CUT", reading.nextCut.map(liveClock) ?? "–", warn: (reading.nextCut ?? 99) <= 3)
            field("NEXT SECTION", reading.nextSection.map { "\($0.name)  \(liveClock($0.seconds))" } ?? "–", warn: false)
            if let id = reading.standbyCameraID, let cam = show.camera(id) {
                HStack(spacing: Space.s) {
                    Text("STANDBY").font(.ocTag).tracking(0.6).foregroundStyle(Gallery.amber)
                    CameraChip(camera: cam, size: 22)
                    Text(cam.displayName).font(.ocBodyStrong).foregroundStyle(Gallery.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
        .frame(height: 40)
        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func field(_ label: String, _ value: String, warn: Bool) -> some View {
        HStack(spacing: Space.s) {
            Text(label).font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
            Text(value).font(.readout(16, weight: .semibold)).foregroundStyle(warn ? Gallery.amber : Gallery.ink)
        }
    }
}

/// The next department calls and player cues, so they can be called on comms.
struct LiveCallsStrip: View {
    let show: Show
    let calls: [UpcomingCall]
    let timed: Bool

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(calls) { call in
                HStack(spacing: Space.s) {
                    Image(systemName: call.kind == .calls ? "megaphone" : "play.rectangle")
                        .foregroundStyle(call.kind == .calls ? Color(hex: "#F2C46D") : Color(hex: "#7FD3E8"))
                    Text(show.cueLabel(call.cue, kind: call.kind)).font(.ocBodyStrong).foregroundStyle(Gallery.ink).lineLimit(1)
                    Spacer(minLength: 0)
                    if timed, let s = call.inSeconds {
                        Text(liveClock(s)).font(.readout(13, weight: .semibold))
                            .foregroundStyle(s <= 5 ? Gallery.amber : Gallery.dim)
                    }
                }
                .padding(.horizontal, Space.m)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
                .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.m))
            }
        }
    }
}

struct PausedBanner: View {
    let reason: String
    let resume: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "pause.circle.fill").font(.system(size: 20)).foregroundStyle(Gallery.amber)
            VStack(alignment: .leading, spacing: 1) {
                Text("Automation paused").font(.system(size: 15, weight: .semibold)).foregroundStyle(Gallery.ink)
                Text("\(reason). OnCue follows the script but sends nothing until you resume.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
            Spacer()
            Button(action: resume) { Label("Resume", systemImage: "play.fill").padding(.horizontal, 6) }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .help("Resume automation (R)")
        }
        .padding(.horizontal, Space.l)
        .frame(height: 56)
        .background(Gallery.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.l))
        .overlay(RoundedRectangle(cornerRadius: Radius.l).strokeBorder(Gallery.amber.opacity(0.7), lineWidth: 1.5))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Toolbar

/// Live Mode's context in the window toolbar: LIVE, the song or segment, and the section on air.
struct LiveToolbarContext: View {
    let show: Show
    @ObservedObject var engine: EngineController

    var body: some View {
        let cursor = engine.status.cursor
        let item = show.item(cursor.itemID)
        let now = show.liveNow(cursor)
        let section = item?.sections.first { $0.id == now?.sectionID }
        let running = engine.status.transport == .running
        HStack(spacing: Space.m) {
            HStack(spacing: 6) {
                Circle().fill(running ? Gallery.tally : Gallery.faint).frame(width: 8, height: 8)
                Text(running ? "LIVE" : "STANDBY")
                    .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                    .foregroundStyle(running ? Gallery.tally : Gallery.dim)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background((running ? Gallery.tally : Gallery.dim).opacity(0.14), in: Capsule())
            VStack(alignment: .leading, spacing: 0) {
                Text(item?.title ?? "No item").font(.ocHeading).foregroundStyle(Gallery.ink)
                Text(section?.name ?? (cursor.isStandingBy ? "Standing by" : show.name))
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
        }
    }
}

/// Live Mode's status in the window toolbar: timing source, switcher, and Exit.
struct LiveToolbarStatus: View {
    let show: Show
    @ObservedObject var engine: EngineController
    @ObservedObject var model: WorkspaceModel
    @State private var switcherOpen = false
    @State private var timingOpen = false

    var body: some View {
        let status = engine.status
        HStack(spacing: Space.s) {
            Button { timingOpen = true } label: {
                StatusChip(symbol: timingSymbol(status.timing), label: "Timing · \(status.timing.label)",
                           value: timingValue(status),
                           warning: [.midiClock, .ltc, .mtc, .osc].contains(status.timing) && !status.timingSignal,
                           help: timingHelp(status) + " Click to switch method.")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $timingOpen, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow this song with").sectionLabel().padding(.bottom, 4)
                    ForEach(SyncMode.allCases) { mode in
                        Button {
                            timingOpen = false
                            let id = status.itemID
                            model.edit("Change Live Timing") { $0.updateItem(id) { $0.syncMode = mode } }
                        } label: {
                            HStack {
                                Text(mode.label).font(.ocBodyStrong).foregroundStyle(Gallery.ink)
                                Spacer()
                                if show.item(status.itemID)?.syncMode == mode {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Gallery.selection)
                                }
                            }
                            .padding(.horizontal, Space.s)
                            .frame(width: 220, height: 28)
                            .contentShape(Rectangle())
                            .interactive()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Space.m)
            }
            Button { switcherOpen = true } label: {
                StatusChip(symbol: status.switcherConnected ? "cable.connector" : "cable.connector.slash",
                           label: "Switcher · \(status.switcherName)",
                           value: switcherValue(status),
                           warning: !status.switcherConnected,
                           help: "Click to connect or disconnect")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $switcherOpen, arrowEdge: .bottom) {
                SwitcherPopover(engine: engine, model: model)
            }
            Button { model.exitLive() } label: { Label("Exit Live", systemImage: "xmark") }
                .labelStyle(.titleAndIcon)
                .buttonStyle(QuietButtonStyle())
                .help("Back to editing (⌘L). Automation stops; switchers keep their state.")
        }
    }

    private func timingSymbol(_ t: TimingSourceKind) -> String {
        switch t {
        case .manual: return "hand.tap"
        case .taps: return "hand.point.up.left"
        case .internalClock: return "clock"
        case .midiClock: return "pianokeys"
        case .ltc: return "waveform"
        case .mtc: return "pianokeys.inverse"
        case .osc: return "antenna.radiowaves.left.and.right"
        }
    }

    private func timingValue(_ s: EngineStatus) -> String {
        switch s.timing {
        case .manual: return "NEXT"
        case .taps, .internalClock:
            if s.timingSignal { return "Running · \(Int((s.tempo ?? 0).rounded())) BPM" }
            return s.timing == .taps ? "Tap or GO to run" : "Waiting for GO"
        case .midiClock:
            guard s.timingSignal else { return "No clock" }
            return s.tempo.map { String(format: "%.1f BPM", $0) } ?? "Receiving"
        case .ltc, .mtc:
            return s.timingSignal ? (s.timecode ?? "Receiving") : "No timecode"
        case .osc:
            return s.timingSignal ? "Receiving" : "No OSC position"
        }
    }

    private func timingHelp(_ s: EngineStatus) -> String {
        switch s.timing {
        case .manual: return "Shots change on NEXT (Space)."
        case .taps: return "Tap at each section (T); OnCue runs at the song's tempo between taps."
        case .internalClock: return "OnCue's own clock runs from GO (Return) at the item's tempo."
        case .midiClock: return "Following MIDI clock from the source set in Settings (This Mac). Start in Ableton starts the song."
        case .ltc: return "Following LTC on the audio input set in Settings (This Mac)."
        case .mtc: return "Following MIDI timecode from the MIDI clock source set in Settings (This Mac)."
        case .osc: return "Following /oncue/time (seconds) or /oncue/beat (quarter notes) sent to this Mac's OSC control port."
        }
    }

    private func switcherValue(_ s: EngineStatus) -> String {
        if s.switcherConnected {
            if let p = s.program, let v = s.preview { return "PGM \(p) · PVW \(v)" }
            return "Connected"
        }
        return s.switcherConnecting ? "Connecting…" : "Not connected"
    }
}

/// Connect or disconnect the main switcher from Live Mode.
struct SwitcherPopover: View {
    @ObservedObject var engine: EngineController
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let s = engine.status
        VStack(alignment: .leading, spacing: Space.s) {
            Text(s.switcherName).font(.ocHeading).foregroundStyle(Gallery.ink)
            MetaLine(parts: [s.switcherKind?.label ?? "No switcher", s.switcherHost])
            if s.switcherAssumed {
                Text("Companion does not report tally back: program and preview are what OnCue last set, and manual cuts cannot be detected.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if s.switcherConnected || s.switcherConnecting {
                    Button("Disconnect") { engine.disconnectSwitcher() }.buttonStyle(QuietButtonStyle())
                } else {
                    Button("Connect") { engine.connectSwitcher() }.buttonStyle(QuietButtonStyle(prominent: true))
                }
                Spacer()
                Button("Show Setup…") { model.exitLive(); model.switcherSetupOpen = true }
                    .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(Space.l)
        .frame(width: 300)
    }
}

struct StatusChip: View {
    let symbol: String
    let label: String
    let value: String
    var warning = false
    let help: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                .foregroundStyle(warning ? Gallery.amber : Gallery.dim)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Gallery.faint).lineLimit(1)
                Text(value).font(.ocLabel.monospacedDigit()).foregroundStyle(warning ? Gallery.amber : Gallery.ink).lineLimit(1)
            }
        }
        .padding(.horizontal, Space.s + 2)
        .frame(height: 30)
        .background(LivePalette.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        .help(help)
    }
}

// MARK: - NOW / NEXT

struct NowNextPanels: View {
    let show: Show
    let item: RundownItem?
    let cursor: LiveCursor
    let takenAt: Date?
    /// From the engine when a timing source is running: the real time to the next cut.
    let secondsToNext: Double?
    let now: Date

    var body: some View {
        let onAir = show.liveNow(cursor)
        let next = show.liveNext(cursor)
        let elapsed = takenAt.map { now.timeIntervalSince($0) }
        let planned: Double? = {
            guard let length = onAir?.lengthSeconds, let elapsed else { return nil }
            return length - elapsed
        }()
        let remaining = secondsToNext ?? planned
        HStack(spacing: Space.l) {
            LiveShotPanel(role: .current, show: show, item: item, row: onAir,
                          timeLabel: "On air", timeValue: elapsed.map(liveClock),
                          emptyText: "Standing by. Press NEXT to take the first shot.")
            LiveShotPanel(role: .next, show: show, item: item, row: next,
                          timeLabel: remaining == nil ? (next == nil ? "" : "On NEXT") : (secondsToNext != nil ? "Cut in" : (remaining! >= 0 ? "Planned in" : "Over plan")),
                          timeValue: remaining.map { $0 >= 0 ? liveClock($0) : "+" + liveClock(-$0) },
                          timeWarning: (remaining ?? 0) < 0,
                          emptyText: "End of \(item?.kind == .segment ? "segment" : "song")")
        }
        .frame(height: 290)
    }
}

func liveClock(_ s: Double) -> String {
    let v = max(s, 0)
    let m = Int(v) / 60
    let sec = v - Double(m * 60)
    return String(format: "%d:%04.1f", m, sec)
}

struct LiveShotPanel: View {
    let role: TallyState
    let show: Show
    let item: RundownItem?
    let row: ShotRow?
    let timeLabel: String
    let timeValue: String?
    var timeWarning = false
    let emptyText: String

    var body: some View {
        let camera = show.camera(row?.cue.cameraID)
        let accent = role.color
        VStack(alignment: .leading, spacing: 0) {
            // Role bar: tally tag, role, shot reference, clock.
            HStack(alignment: .center, spacing: Space.s) {
                TallyTag(state: role, live: true)
                Text(role == .current ? "NOW" : "NEXT")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(accent)
                if let row {
                    Text("Shot \(row.number)").font(.system(size: 13, weight: .medium)).foregroundStyle(Gallery.dim)
                    if let item {
                        Text(item.format(row.cue.at)).font(.readout(13)).foregroundStyle(Gallery.faint)
                    }
                }
                Spacer()
                if let timeValue {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(timeLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(Gallery.faint)
                        Text(timeValue)
                            .font(.system(size: 30, weight: .semibold).monospacedDigit())
                            .foregroundStyle(timeWarning ? Gallery.amber : Gallery.ink)
                            .contentTransition(.numericText())
                    }
                } else if !timeLabel.isEmpty {
                    Text(timeLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(Gallery.faint)
                }
            }
            .frame(height: 48)

            if let row {
                HStack(alignment: .center, spacing: Space.l + 4) {
                    LiveCameraBlock(camera: camera, missing: row.cue.cameraID != nil && camera == nil)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(camera?.displayName ?? "No camera")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(camera == nil ? Gallery.amber : Gallery.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let op = camera?.operatorName, !op.isEmpty {
                            Text(op).font(.system(size: 16, weight: .medium)).foregroundStyle(Gallery.dim)
                        }
                        if !row.cue.text.isEmpty {
                            Text(row.cue.text)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Gallery.ink)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                        if !row.cue.note.isEmpty {
                            Text(row.cue.note).font(.system(size: 14).italic()).foregroundStyle(Gallery.dim).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: Space.s) {
                    Pill(text: row.cue.transition == .cut ? "CUT" : "MIX",
                         color: row.cue.transition == .cut ? Gallery.dim : Gallery.selection,
                         filled: row.cue.transition == .auto)
                    if let length = row.lengthSeconds {
                        Text(String(format: "%.1f s planned", length)).font(.readout(12)).foregroundStyle(Gallery.faint)
                    }
                    Spacer()
                    if let section = item?.sections.first(where: { $0.id == row.sectionID }) {
                        Text(section.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Gallery.faint)
                    }
                }
            } else {
                Spacer()
                Text(emptyText).font(.system(size: 18, weight: .medium)).foregroundStyle(Gallery.faint)
                Spacer()
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.l)
        .padding(.top, Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [accent.opacity(row == nil ? 0 : 0.10), LivePalette.panel.opacity(0)],
                           startPoint: .top, endPoint: .center)
        )
        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l + 2))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l + 2))
        .overlay(RoundedRectangle(cornerRadius: Radius.l + 2)
            .strokeBorder(row == nil ? Gallery.hairline : accent.opacity(0.85), lineWidth: role == .next ? 3 : 2))
        .animation(.easeOut(duration: 0.15), value: row?.id)
    }
}

/// The camera on a NOW / NEXT card: its colour, the number large enough to read across a gallery.
struct LiveCameraBlock: View {
    let camera: Camera?
    let missing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.l)
                .fill(camera?.swiftUIColor ?? Gallery.key)
            if let camera {
                Text("\(camera.number)")
                    .font(.cameraNumeral(58))
                    .foregroundStyle(camera.inkColor)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
            } else {
                Image(systemName: missing ? "exclamationmark" : "questionmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Gallery.amber)
            }
        }
        .frame(width: 128, height: 112)
    }
}

// MARK: - Upcoming and cameras

struct UpcomingStrip: View {
    let show: Show
    let cursor: LiveCursor

    var body: some View {
        let upcoming = show.liveUpcoming(cursor, limit: 6)
        VStack(alignment: .leading, spacing: Space.s) {
            Text("After next").sectionLabel()
            if upcoming.isEmpty {
                Text("Nothing after next in this \(show.item(cursor.itemID)?.kind == .segment ? "segment" : "song").")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
                    .frame(height: 52, alignment: .leading)
            } else {
                HStack(spacing: Space.s) {
                    ForEach(upcoming) { row in
                        let cam = show.camera(row.cue.cameraID)
                        HStack(spacing: Space.s) {
                            CameraChip(camera: cam, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cam?.displayName ?? "No camera").font(.ocBodyStrong).foregroundStyle(Gallery.ink).lineLimit(1)
                                Text(row.cue.text.isEmpty ? "Shot \(row.number)" : row.cue.text)
                                    .font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.s)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.m))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(cam?.swiftUIColor ?? Gallery.key).frame(width: 3)
                                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.m, bottomLeadingRadius: Radius.m))
                        }
                    }
                }
            }
        }
    }
}

struct LiveCameraGrid: View {
    let show: Show
    let status: EngineStatus
    /// The camera to put on standby before its cut; its key flashes amber.
    var standby: UUID? = nil
    var flash = false
    @AppStorage("live.cameraView") private var view = "grid"

    var body: some View {
        let fromSwitcher = status.switcherConnected && status.program != nil
        let pgm: (Camera) -> Bool = { cam in
            fromSwitcher ? cam.input == status.program : cam.id == show.liveNow(status.cursor)?.cue.cameraID
        }
        let pvw: (Camera) -> Bool = { cam in
            fromSwitcher ? cam.input == status.preview : cam.id == show.liveNext(status.cursor)?.cue.cameraID
        }
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Cameras").sectionLabel()
                if !show.plot.markers.isEmpty {
                    Picker("Show", selection: $view) {
                        Text("Grid").tag("grid")
                        Text("Plot").tag("plot")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 110)
                    .help("Cameras as keys, or on the camera plot with the live and next cameras lit")
                }
                Spacer()
                Text(fromSwitcher ? (status.switcherAssumed ? "Tally as OnCue last set it" : "Tally from the switcher")
                     : "Tally follows the script")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            }
            if view == "plot" && !show.plot.markers.isEmpty {
                PlotCanvas(show: show, plot: show.plot, selected: nil, dragging: nil, turning: nil, printing: true,
                           live: show.sortedCameras.first(where: pgm)?.id, next: show.sortedCameras.first(where: pvw)?.id, tally: true)
                    .frame(minHeight: 260, maxHeight: 420)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.s)], alignment: .leading, spacing: Space.s) {
                    ForEach(show.sortedCameras) { cam in
                        SourceButton(camera: cam, tally: pgm(cam) ? .current : (pvw(cam) ? .next : .off),
                                     live: true, width: 150, height: 62, numeral: 28)
                            .overlay {
                                if cam.id == standby {
                                    RoundedRectangle(cornerRadius: Radius.m)
                                        .strokeBorder(Gallery.amber.opacity(flash ? 1 : 0.35), lineWidth: 3)
                                        .overlay(alignment: .topTrailing) {
                                            Text("STBY").font(.ocTag).tracking(0.5).foregroundStyle(.black)
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Gallery.amber, in: RoundedRectangle(cornerRadius: 3))
                                                .padding(5)
                                        }
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Controls

struct LiveControls: View {
    let show: Show
    let item: RundownItem?
    @ObservedObject var engine: EngineController
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let status = engine.status
        let cursor = status.cursor
        let now = show.liveNow(cursor)
        let running = status.transport == .running
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Switcher mode").sectionLabel()
            Picker("Mode", selection: Binding(get: { status.mode(show.mainOutput?.id) }, set: { engine.setMode($0) })) {
                Text("Display").tag(OutputMode.display)
                Text("Preview").tag(OutputMode.preview)
                Text("Cut").tag(OutputMode.cut)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("Display: OnCue only shows the calls. Preview: OnCue puts the next shot on preview; you cut. Cut: OnCue cuts on the script.")
            if status.mode(show.mainOutput?.id) != .display && !status.switcherConnected {
                Label("No switcher connected: nothing is sent.", systemImage: "exclamationmark.triangle.fill")
                    .font(.ocMeta).foregroundStyle(Gallery.amber)
            }

            if show.outputs.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(show.outputs.dropFirst()) { output in
                        HStack(spacing: Space.s) {
                            Text(output.name).font(.ocLabel).foregroundStyle(Gallery.dim).lineLimit(1)
                            Spacer(minLength: 4)
                            Picker(output.name, selection: Binding(get: { status.mode(output.id) },
                                                                   set: { engine.setMode($0, for: output.id) })) {
                                Text("Off").tag(OutputMode.display)
                                Text("Pvw").tag(OutputMode.preview)
                                Text("Cut").tag(OutputMode.cut)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                            .frame(width: 132)
                        }
                    }
                }
            }

            HStack(spacing: Space.s) {
                ToolToggle(title: "Free", symbol: "hand.raised", on: status.freeMode, color: Gallery.amber,
                           help: "Free mode (F): the script holds; you cut. Hints show cameras not used lately.") {
                    engine.setFreeMode(!status.freeMode)
                }
                ToolToggle(title: "Loop", symbol: "repeat", on: status.loopSectionID != nil, color: Gallery.selection,
                           help: "Loop the current section until released (L)") {
                    engine.toggleLoop()
                }
                ToolToggle(title: "Cam down", symbol: "video.slash", on: false, color: Gallery.tally,
                           help: "Move a dead camera's upcoming shots to another camera") {
                    model.cameraDownOpen = true
                }
            }
            if !show.settings.monitors.isEmpty {
                MonitorsToggle(windows: model.monitors, model: model, engine: engine, show: show)
            }
            Button { engine.panic() } label: {
                Label("Display only (Esc)", systemImage: "exclamationmark.octagon")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(LiveKeyStyle(color: Gallery.tally, subtle: true))
            .help("Panic: every output drops to display only. Switchers keep what is on air.")

            if status.timing != .manual {
                Button { running ? engine.stop() : engine.go() } label: {
                    Label(running ? "Stop" : "GO", systemImage: running ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(LiveKeyStyle(color: running ? Gallery.dim : Gallery.tally, subtle: running))
                .help(running ? "Stop following the timing source (Return)" : "Start following the timing source (Return)")
            }

            Button { engine.next() } label: {
                VStack(spacing: 6) {
                    Text("NEXT").font(.system(size: 24, weight: .heavy)).tracking(3)
                    if let next = show.liveNext(cursor) {
                        let cam = show.camera(next.cue.cameraID)
                        HStack(spacing: 6) {
                            CameraChip(camera: cam, size: 18)
                            Text(cam?.displayName ?? "No camera").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Gallery.ink)
                    }
                    Text("Space").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Gallery.faint)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
            .buttonStyle(LiveKeyStyle(color: Gallery.next))
            .disabled(show.liveNext(cursor) == nil)
            .help("Take the next shot now (Space or →)")

            HStack(spacing: Space.s) {
                Button { engine.back() } label: {
                    Label("Back", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(LiveKeyStyle(color: Gallery.dim, subtle: true))
                .disabled(cursor.isStandingBy)
                .help("Back one shot (←)")
                if status.timing == .taps {
                    Button { engine.tap() } label: {
                        Label("Tap", systemImage: "hand.point.up.left").frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(LiveKeyStyle(color: Gallery.selection))
                    .help("Next section starts now (T)")
                }
            }

            if let item, !item.sections.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Sections").sectionLabel()
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(item.sortedSections) { section in
                                let active = now?.sectionID == section.id
                                Button { engine.jump(toSection: section.id) } label: {
                                    HStack {
                                        Text(section.name).font(.ocBodyStrong)
                                        Spacer()
                                        Text(item.format(section.at)).font(.readout(11)).foregroundStyle(Gallery.faint)
                                    }
                                    .foregroundStyle(active ? Gallery.ink : Gallery.dim)
                                    .padding(.horizontal, Space.s)
                                    .frame(height: 28)
                                    .background(active ? LivePalette.raised : Color.clear, in: RoundedRectangle(cornerRadius: Radius.s))
                                    .overlay(alignment: .leading) {
                                        if active { Rectangle().fill(Gallery.tally).frame(width: 2) }
                                    }
                                    .contentShape(Rectangle())
                                    .interactive()
                                }
                                .buttonStyle(.plain)
                                .help("Jump to \(section.name): takes its first shot")
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Running order").sectionLabel()
                HStack(spacing: Space.s) {
                    Button { engine.moveItem(by: -1) } label: { Label("Previous", systemImage: "backward.end") }
                        .help("Previous song or segment (⌘[)")
                    Button { engine.moveItem(by: 1) } label: { Label("Next item", systemImage: "forward.end") }
                        .help("Next song or segment (⌘])")
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LivePalette.panel)
    }
}

/// Large, high-contrast key for live operation.
struct LiveKeyStyle: ButtonStyle {
    let color: Color
    var subtle = false

    func makeBody(configuration: Configuration) -> some View {
        LiveKey(configuration: configuration, color: color, subtle: subtle)
    }

    private struct LiveKey: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        let subtle: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(subtle ? Gallery.ink : color)
                .background(fill, in: RoundedRectangle(cornerRadius: Radius.l))
                .overlay(RoundedRectangle(cornerRadius: Radius.l)
                    .strokeBorder(subtle ? Gallery.hairline : color.opacity(enabled ? 0.9 : 0.3), lineWidth: subtle ? 1 : 2))
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }

        private var fill: Color {
            if subtle { return configuration.isPressed ? Gallery.pressed : (hovering ? LivePalette.raised : Color.clear) }
            return color.opacity(configuration.isPressed ? 0.28 : (hovering ? 0.18 : 0.12))
        }
    }
}


/// Small toggle button for Live tools (free mode, loop, camera down).
struct ToolToggle: View {
    let title: String
    let symbol: String
    let on: Bool
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(on ? color : Gallery.dim)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(on ? color.opacity(0.16) : LivePalette.raised, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(on ? color.opacity(0.8) : Gallery.hairline, lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Free mode: the script holds and the director cuts; cameras not used lately are suggested.
struct FreeModeBanner: View {
    let show: Show
    let hints: [UUID]
    let leave: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "hand.raised.fill").font(.system(size: 18)).foregroundStyle(Gallery.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("Free mode").font(.system(size: 15, weight: .semibold)).foregroundStyle(Gallery.ink)
                HStack(spacing: 6) {
                    Text(hints.isEmpty ? "The script holds; OnCue sends nothing. Your cuts are logged." : "Not used lately:")
                        .font(.ocMeta).foregroundStyle(Gallery.dim)
                    ForEach(hints, id: \.self) { id in
                        if let cam = show.camera(id) {
                            HStack(spacing: 4) {
                                CameraChip(camera: cam, size: 16)
                                Text(cam.displayName).font(.ocLabel).foregroundStyle(Gallery.ink)
                            }
                        }
                    }
                }
            }
            Spacer()
            Button(action: leave) { Label("Back to script", systemImage: "arrow.uturn.forward").padding(.horizontal, 6) }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .help("Leave free mode (F): the script continues from where it held")
        }
        .padding(.horizontal, Space.l)
        .frame(height: 56)
        .background(Gallery.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.l))
        .overlay(RoundedRectangle(cornerRadius: Radius.l).strokeBorder(Gallery.amber.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Camera down: move a dead camera's next shots to another camera. Asks how many.
struct CameraDownSheet: View {
    let show: Show
    @ObservedObject var engine: EngineController
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var down: UUID?
    @State private var replacement: UUID?
    @State private var count = 1

    var body: some View {
        let cursor = engine.status.cursor
        let total = down.map { show.upcomingShotCount(camera: $0, from: cursor) } ?? 0
        let inSong = down.map { show.upcomingShotCount(camera: $0, from: cursor, sameItemOnly: true) } ?? 0
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Camera down").font(.ocTitle).foregroundStyle(Gallery.ink)
            Text("Move a camera's upcoming shots to another camera. The shot on air is not touched; Undo puts them back.")
                .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            PropertyRow(label: "Down") { cameraPicker($down) }
            PropertyRow(label: "Move to") { cameraPicker($replacement, excluding: down) }
            PropertyRow(label: "Shots") {
                HStack(spacing: Space.s) {
                    Stepper(value: $count, in: 0...max(total, 0)) {
                        Text("\(count)").font(.readout(15, weight: .semibold)).foregroundStyle(Gallery.ink)
                    }
                    .disabled(down == nil)
                    Text("of \(total) upcoming (\(inSong) in this song)").font(.ocMeta).foregroundStyle(Gallery.faint)
                }
            }
            HStack {
                Button("This song") { count = inSong }.buttonStyle(QuietButtonStyle()).disabled(down == nil)
                Button("All upcoming") { count = total }.buttonStyle(QuietButtonStyle()).disabled(down == nil)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                Button("Move \(count) \(count == 1 ? "shot" : "shots")") {
                    if let down, let replacement {
                        model.edit("Camera Down") { $0.reassignUpcomingShots(from: down, to: replacement, count: count, after: cursor) }
                    }
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .disabled(down == nil || replacement == nil || count == 0)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 480)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onChange(of: down) { _, new in
            guard let new else { return }
            count = show.upcomingShotCount(camera: new, from: cursor, sameItemOnly: true)
        }
        .onAppear {
            down = show.liveNext(cursor)?.cue.cameraID
        }
    }

    private func cameraPicker(_ selection: Binding<UUID?>, excluding: UUID? = nil) -> some View {
        Picker("", selection: selection) {
            Text("Choose…").tag(UUID?.none)
            ForEach(show.sortedCameras.filter { $0.id != excluding }) { cam in
                Text("\(cam.number)  \(cam.label)").tag(UUID?.some(cam.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 260)
    }
}


/// Rundown timing for timed segments: planned against elapsed, the hard out, the show over or under.
struct LiveRundownStrip: View {
    let timing: RundownTiming

    var body: some View {
        HStack(spacing: Space.xl) {
            if let planned = timing.planned {
                metric("Planned", clockText(planned), Gallery.dim)
                metric("Elapsed", timing.elapsed.map(clockText) ?? "–", Gallery.ink)
                if let left = timing.remaining {
                    if left >= 0 {
                        metric("Left", clockText(left), left < 30 ? Gallery.amber : Gallery.ink)
                    } else {
                        metric("Over", clockText(-left), Gallery.tally)
                    }
                }
            }
            if let out = timing.hardOutIn {
                metric("Hard out", out >= 0 ? "in " + clockText(out) : clockText(-out) + " past", out < 60 ? Gallery.tally : (out < 300 ? Gallery.amber : Gallery.ink))
            }
            Spacer(minLength: 0)
            if timing.finishedPlanned > 0 {
                let off = timing.showOffset
                metric("Show", abs(off) < 1 ? "On time" : (off > 0 ? "+" + clockText(off) + " over" : "−" + clockText(-off) + " under"),
                       off > 30 ? Gallery.amber : Gallery.ink)
            }
            if let next = timing.nextHardOut {
                let time = next.deadline.formatted(date: .omitted, time: .shortened)
                metric("\(next.title) out \(time)",
                       next.margin >= 0 ? clockText(next.margin) + " spare" : clockText(-next.margin) + " late",
                       next.margin < 0 ? Gallery.tally : (next.margin < 120 ? Gallery.amber : Gallery.next))
            } else if let end = timing.forecastEnd {
                metric("Ends about", end.formatted(date: .omitted, time: .shortened), Gallery.dim)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l))
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
            Text(value).font(.readout(20, weight: .semibold)).foregroundStyle(color).lineLimit(1)
        }
    }
}


/// Opens or closes the operator monitors set up in Show Setup › Monitors.
struct MonitorsToggle: View {
    @ObservedObject var windows: MonitorWindows
    let model: WorkspaceModel
    let engine: EngineController
    let show: Show

    var body: some View {
        ToolToggle(title: windows.isOpen ? "Monitors on" : "Monitors (\(show.settings.monitors.count))", symbol: "display.2",
                   on: windows.isOpen, color: Gallery.selection,
                   help: "Show the crew views on the displays chosen in Show Setup") {
            if windows.isOpen { windows.close() } else { windows.open(model: model, engine: engine, show: show) }
        }
    }
}


/// Backup Mac: following the main Mac, or the main Mac is gone and this one can take the show.
struct BackupBanner: View {
    let linked: Bool
    let takeOver: () -> Void

    var body: some View {
        HStack(spacing: Space.m) {
            Image(systemName: linked ? "link" : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(linked ? Gallery.next : Gallery.well)
            VStack(alignment: .leading, spacing: 1) {
                Text(linked ? "Backup: following the main Mac" : "Main Mac lost")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(linked ? Gallery.ink : Gallery.well)
                Text(linked ? "Nothing is sent from this Mac. Take over only if the main Mac fails."
                            : "This Mac is not sending anything. Take over to run the show from here.")
                    .font(.ocMeta)
                    .foregroundStyle(linked ? Gallery.dim : Gallery.well.opacity(0.8))
            }
            Spacer()
            Button("Take Over", action: takeOver)
                .buttonStyle(LiveKeyStyle(color: linked ? Gallery.amber : Gallery.well, subtle: linked))
                .frame(width: 130)
                .help("Start sending to the switchers from this Mac, in the modes the main Mac was using")
        }
        .padding(Space.m)
        .background(linked ? LivePalette.panel : Gallery.tally, in: RoundedRectangle(cornerRadius: Radius.l))
    }
}
