import Foundation
import Combine

/// Which timing source drives the current song or segment in Live Mode.
public enum TimingSourceKind: Equatable {
    case manual, taps, internalClock, midiClock, ltc

    public var label: String {
        switch self {
        case .manual: return "Manual NEXT"
        case .taps: return "Section taps"
        case .internalClock: return "Internal clock"
        case .midiClock: return "MIDI clock"
        case .ltc: return "LTC"
        }
    }
}

/// One switcher's live state, as Live Mode shows it.
public struct SwitcherLiveStatus: Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var kind: SwitcherKind
    public var host: String
    public var role: SwitcherRole
    public var connected: Bool
    public var connecting: Bool
    public var program: Int?
    public var preview: Int?
    public var assumed: Bool
    public var modelName: String
}

/// Everything Live Mode shows about the engine, published at about 20 Hz.
public struct EngineStatus: Equatable {
    public var itemID: UUID
    public var index: Int
    public var position: Double
    public var transport: EngineTransport
    /// Mode per output id.
    public var modes: [UUID: OutputMode]
    public var pauseReason: String?
    public var freeMode: Bool
    public var loopSectionID: UUID?
    public var takenAt: Date?
    public var secondsToNext: Double?

    public var timing: TimingSourceKind
    /// True while the timing source is delivering (MIDI ticks or LTC frames in the last half second).
    public var timingSignal: Bool
    public var tempo: Double?
    public var timecode: String?

    public var switchers: [SwitcherLiveStatus]
    /// Cameras that have been off program the longest (free mode hints).
    public var hints: [UUID]
    public var logFile: String?
    public var cutCount: Int

    public var cursor: LiveCursor { LiveCursor(itemID: itemID, index: index) }
    public var mainSwitcher: SwitcherLiveStatus? { switchers.first }
    public func mode(_ outputID: UUID?) -> OutputMode { outputID.flatMap { modes[$0] } ?? .display }

    // Main switcher shorthands.
    public var switcherName: String { mainSwitcher?.name ?? "No switcher" }
    public var switcherKind: SwitcherKind? { mainSwitcher?.kind }
    public var switcherHost: String { mainSwitcher?.host ?? "" }
    public var switcherConnected: Bool { mainSwitcher?.connected ?? false }
    public var switcherConnecting: Bool { mainSwitcher?.connecting ?? false }
    public var program: Int? { mainSwitcher?.program }
    public var preview: Int? { mainSwitcher?.preview }
    public var switcherAssumed: Bool { mainSwitcher?.assumed ?? false }
}

/// Runs the show: owns the engine, the switcher connections, the timing inputs, OSC and PTZ
/// output, the clock and the switch log. Lives on the main thread.
public final class EngineController: ObservableObject {
    @Published public private(set) var status: EngineStatus
    public let engine: ShowEngine
    public private(set) var log: SwitchLog

    private var profile: MachineProfile
    private var devices: [UUID: SwitcherDevice] = [:]
    private let companion = CompanionClient()
    private let osc = OSCSender()
    private let ptz = PTZService()
    private var midi: MIDIManager?
    private var midiFollower = MIDIClockFollower()
    private var lastMIDIEvent: Double?
    private var ltcInput: LTCInput?
    private var ltcFollower = LTCFollower()
    private var lastLTC: (seconds: Double, time: Double)?
    private var clock = InternalClock()
    private var timer: Timer?
    private var tickCount = 0
    private var pending: [EngineCommand] = []
    private var transitionWait: (switcher: UUID, deadline: Double, seen: Bool)?
    private var lastProgram: [UUID: Int] = [:]
    private var connectedOnce: Set<UUID> = []
    private var takenDate: Date?
    private var lastTakenAt: Double?
    private var processing = false
    private var logURL: URL?
    private var logDirty = false
    private var lastLogSave: Double = 0

