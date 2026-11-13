import Foundation

// The show engine: follows a playhead through a song or segment and decides what the switchers,
// OSC receivers and PTZ cameras should do. It is pure logic: callers feed it positions (from a
// timing source) and switcher reports, and it returns commands. Times are monotonic seconds
// supplied by the caller, so every behaviour is testable without a clock or hardware.
//
// Outputs: the first output is the main one (its shots are NOW / NEXT). Every output has its own
// shots track or mirrors the main cut, and its own mode. Cameras can sit on sub-switchers that
// feed another switcher: the sub-switcher takes the camera, and the switcher above takes the
// sub-switcher's feed.

/// What the engine asks devices to do, in order.
public enum EngineCommand: Equatable {
    case preview(switcher: UUID, input: Int)
    /// Cut preview to program.
    case cut(switcher: UUID)
    /// Mix preview to program. Commands after it wait for the transition to end.
    case auto(switcher: UUID)
    /// Put an input straight on program (sub-switchers feeding another switcher).
    case program(switcher: UUID, input: Int)
    case aux(switcher: UUID, aux: Int, input: Int)
    case macro(switcher: UUID, index: Int)
    case dsk(switcher: UUID, index: Int, on: Bool)
    case dskAuto(switcher: UUID, index: Int)
    case key(switcher: UUID, index: Int, on: Bool)
    case fadeToBlack(switcher: UUID)
    case osc(target: UUID, address: String, args: String)
    case ptz(camera: UUID, preset: Int)
    case send(target: UUID, payload: DeviceSend)
}

public enum EngineTransport: Equatable {
    /// Loaded, not started: nothing taken yet (or stopped and reset).
    case standby
    /// Following the timing source.
    case running
    /// Halted where it is.
    case stopped
}

/// Why automation stopped sending commands.
public struct EnginePause: Equatable {
    public let reason: String
}

/// A shot the engine took on an output (for the switch log).
public struct EngineTake: Equatable {
    public let outputID: UUID
    public let itemID: UUID
    public let shotNumber: Int
    public let cameraID: UUID?
    public let time: Double
}

public final class ShowEngine {
    public private(set) var show: Show
    public private(set) var cursor: LiveCursor
    /// Playhead in the item's time base (beats, seconds or step).
    public private(set) var position: Double = 0
    public private(set) var transport: EngineTransport = .standby
    public private(set) var modes: [UUID: OutputMode] = [:]
    public private(set) var pause: EnginePause?
    /// Unscripted moment: the script holds still and nothing is sent; the director cuts.
    public private(set) var freeMode = false
    /// The section being looped (repeated until released).
    public private(set) var loopSectionID: UUID?
    /// When the shot on air was taken (caller's monotonic seconds).
    public private(set) var takenAt: Double?
    /// Takes since the caller last drained them (for the switch log).
    public private(set) var takes: [EngineTake] = []

    /// Raw timing-source position and the offset that maps it to the playhead
    /// (NEXT, jumps, loops and free mode move the playhead away from the raw source).
    private var lastRaw: Double = 0
    private var offset: Double = 0
    /// Last playhead position at which non-shot cues were fired.
    private var firedThrough: Double = -1
    /// Current shot index per non-main output.
    private var outputIndex: [UUID: Int] = [:]
    /// Program inputs OnCue expects after its own cuts, per switcher, each until a deadline.
    private var expected: [(switcher: UUID, input: Int, until: Double)] = []
    /// Item to load after the current call returns (control track).
    private var pendingLoad: UUID?

    public init(show: Show, itemID: UUID, mode: OutputMode = .display) {
        self.show = show
        self.cursor = LiveCursor(itemID: itemID)
        for output in show.outputs { modes[output.id] = mode }
    }

    // MARK: - Reading

