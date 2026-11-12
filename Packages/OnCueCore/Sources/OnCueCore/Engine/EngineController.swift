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
    /// Backup Mac: following the main Mac (sends nothing until it takes over).
    public var following: Bool = false
    /// Backup Mac: the link to the main Mac is up.
    public var mainLinked: Bool = false

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
    private let oscControl = OSCControlListener()
    private var tapTempo = TapTempo()
    /// Tempo from tap tempo, overriding the item's tempo for the internal clock until the item changes.
    public private(set) var tempoOverride: Double?
    private var ledCache: [Int: Int] = [:]
    private var lastVariables: [String: String] = [:]
    private var lastVariablePush: Double = 0

    public init(show: Show, itemID: UUID, profile: MachineProfile, logFolder: URL? = nil) {
        self.profile = profile
        engine = ShowEngine(show: show, itemID: itemID, mode: .display)
        var crew: [String: String] = [:]
        for cam in show.cameras where !cam.operatorName.isEmpty { crew["\(cam.number)"] = cam.operatorName }
        log = SwitchLog(showID: show.id, showName: show.name, started: Date(), machine: profile.machineName,
                        night: show.settings.nightLabel, operators: crew)
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
        setupControls()
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
        clearLEDs()
        midi?.onClock = nil
        midi?.onControl = nil
        midi = nil
        oscControl.stop()
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
        tempoOverride = nil
        switch timingKind {
        case .midiClock:
            ensureMIDI()
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
        switch following ? nil : clockEvent {
        case .start?:
            engine.rewind()
            engine.syncRaw(0)
            run(engine.start(now: now))
        case .resume?:
            if engine.transport != .running { run(engine.start(now: now)) }
        case .stop?:
            engine.stop()
        default:
            break
        }
        if moved {
            if !following { run(engine.setPosition(raw: TimingMath.position(beats: midiFollower.beats, for: item), now: now), publishNow: false) }
        }
    }

    private func handleLTC(_ seconds: Double) {
        let now = Self.now
        lastLTC = (seconds, now)
        guard timingKind == .ltc, let item = engine.item, engine.transport == .running else { return }
        let p = ltcFollower.position(forTimecode: seconds, item: item, fps: engine.show.settings.ltcFPS)
        if !following { run(engine.setPosition(raw: p, now: now), publishNow: false) }
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
            var rate = TimingMath.rate(for: item)
            if let tempo = tempoOverride, item.timeBase == .bars { rate = tempo / 60 }
            let raw = clock.advance(now: now, rate: rate)
            if engine.transport == .running {
                if !following { run(engine.setPosition(raw: raw, now: now), publishNow: false) }
            }
        }
        processPending(now)
        tickCount += 1
        if tickCount % 3 == 0 { publish() }
        if logDirty, now - lastLogSave > 5 { saveLog() }
    }

    private func run(_ commands: [EngineCommand], publishNow: Bool = true) {
        let itemBefore = engine.cursor.itemID
        if !following { pending += commands }
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

    // MARK: - Backup Mac

    private var following = false
    private var mainLinked = false
    private var mainModes: [String: String] = [:]

    /// Backup Mac: follow the main Mac; nothing is sent to switchers, OSC or PTZ until takeOver().
    public func startFollowing() {
        following = true
        publish()
    }

    public func follow(_ s: BackupState) {
        guard following, s.showID == engine.show.id else { return }
        let t: EngineTransport = s.transport == "running" ? .running : (s.transport == "stopped" ? .stopped : .standby)
        let itemBefore = engine.cursor.itemID
        _ = engine.follow(itemID: s.itemID, index: s.index, position: s.position, transport: t,
                          freeMode: s.freeMode, loopSectionID: s.loopSectionID, now: Self.now)
        mainModes = s.modes
        recordTakes()
        if engine.cursor.itemID != itemBefore { prepareTiming() }
        publish()
    }

    public func setMainLinked(_ linked: Bool) {
        mainLinked = linked
        publish()
    }

    /// The backup Mac takes the show: it starts sending, in the modes the main Mac was using.
    public func takeOver() {
        guard following else { return }
        following = false
        for (key, value) in mainModes {
            if let id = UUID(uuidString: key), let mode = OutputMode(rawValue: value) { run(engine.setMode(mode, for: id), publishNow: false) }
        }
        // Carry on from the main Mac's position with this Mac's own timing source.
        let now = Self.now
        switch timingKind {
        case .internalClock, .taps:
            if engine.transport == .running { clock.start(at: engine.position, now: now) } else { clock.jump(to: engine.position, now: now) }
            engine.syncRaw(clock.position)
        case .midiClock:
            if let item = engine.item { engine.syncRaw(TimingMath.position(beats: midiFollower.beats, for: item)) }
        case .ltc, .manual:
            break
        }
        publish()
    }

    /// Main Mac: where the show is, for the backup Macs.
    public var backupState: BackupState {
        let t: String
        switch engine.transport {
        case .running: t = "running"
        case .stopped: t = "stopped"
        case .standby: t = "standby"
        }
        var modes: [String: String] = [:]
        for (k, v) in engine.modes { modes[k.uuidString] = v.rawValue }
        return BackupState(showID: engine.show.id, itemID: engine.cursor.itemID, index: engine.cursor.index,
                           position: engine.position, transport: t, modes: modes, freeMode: engine.freeMode,
                           loopSectionID: engine.loopSectionID, sentAt: Date())
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
            tempo: kind == .midiClock ? midiFollower.tempo : (tempoOverride ?? engine.item?.bpm),
            timecode: timecode, switchers: switchers, hints: hints,
            logFile: logURL?.lastPathComponent, cutCount: log.cuts.count,
            following: following, mainLinked: mainLinked)
        if new != status { status = new }
        updateLEDs()
        pushCompanionVariables(now: now)
    }

    /// Main switcher first, then the others in show order.
    private func orderedSwitchers(_ show: Show) -> [SwitcherConfig] {
        let main = show.mainOutput?.switcherID
        return show.switchers.filter { $0.id == main } + show.switchers.filter { $0.id != main }
    }

    // MARK: - Controls (APC40 / MIDI, Companion OSC, keyboard)

    /// One MIDI connection for clock and controller (and the controller's LEDs).
    private func ensureMIDI() {
        guard midi == nil else { return }
        let m = MIDIManager()
        m.configure(clockSource: profile.midiClockSource,
                    controllerSource: profile.controllerSource,
                    controllerDestination: profile.controllerDestination)
        m.onClock = { [weak self] event in self?.handleMIDI(event) }
        m.onControl = { [weak self] channel, number, isCC, value in
            guard let self, let binding = ControlMapping.binding(for: channel, number: number, isCC: isCC, value: value,
                                                                  in: self.engine.show.midiBindings) else { return }
            self.perform(binding.command, camera: binding.cameraNumber)
        }
        midi = m
        ledCache.removeAll()
    }

    private func setupControls() {
        if !profile.controllerSource.isEmpty || !profile.controllerDestination.isEmpty { ensureMIDI() }
        oscControl.onCommand = { [weak self] address, args in
            var number: Int?
            if let first = args.first {
                switch first {
                case .int(let v): number = Int(v)
                case .float(let v): number = Int(v)
                default: break
                }
            }
            guard let self, let parsed = ControlMapping.command(fromOSC: address, intArgument: number) else { return }
            self.perform(parsed.0, camera: parsed.1)
        }
        if profile.oscControlPort > 0 { oscControl.start(port: profile.oscControlPort) }
    }

    /// Runs a control action from a MIDI controller, Companion / Stream Deck, or the keyboard.
    public func perform(_ command: ControlCommand, camera: Int = 0) {
        switch command {
        case .go: go()
        case .stop: stop()
        case .next: next()
        case .previous: back()
        case .take: manualTransition(mix: false)
        case .auto: manualTransition(mix: true)
        case .tapSection: tap()
        case .prevSection: previousSection()
        case .tapBeat: tapBeat()
        case .loopToggle: toggleLoop()
        case .panic: panic()
        case .resume: resume()
        case .freeModeToggle: setFreeMode(!engine.freeMode)
        case .modeDisplay: setMode(.display)
        case .modePreview: setMode(.preview)
        case .modeCut: setMode(.cut)
        case .nextItem: moveItem(by: 1)
        case .prevItem: moveItem(by: -1)
        case .previewCamera: manualCamera(camera, take: false)
        case .takeCamera: manualCamera(camera, take: true)
        }
    }

    /// The director's own cut or mix on the main switcher (in Auto cut this pauses automation).
    private func manualTransition(mix: Bool) {
        guard let s = engine.show.mainOutput?.switcherID, let d = device(s) else { return }
        if mix { d.auto() } else { d.cut() }
    }

    /// Puts a camera on the main switcher's preview (through sub-switchers), and cuts if `take`.
    private func manualCamera(_ number: Int, take: Bool) {
        guard let s = engine.show.mainOutput?.switcherID, let camera = engine.show.camera(number: number),
              let route = engine.route(camera.id, to: s), let d = device(s) else { return }
        for feed in route.feeds { device(feed.switcher)?.setProgram(feed.input) }
        d.setPreview(route.input)
        if take { d.cut() }
    }

    private func previousSection() {
        guard let item = engine.item else { return }
        let sections = item.sortedSections
        guard let current = sections.lastIndex(where: { $0.at <= engine.position + 1e-6 }) else { return }
        let target = current > 0 && engine.position - sections[current].at < 0.5 ? sections[current - 1] : sections[current]
        jump(toSection: target.id)
    }

    private func tapBeat() {
        if let bpm = tapTempo.tap(at: Self.now) {
            tempoOverride = bpm
            publish()
        }
    }

    private func updateLEDs() {
        guard profile.apcLEDs, let midi, !profile.controllerDestination.isEmpty else { return }
        let main = status.mainSwitcher
        let show = engine.show
        let program = main?.program.flatMap { show.camera(input: $0, switcherID: main?.id)?.id } ?? engine.onAir?.cue.cameraID
        let preview = main?.preview.flatMap { show.camera(input: $0, switcherID: main?.id)?.id } ?? engine.next?.cue.cameraID
        for (note, color) in ControlMapping.padColors(show: show, bindings: show.midiBindings, program: program, preview: preview) {
            if ledCache[note] != color.rawValue {
                midi.sendNote(channel: 0, note: note, velocity: color.rawValue)
                ledCache[note] = color.rawValue
            }
        }
    }

    private func clearLEDs() {
        guard let midi else { return }
        for note in ledCache.keys { midi.sendNote(channel: 0, note: note, velocity: 0) }
        ledCache.removeAll()
    }

    /// Live status as Companion custom variables, for Stream Deck keys:
    /// oncue_now, oncue_next (camera numbers), oncue_now_name, oncue_next_name, oncue_mode,
    /// oncue_countdown, oncue_item, oncue_section, oncue_paused, oncue_free.
    private func pushCompanionVariables(now: Double) {
        guard profile.companionVariables, now - lastVariablePush > 0.25 else { return }
        lastVariablePush = now
        let show = engine.show
        let onAir = show.camera(engine.onAir?.cue.cameraID)
        let next = show.camera(engine.next?.cue.cameraID)
        let section = engine.item?.section(at: engine.position)?.name ?? ""
        let values: [String: String] = [
            "oncue_now": onAir.map { "\($0.number)" } ?? "",
            "oncue_next": next.map { "\($0.number)" } ?? "",
            "oncue_now_name": onAir?.displayName ?? "",
            "oncue_next_name": next?.displayName ?? "",
            "oncue_mode": engine.mode.label,
            "oncue_countdown": status.secondsToNext.map { String(format: "%.1f", $0) } ?? "",
            "oncue_item": engine.item?.title ?? "",
            "oncue_section": section,
            "oncue_paused": engine.isPaused ? "1" : "0",
            "oncue_free": engine.freeMode ? "1" : "0",
        ]
        for (name, value) in values where lastVariables[name] != value {
            companion.setVariable(name, value)
            lastVariables[name] = value
        }
    }

    /// For tests: drive the clock without the timer.
    func tickForTesting() { tick() }
    /// For tests: a connected switcher device.
    func deviceForTesting(_ id: UUID) -> SwitcherDevice? { devices[id] }
}