    public init(show: Show, itemID: UUID, profile: MachineProfile, logFolder: URL? = nil) {
        self.profile = profile
        engine = ShowEngine(show: show, itemID: itemID, mode: .display)
        log = SwitchLog(showID: show.id, showName: show.name, started: Date(), machine: profile.machineName)
        status = EngineStatus(itemID: itemID, index: -1, position: 0, transport: .standby, modes: engine.modes,
                              pauseReason: nil, freeMode: false, loopSectionID: nil, takenAt: nil, secondsToNext: nil,
                              timing: .manual, timingSignal: false, tempo: nil, timecode: nil,
                              switchers: [], hints: [], logFile: nil, cutCount: 0)
        if let folder = logFolder ?? Self.defaultLogFolder(profile) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            logURL = folder.appendingPathComponent(log.fileName)
        }
        ptz.companion = companion
        ptz.runATEMMacro = { [weak self] switcherID, index in
            guard let self else { return }
            let id = switcherID ?? self.engine.show.mainOutput?.switcherID
            if let id { self.devices[id]?.runMacro(index) }
        }
        prepareTiming()
        startTimer()
        publish()
    }

    deinit {
        timer?.invalidate()
        devices.values.forEach { $0.disconnect() }
        ltcInput?.stop()
    }

    /// Where switch logs go: the folder set in This Mac's settings, or Documents/OnCue Logs.
    public static func defaultLogFolder(_ profile: MachineProfile) -> URL? {
        if !profile.logFolder.isEmpty { return URL(fileURLWithPath: profile.logFolder, isDirectory: true) }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OnCue Logs", isDirectory: true)
    }

    /// Stops the clock and inputs, saves the log and leaves every switcher as it is.
    public func shutdown() {
        timer?.invalidate()
        timer = nil
        saveLog()
        for device in devices.values {
            device.onChange = nil
            device.disconnect()
        }
        devices.removeAll()
        midi?.onClock = nil
        midi = nil
        ltcInput?.stop()
        ltcInput = nil
    }

    static var now: Double { ProcessInfo.processInfo.systemUptime }

    // MARK: - Timing source

    public var timingKind: TimingSourceKind {
        guard let item = engine.item else { return .manual }
        if item.timeBase == .order { return .manual }
        switch item.syncMode {
        case .next: return .manual
        case .tap: return .taps
        case .freeRun: return .internalClock
        case .midiClock: return .midiClock
        case .ltc: return .ltc
        }
    }

    /// Starts the input the current item needs (MIDI clock or LTC audio).
    private func prepareTiming() {
        clock.stop()
        ltcFollower.reset()
        switch timingKind {
        case .midiClock:
            if midi == nil {
                let m = MIDIManager()
                m.configure(clockSource: profile.midiClockSource,
                            controllerSource: profile.controllerSource,
                            controllerDestination: profile.controllerDestination)
                m.onClock = { [weak self] event in self?.handleMIDI(event) }
                midi = m
            }
        case .ltc:
            if ltcInput == nil {
                let input = LTCInput(deviceUID: profile.ltcDeviceUID, channel: profile.ltcChannel,
                                     fps: engine.show.settings.ltcFPS)
                input.onTimecode = { [weak self] seconds in self?.handleLTC(seconds) }
                input.start()
                ltcInput = input
            }
        default:
            break
        }
    }

    // MARK: - Switchers

    /// Connects every switcher in the show (main, sub-switchers and separate outputs).
    public func connectSwitcher() {
        companion.host = profile.companionHost
        companion.port = profile.companionPort
        companion.version = CompanionVersion(rawValue: profile.companionVersion) ?? .v3
        for config in engine.show.switchers { connect(config) }
        publish()
    }

    public func connect(_ config: SwitcherConfig) {
        devices[config.id]?.onChange = nil
        devices[config.id]?.disconnect()
        let device = SwitcherFactory.make(config, companion: companion)
        let id = config.id
        device.onChange = { [weak self] in self?.switcherChanged(id) }
        devices[id] = device
        connectedOnce.remove(id)
        lastProgram[id] = nil
        device.connect()
    }

    public func disconnectSwitcher() {
        for device in devices.values {
            device.onChange = nil
            device.disconnect()
        }
        devices.removeAll()
        pending.removeAll()
        transitionWait = nil
        publish()
    }

    private func switcherChanged(_ id: UUID) {
        guard let device = devices[id] else { return }
        let state = device.state
        let now = Self.now
        if state.connected && !connectedOnce.contains(id) {
            connectedOnce.insert(id)
            lastProgram[id] = state.program
            run(engine.setMode(engine.mode))
        }
        if !state.connected { connectedOnce.remove(id) }
        if state.connected, let last = lastProgram[id], state.program != last {
            if !state.assumed { engine.programChanged(to: state.program, on: id, now: now) }
            logCut(switcherID: id, input: state.program)
        }
        lastProgram[id] = state.connected ? state.program : nil
        processPending(now)
        publish()
    }

    // MARK: - Transport

    public func go() {
        let now = Self.now
        switch timingKind {
        case .internalClock, .taps:
            clock.start(at: 0, now: now)
            engine.syncRaw(0)
        case .ltc:
            ltcFollower.reset()
        default:
            break
        }
        run(engine.start(now: now))
    }

    public func stop() {
        engine.stop()
        clock.stop()
        publish()
    }

    public func next() { run(engine.next(now: Self.now)) }
    public func back() { run(engine.back(now: Self.now)) }

    /// Section tap: jump to the next section and run from there at the item's tempo.
    public func tap() {
        let now = Self.now
        if !clock.running {
            clock.start(at: 0, now: now)
            engine.syncRaw(0)
        }
        run(engine.tapSection(now: now))
    }

    public func jump(toSection id: UUID) { run(engine.jump(toSection: id, now: Self.now)) }

    public func moveItem(by delta: Int) {
        run(engine.moveItem(by: delta, now: Self.now))
        prepareTiming()
    }

    public func load(itemID: UUID) {
        run(engine.load(itemID: itemID, now: Self.now))
        prepareTiming()
    }

    // MARK: - Modes, pause, free mode, loop, panic

    public func setMode(_ mode: OutputMode) { run(engine.setMode(mode)) }

    public func setMode(_ mode: OutputMode, for outputID: UUID) { run(engine.setMode(mode, for: outputID)) }

    public func resume() { run(engine.resume()) }

    public func setFreeMode(_ on: Bool) { run(engine.setFreeMode(on)) }

    public func toggleLoop() {
        engine.toggleLoop()
        publish()
    }

    /// Panic: every output to display only, queued commands dropped. Switchers keep their state.
    public func panic() {
        engine.panic()
        pending.removeAll()
        transitionWait = nil
        publish()
    }

    /// The script was edited while live.
    public func update(show: Show) {
        let before = timingKind
        let switchersBefore = engine.show.switchers
        engine.update(show: show)
        if timingKind != before { prepareTiming() }
        // A switcher added or re-addressed while live connects again.
        if !devices.isEmpty {
            for config in show.switchers where switchersBefore.first(where: { $0.id == config.id }) != config {
                connect(config)
            }
        }
        log.showName = show.name
        publish()
    }

    // MARK: - Inputs

    private func handleMIDI(_ event: MIDIClockEvent) {
        let now = Self.now
        lastMIDIEvent = now
        let clockEvent: ClockEvent
        switch event {
        case .tick(let t): clockEvent = .tick(t)
        case .start: clockEvent = .start
        case .stop: clockEvent = .stop
        case .resume: clockEvent = .resume
        case .songPosition(let p): clockEvent = .songPosition(p)
        }
        let moved = midiFollower.handle(clockEvent)
        guard timingKind == .midiClock, let item = engine.item else { return }
        switch clockEvent {
        case .start:
            engine.rewind()
            engine.syncRaw(0)
            run(engine.start(now: now))
        case .resume:
            if engine.transport != .running { run(engine.start(now: now)) }
        case .stop:
            engine.stop()
        default:
            break
        }
        if moved {
            run(engine.setPosition(raw: TimingMath.position(beats: midiFollower.beats, for: item), now: now), publishNow: false)
        }
    }

    private func handleLTC(_ seconds: Double) {
        let now = Self.now
        lastLTC = (seconds, now)
        guard timingKind == .ltc, let item = engine.item, engine.transport == .running else { return }
        let p = ltcFollower.position(forTimecode: seconds, item: item, fps: engine.show.settings.ltcFPS)
        run(engine.setPosition(raw: p, now: now), publishNow: false)
    }

    // MARK: - Clock and commands

    private func startTimer() {
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Self.now
        if (timingKind == .internalClock || timingKind == .taps), clock.running, let item = engine.item {
            let raw = clock.advance(now: now, rate: TimingMath.rate(for: item))
            if engine.transport == .running {
                run(engine.setPosition(raw: raw, now: now), publishNow: false)
            }
        }
        processPending(now)
        tickCount += 1
        if tickCount % 3 == 0 { publish() }
        if logDirty, now - lastLogSave > 5 { saveLog() }
    }

    private func run(_ commands: [EngineCommand], publishNow: Bool = true) {
        let itemBefore = engine.cursor.itemID
        pending += commands
        recordTakes()
        processPending(Self.now)
        if engine.cursor.itemID != itemBefore { prepareTiming() }
        if publishNow { publish() }
    }

    /// Sends queued commands in order. Commands after a mix wait until that switcher reports the
    /// transition finished (or 3 seconds pass).
    private func processPending(_ now: Double) {
        guard !processing else { return }
        processing = true
        defer { processing = false }
        while !pending.isEmpty {
            if let wait = transitionWait {
                let inTransition = devices[wait.switcher]?.state.inTransition ?? false
                if inTransition { transitionWait?.seen = true }
                let seen = transitionWait?.seen ?? false
                guard (seen && !inTransition) || now > wait.deadline else { return }
                transitionWait = nil
            }
            let command = pending.removeFirst()
            execute(command, now: now)
        }
    }

    private func device(_ id: UUID) -> SwitcherDevice? {
        guard let d = devices[id], d.state.connected else { return nil }
        return d
    }

    private func execute(_ command: EngineCommand, now: Double) {
        switch command {
        case .preview(let s, let input): device(s)?.setPreview(input)
        case .program(let s, let input): device(s)?.setProgram(input)
        case .cut(let s):
            guard let d = device(s) else { return }
            engine.noteTransitionSent(to: d.state.preview, on: s, mix: false, now: now)
            d.cut()
        case .auto(let s):
            guard let d = device(s) else { return }
            engine.noteTransitionSent(to: d.state.preview, on: s, mix: true, now: now)
            d.auto()
            transitionWait = (s, now + 3, d.state.inTransition)
        case .aux(let s, let aux, let input): device(s)?.setAux(aux, source: input)
        case .macro(let s, let index): device(s)?.runMacro(index)
        case .dsk(let s, let index, let on): device(s)?.setDSK(index, onAir: on)
        case .dskAuto(let s, let index): device(s)?.autoDSK(index)
        case .key(let s, let index, let on): device(s)?.setKeyer(index, onAir: on)
        case .fadeToBlack(let s): device(s)?.fadeToBlack()
        case .osc(let targetID, let address, let args):
            if let target = engine.show.oscTarget(targetID) {
                osc.send(host: target.host, port: target.port, address: address, args: OSC.parseArgs(args))
            }
        case .ptz(let cameraID, let preset):
            if let cam = engine.show.ptz(cameraID) { ptz.recall(cam, preset: preset) }
        }
    }

    // MARK: - Switch log

    private func recordTakes() {
        let now = Self.now
        for take in engine.drainTakes() {
            let date = Date().addingTimeInterval(take.time - now)
            log.entries.append(SwitchLogEntry(kind: .scripted, date: date, timecode: currentTimecode,
                                              outputID: take.outputID, cameraID: take.cameraID, itemID: take.itemID,
                                              shotNumber: take.shotNumber, mode: engine.mode(of: take.outputID).rawValue,
                                              freeMode: engine.freeMode))
            logDirty = true
        }
    }

    private func logCut(switcherID: UUID, input: Int) {
        let camera = engine.show.camera(input: input, switcherID: switcherID)
        log.entries.append(SwitchLogEntry(kind: .cut, date: Date(), timecode: currentTimecode, switcherID: switcherID,
                                          input: input, cameraID: camera?.id, itemID: engine.cursor.itemID,
                                          shotNumber: engine.onAir?.number, mode: engine.mode.rawValue,
                                          freeMode: engine.freeMode))
        logDirty = true
    }

    private var currentTimecode: String? {
        guard timingKind == .ltc, let l = lastLTC, Self.now - l.time < 1 else { return nil }
        return TimeFormat.timecode(l.seconds, fps: engine.show.settings.ltcFPS)
    }

    /// Writes the log (atomically) next to the other logs.
    public func saveLog() {
        lastLogSave = Self.now
        guard !log.entries.isEmpty, let url = logURL, let data = try? log.encoded() else { return }
        try? data.write(to: url, options: .atomic)
        logDirty = false
    }

    public var logFileURL: URL? { logURL }

    // MARK: - Publish

    private func publish() {
        let now = Self.now
        if engine.takenAt != lastTakenAt {
            lastTakenAt = engine.takenAt
            takenDate = engine.takenAt.map { Date().addingTimeInterval($0 - now) }
        }
        let kind = timingKind
        var signal = false
        var timecode: String?
        switch kind {
        case .midiClock: signal = lastMIDIEvent.map { now - $0 < 0.5 } ?? false
        case .ltc:
            signal = lastLTC.map { now - $0.time < 0.5 } ?? false
            timecode = lastLTC.map { TimeFormat.timecode($0.seconds, fps: engine.show.settings.ltcFPS) }
        case .internalClock, .taps: signal = clock.running
        case .manual: signal = true
        }
        let show = engine.show
        let switchers: [SwitcherLiveStatus] = orderedSwitchers(show).map { config in
            let state = devices[config.id]?.state
            let connected = state?.connected ?? false
            return SwitcherLiveStatus(id: config.id, name: config.name, kind: config.kind, host: config.host, role: config.role,
                                      connected: connected, connecting: devices[config.id] != nil && !connected,
                                      program: connected ? state?.program : nil, preview: connected ? state?.preview : nil,
                                      assumed: state?.assumed ?? false, modelName: state?.modelName ?? "")
        }
        var hints: [UUID] = []
        if engine.freeMode {
            let main = switchers.first
            let onAirCamera = main?.program.flatMap { show.camera(input: $0, switcherID: main?.id)?.id }
            hints = show.varietyHints(log: log, now: Date(), count: 3, excluding: onAirCamera).map(\.id)
        }
        let new = EngineStatus(
            itemID: engine.cursor.itemID, index: engine.cursor.index, position: engine.position,
            transport: engine.transport, modes: engine.modes, pauseReason: engine.pause?.reason,
            freeMode: engine.freeMode, loopSectionID: engine.loopSectionID,
            takenAt: takenDate,
            // Only a moving timing source gives a real countdown; otherwise Live shows the plan.
            secondsToNext: (engine.transport == .running && kind != .manual && signal && !engine.freeMode) ? engine.secondsToNext() : nil,
            timing: kind, timingSignal: signal,
            tempo: kind == .midiClock ? midiFollower.tempo : engine.item?.bpm,
            timecode: timecode, switchers: switchers, hints: hints,
            logFile: logURL?.lastPathComponent, cutCount: log.cuts.count)
        if new != status { status = new }
    }

    /// Main switcher first, then the others in show order.
    private func orderedSwitchers(_ show: Show) -> [SwitcherConfig] {
        let main = show.mainOutput?.switcherID
        return show.switchers.filter { $0.id == main } + show.switchers.filter { $0.id != main }
    }

    /// For tests: drive the clock without the timer.
    func tickForTesting() { tick() }
    /// For tests: a connected switcher device.
    func deviceForTesting(_ id: UUID) -> SwitcherDevice? { devices[id] }
}