    public var item: RundownItem? { show.item(cursor.itemID) }
    public var mainOutput: OutputConfig? { show.mainOutput }
    public var rows: [ShotRow] { show.shotRows(forItem: cursor.itemID) }
    public var onAir: ShotRow? { show.liveNow(cursor) }
    public var next: ShotRow? { show.liveNext(cursor) }
    public var isPaused: Bool { pause != nil }
    /// The main output's mode.
    public var mode: OutputMode { mainOutput.flatMap { modes[$0.id] } ?? .display }
    public func mode(of outputID: UUID) -> OutputMode { modes[outputID] ?? .display }

    /// Shots of an output in the current item: its own track, or the main shots when mirroring.
    public func rows(for output: OutputConfig) -> [ShotRow] {
        if output.id == mainOutput?.id || output.mirrorMain { return rows }
        guard let item, let track = item.shotsTrack(for: output.id) else { return [] }
        return track.cues.sorted { $0.at < $1.at }.enumerated().map { k, cue in
            ShotRow(cue: cue, number: k + 1, sectionID: item.section(at: cue.at)?.id, lengthSeconds: nil, issues: [])
        }
    }

    /// The switcher input that shows a camera on the main output's switcher (nil if not routable).
    public func input(of row: ShotRow?) -> Int? {
        guard let main = mainOutput, let switcherID = main.switcherID else { return nil }
        return route(row?.cue.cameraID, to: switcherID)?.input
    }

    /// Seconds until the next shot, from the playhead and the item's tempo (nil in NEXT order).
    public func secondsToNext() -> Double? {
        guard let item, item.timeBase != .order, let next else { return nil }
        return item.seconds(for: max(next.cue.at - position, 0))
    }

    /// Drains the takes recorded since the last call.
    public func drainTakes() -> [EngineTake] {
        defer { takes.removeAll() }
        return takes
    }

    // MARK: - Routing

    /// How a camera reaches a switcher: the input on that switcher, plus the sub-switchers that
    /// must take it on the way (sub-switcher id, input on it), lowest first.
    public struct Route: Equatable {
        public let input: Int
        public let feeds: [(switcher: UUID, input: Int)]
        public static func == (a: Route, b: Route) -> Bool {
            a.input == b.input && a.feeds.map(\.switcher) == b.feeds.map(\.switcher) && a.feeds.map(\.input) == b.feeds.map(\.input)
        }
    }

    public func route(_ cameraID: UUID?, to switcherID: UUID) -> Route? {
        guard let camera = show.camera(cameraID) else { return nil }
        // A camera split to several switchers has its own input on each.
        if let direct = camera.extraInputs.first(where: { $0.switcherID == switcherID }), direct.input > 0 {
            return Route(input: direct.input, feeds: [])
        }
        guard camera.input > 0 else { return nil }
        var current = camera.switcherID ?? mainOutput?.switcherID ?? switcherID
        var input = camera.input
        var feeds: [(switcher: UUID, input: Int)] = []
        var guardCount = 0
        while current != switcherID {
            guard let sub = show.switcher(current), let parent = sub.parentID, sub.feedInput > 0, guardCount < 8 else { return nil }
            feeds.append((current, input))
            input = sub.feedInput
            current = parent
            guardCount += 1
        }
        return Route(input: input, feeds: feeds)
    }

    // MARK: - Script changes

    /// The show was edited while live: keep the position and recompute the shots on air.
    public func update(show newShow: Show) {
        show = newShow
        for output in show.outputs where modes[output.id] == nil { modes[output.id] = .display }
        guard show.item(cursor.itemID) != nil else {
            if let first = show.items.first { cursor = LiveCursor(itemID: first.id) }
            return
        }
        if transport != .standby {
            cursor.index = index(at: position, in: rows) ?? -1
        } else {
            cursor.index = min(cursor.index, rows.count - 1)
        }
    }

    // MARK: - Transport

    /// Loads a song or segment, standing by at its start. Primes preview with its first shot.
    public func load(itemID: UUID, now: Double) -> [EngineCommand] {
        guard show.item(itemID) != nil else { return [] }
        cursor = LiveCursor(itemID: itemID)
        transport = .standby
        position = 0
        offset = lastRaw
        firedThrough = -1
        outputIndex.removeAll()
        loopSectionID = nil
        takenAt = nil
        expected.removeAll()
        return primePreview()
    }

    /// GO: start following the timing source from the current position.
    public func start(now: Double) -> [EngineCommand] {
        transport = .running
        return moveTo(position, now: now)
    }

    public func stop() {
        transport = .stopped
    }

    /// Back to the top of the item, standing by (MIDI Start: the song starts from its beginning).
    public func rewind() {
        position = 0
        cursor.index = -1
        offset = lastRaw
        firedThrough = -1
        outputIndex.removeAll()
        takenAt = nil
        transport = .standby
    }

    /// The timing source starts counting from `raw` (internal clock started, MIDI Start):
    /// the playhead keeps its place.
    public func syncRaw(_ raw: Double) {
        lastRaw = raw
        offset = raw - position
    }

    /// The timing source moved. Takes the shots the playhead is now in, fires cues it passed.
    public func setPosition(raw: Double, now: Double) -> [EngineCommand] {
        lastRaw = raw
        guard transport == .running, !freeMode else { return [] }
        var p = raw - offset
        if let loopID = loopSectionID, let span = show.sectionSpans(forItem: cursor.itemID).first(where: { $0.id == loopID }) {
            let length = span.end - span.start
            if length > 0 {
                while p >= span.end - 1e-9 {
                    offset += length
                    p -= length
                    firedThrough = span.start - 1e-9
                }
            }
        }
        return moveTo(max(p, 0), now: now)
    }

    /// Positions in the item's time base for callers without a separate raw source (tests).
    public func setPosition(_ p: Double, now: Double) -> [EngineCommand] {
        setPosition(raw: p + offset, now: now)
    }

    /// Backup Mac: adopt the main Mac's place in the show. Returns what the main Mac would have
    /// sent (the controller drops it while following), so the cues it passed count as fired.
    public func follow(itemID: UUID, index: Int, position p: Double, transport t: EngineTransport,
                       freeMode f: Bool, loopSectionID l: UUID?, now: Double) -> [EngineCommand] {
        var out: [EngineCommand] = []
        if cursor.itemID != itemID {
            guard show.item(itemID) != nil else { return [] }
            out += load(itemID: itemID, now: now)
        }
        freeMode = f
        loopSectionID = l
        if t == .running {
            transport = .running
            let target = rows.indices.contains(index) ? max(p, rows[index].cue.at) : p
            out += jumpPlayhead(to: target, now: now)
        } else {
            transport = t
            position = p
            offset = lastRaw - p
        }
        return out
    }

    /// NEXT: take the next shot now, moving the playhead to it.
    public func next(now: Double) -> [EngineCommand] {
        let target = cursor.index + 1
        guard rows.indices.contains(target) else { return [] }
        if transport != .running { transport = .running }
        return jumpPlayhead(to: rows[target].cue.at, now: now)
    }

    /// Back one shot.
    public func back(now: Double) -> [EngineCommand] {
        let target = cursor.index - 1
        guard target >= -1 else { return [] }
        if target == -1 {
            cursor.index = -1
            position = 0
            offset = lastRaw
            firedThrough = -1
            outputIndex.removeAll()
            takenAt = nil
            transport = .standby
            return primePreview()
        }
        return jumpPlayhead(to: rows[target].cue.at, now: now, forward: false)
    }

    /// Section tap: the playhead jumps to the start of the next section.
    public func tapSection(now: Double) -> [EngineCommand] {
        guard let item else { return [] }
        let sections = item.sortedSections
        let nextSection: SongSection?
        if transport != .running && cursor.index < 0 {
            nextSection = sections.first
        } else {
            nextSection = sections.first { $0.at > position + 1e-6 }
        }
        guard let section = nextSection else { return [] }
        if transport != .running { transport = .running }
        return jumpPlayhead(to: section.at, now: now)
    }

    /// Jump to a section and take its first shot.
    public func jump(toSection sectionID: UUID, now: Double) -> [EngineCommand] {
        guard let section = item?.sections.first(where: { $0.id == sectionID }) else { return [] }
        if transport != .running { transport = .running }
        return jumpPlayhead(to: section.at, now: now, forward: section.at > position)
    }

    /// Previous or next song or segment, standing by.
    public func moveItem(by delta: Int, now: Double) -> [EngineCommand] {
        var c = cursor
        guard show.moveItem(&c, by: delta) else { return [] }
        return load(itemID: c.itemID, now: now)
    }

    // MARK: - Loop, free mode, panic

    /// Loop the section the playhead is in until released (extra chorus, long solo).
    public func toggleLoop() {
        if loopSectionID != nil {
            loopSectionID = nil
        } else {
            loopSectionID = item?.section(at: position)?.id
        }
    }

    /// Free mode: the script holds still and nothing is sent; leaving it continues from where
    /// the script stopped.
    public func setFreeMode(_ on: Bool) -> [EngineCommand] {
        guard on != freeMode else { return [] }
        freeMode = on
        if !on {
            offset = lastRaw - position
            return primePreview()
        }
        return []
    }

    /// Panic: every output drops to display only. Nothing is sent from now on until a mode is chosen.
    public func panic() {
        for key in modes.keys { modes[key] = .display }
        pause = nil
    }

    // MARK: - Modes and pause

    /// Sets the main output's mode.
    public func setMode(_ newMode: OutputMode) -> [EngineCommand] {
        guard let main = mainOutput else { return [] }
        return setMode(newMode, for: main.id)
    }

    public func setMode(_ newMode: OutputMode, for outputID: UUID) -> [EngineCommand] {
        modes[outputID] = newMode
        return primePreview()
    }

    /// A switcher's program changed. In Auto cut, a change OnCue did not ask for is a manual cut:
    /// automation pauses until the director resumes it.
    public func programChanged(to input: Int, on switcherID: UUID, now: Double) {
        expected.removeAll { $0.until < now }
        if let k = expected.firstIndex(where: { $0.switcher == switcherID && $0.input == input }) {
            expected.remove(at: k)
            return
        }
        guard transport == .running, pause == nil, !freeMode else { return }
        let cutOutputs = show.outputs.filter { $0.switcherID == switcherID && $0.bus == .program && mode(of: $0.id) == .cut }
        guard !cutOutputs.isEmpty else { return }
        for output in cutOutputs {
            let current = output.id == mainOutput?.id ? onAir : currentRow(for: output)
            if route(current?.cue.cameraID, to: switcherID)?.input == input { return }
        }
        let name = show.switcher(switcherID)?.name ?? "the switcher"
        pause = EnginePause(reason: "Manual cut to input \(input) on \(name)")
        expected.removeAll()
    }

    /// Main switcher shorthand (tests and single-switcher shows).
    public func programChanged(to input: Int, now: Double) {
        guard let s = mainOutput?.switcherID else { return }
        programChanged(to: input, on: s, now: now)
    }

    /// The controller sent a cut or mix to `input` (what was on preview at that moment).
    public func noteTransitionSent(to input: Int, on switcherID: UUID, mix: Bool, now: Double) {
        expected.append((switcherID, input, now + (mix ? 6 : 2)))
    }

    public func pauseAutomation(reason: String) {
        pause = EnginePause(reason: reason)
    }

    /// Resume after a manual cut: the next scripted shots go to preview, cuts continue from the
    /// next shot on.
    public func resume() -> [EngineCommand] {
        pause = nil
        return primePreview()
    }

    // MARK: - Internals

    func index(at p: Double, in rows: [ShotRow]) -> Int? {
        rows.lastIndex { $0.cue.at <= p + 1e-6 }
    }

    func index(at p: Double) -> Int? { index(at: p, in: rows) }

    private func currentRow(for output: OutputConfig) -> ShotRow? {
        let r = rows(for: output)
        guard let k = outputIndex[output.id], r.indices.contains(k) else { return nil }
        return r[k]
    }

    private var automationOn: Bool { pause == nil && !freeMode }

    /// Explicit move (NEXT, back, tap, jump): the playhead goes to `target` and the raw source is
    /// re-mapped so it continues from there.
    private func jumpPlayhead(to target: Double, now: Double, forward: Bool = true) -> [EngineCommand] {
        offset = lastRaw - target
        if !forward { firedThrough = target }
        return moveTo(target, now: now)
    }

    private func moveTo(_ p: Double, now: Double) -> [EngineCommand] {
        position = p
        guard transport == .running else { return [] }
        var commands: [EngineCommand] = []
        // Main output.
        if let target = index(at: p, in: rows), target != cursor.index {
            commands += take(target, now: now)
        } else if index(at: p, in: rows) == nil, cursor.index != -1 {
            cursor.index = -1
        }
        // Other outputs.
        for output in show.outputs.dropFirst() {
            let r = rows(for: output)
            let target = index(at: p, in: r)
            if let target, target != outputIndex[output.id] {
                outputIndex[output.id] = target
                commands += takeOnOutput(output, rows: r, index: target, now: now)
            }
        }
        // Non-shot cues passed since the last move (forward only).
        if p > firedThrough {
            commands += fireCues(after: firedThrough, through: p, now: now)
            firedThrough = p
        } else if p < firedThrough {
            // The source went back (MIDI Song Position): cues ahead fire again when reached.
            firedThrough = p
        }
        if let load = pendingLoad {
            pendingLoad = nil
            commands += self.load(itemID: load, now: now)
        }
        return commands
    }

    private func take(_ index: Int, now: Double) -> [EngineCommand] {
        cursor.index = index
        takenAt = now
        let shot = rows[index]
        guard let main = mainOutput else { return [] }
        takes.append(EngineTake(outputID: main.id, itemID: cursor.itemID, shotNumber: shot.number,
                                cameraID: shot.cue.cameraID, time: now))
        guard automationOn else { return [] }
        let following = rows.indices.contains(index + 1) ? rows[index + 1] : nil
        var commands = cutCommands(output: main, shot: shot, now: now)
        if mode(of: main.id) != .display, let switcherID = main.switcherID, main.bus == .program {
            commands += previewCommands(for: following, on: switcherID, after: shot)
        }
        // Mirroring outputs follow the main cut.
        for output in show.outputs.dropFirst() where output.mirrorMain {
            outputIndex[output.id] = index
            commands += takeOnOutput(output, rows: rows, index: index, now: now)
        }
        return commands
    }

    private func takeOnOutput(_ output: OutputConfig, rows r: [ShotRow], index: Int, now: Double) -> [EngineCommand] {
        let shot = r[index]
        takes.append(EngineTake(outputID: output.id, itemID: cursor.itemID, shotNumber: shot.number,
                                cameraID: shot.cue.cameraID, time: now))
        guard automationOn else { return [] }
        var commands = cutCommands(output: output, shot: shot, now: now)
        if mode(of: output.id) != .display, let switcherID = output.switcherID, output.bus == .program {
            let following = r.indices.contains(index + 1) ? r[index + 1] : nil
            commands += previewCommands(for: following, on: switcherID, after: shot)
        }
        return commands
    }

    /// Cut (or mix, or aux) an output to a shot, routing through sub-switchers.
    private func cutCommands(output: OutputConfig, shot: ShotRow, now: Double) -> [EngineCommand] {
        guard mode(of: output.id) == .cut, let switcherID = output.switcherID,
              let shotRoute = route(shot.cue.cameraID, to: switcherID) else { return [] }
        var commands: [EngineCommand] = shotRoute.feeds.map { .program(switcher: $0.switcher, input: $0.input) }
        switch output.bus {
        case .aux:
            commands.append(.aux(switcher: switcherID, aux: output.auxIndex, input: shotRoute.input))
        case .program:
            let mix = shot.cue.transition == .auto
            commands += [.preview(switcher: switcherID, input: shotRoute.input), mix ? .auto(switcher: switcherID) : .cut(switcher: switcherID)]
            expected.append((switcherID, shotRoute.input, now + 10))
        }
        return commands
    }

    /// Puts the next shot on a switcher's preview. A shot on a sub-switcher that is not on air goes
    /// straight to that sub-switcher's program, so the main preview shows it.
    private func previewCommands(for row: ShotRow?, on switcherID: UUID, after current: ShotRow?) -> [EngineCommand] {
        guard let row, let nextRoute = route(row.cue.cameraID, to: switcherID) else { return [] }
        let onAirRoute = route(current?.cue.cameraID, to: switcherID)
        if let lowest = nextRoute.feeds.first, onAirRoute?.input == nextRoute.input {
            // Same sub-switcher feed is on air: prepare the camera on the sub-switcher's own preview.
            return [.preview(switcher: lowest.switcher, input: lowest.input)]
        }
        let feeds: [EngineCommand] = nextRoute.feeds.map { .program(switcher: $0.switcher, input: $0.input) }
        return feeds + [.preview(switcher: switcherID, input: nextRoute.input)]
    }

    /// Puts the next scripted shots on preview (Auto preview and Auto cut).
    private func primePreview() -> [EngineCommand] {
        guard automationOn else { return [] }
        var commands: [EngineCommand] = []
        for output in show.outputs where mode(of: output.id) != .display && output.bus == .program {
            guard let switcherID = output.switcherID else { continue }
            if output.id == mainOutput?.id || output.mirrorMain {
                commands += previewCommands(for: next, on: switcherID, after: onAir)
            } else {
                let r = rows(for: output)
                let k = (outputIndex[output.id] ?? -1) + 1
                if r.indices.contains(k) {
                    commands += previewCommands(for: r[k], on: switcherID, after: currentRow(for: output))
                }
            }
        }
        return commands
    }

    /// FX, control, OSC and PTZ cues in (from, through].
    private func fireCues(after from: Double, through to: Double, now: Double) -> [EngineCommand] {
        guard let item, !freeMode else { return [] }
        var commands: [EngineCommand] = []
        let automation = automationOn && mode != .display
        var cues: [(Track, Cue)] = []
        for track in item.tracks where !track.muted && track.kind != .shots {
            for cue in track.cues where cue.at > from + 1e-9 && cue.at <= to + 1e-9 {
                cues.append((track, cue))
            }
        }
        cues.sort { $0.1.at < $1.1.at }
        for (track, cue) in cues {
            switch track.kind {
            case .fx:
                guard automation, let action = cue.fxAction,
                      let s = track.switcherID ?? mainOutput?.switcherID else { continue }
                switch action {
                case .macro: commands.append(.macro(switcher: s, index: cue.fxIndex))
                case .dskOn: commands.append(.dsk(switcher: s, index: cue.fxIndex, on: true))
                case .dskOff: commands.append(.dsk(switcher: s, index: cue.fxIndex, on: false))
                case .dskAuto: commands.append(.dskAuto(switcher: s, index: cue.fxIndex))
                case .keyOn: commands.append(.key(switcher: s, index: cue.fxIndex, on: true))
                case .keyOff: commands.append(.key(switcher: s, index: cue.fxIndex, on: false))
                case .fadeToBlack: commands.append(.fadeToBlack(switcher: s))
                case .auxSource: commands.append(.aux(switcher: s, aux: cue.fxIndex, input: cue.fxValue))
                }
            case .osc:
                if let target = cue.oscTargetID, !cue.oscAddress.isEmpty {
                    commands.append(.osc(target: target, address: cue.oscAddress, args: cue.oscArgs))
                }
            case .device:
                if let target = cue.sendTargetID, let payload = cue.send {
                    commands.append(.send(target: target, payload: payload))
                }
            case .ptz:
                if automation, let camera = cue.ptzCameraID {
                    commands.append(.ptz(camera: camera, preset: cue.ptzPreset))
                }
            case .control:
                switch cue.controlAction {
                case .stop?, .wait?:
                    transport = .stopped
                case .loadNext?:
                    var c = cursor
                    if show.moveItem(&c, by: 1) { pendingLoad = c.itemID }
                case .jump?:
                    if let id = cue.jumpItemID, show.item(id) != nil { pendingLoad = id }
                case nil:
                    break
                }
            default:
                break
            }
        }
        return commands
    }
}
