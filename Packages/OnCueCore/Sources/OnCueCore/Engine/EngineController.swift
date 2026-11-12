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

/// Everything Live Mode shows about the engine, published at about 20 Hz.
public struct EngineStatus: Equatable {
    public var itemID: UUID
    public var index: Int
    public var position: Double
    public var transport: EngineTransport
    public var mode: OutputMode
    public var pauseReason: String?
    public var takenAt: Date?
    public var secondsToNext: Double?

    public var timing: TimingSourceKind
    /// True while the timing source is delivering (MIDI ticks or LTC frames in the last half second).
    public var timingSignal: Bool
    public var tempo: Double?
    public var timecode: String?

    public var switcherName: String
    public var switcherKind: SwitcherKind?
    public var switcherHost: String
    public var switcherConnected: Bool
    public var switcherConnecting: Bool
    /// Program and preview as the switcher reports them (Companion: as OnCue last set them).
    public var program: Int?
    public var preview: Int?
    public var switcherAssumed: Bool

    public var cursor: LiveCursor { LiveCursor(itemID: itemID, index: index) }
}

/// Runs the show: owns the engine, the switcher connection, the timing inputs and the clock.
/// Lives on the main thread.
public final class EngineController: ObservableObject {
    @Published public private(set) var status: EngineStatus
    public let engine: ShowEngine

    private var profile: MachineProfile
    private var switcher: SwitcherDevice?
    private let companion = CompanionClient()
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
    private var transitionDeadline: Double?
    private var transitionSeen = false
    private var lastProgram: Int?
    private var wasConnected = false
    private var takenDate: Date?
    private var lastTakenAt: Double?
    private var processing = false

    public init(show: Show, itemID: UUID, profile: MachineProfile) {
        self.profile = profile
        engine = ShowEngine(show: show, itemID: itemID, mode: .display)
        status = EngineStatus(itemID: itemID, index: -1, position: 0, transport: .standby, mode: .display,
                              pauseReason: nil, takenAt: nil, secondsToNext: nil,
                              timing: .manual, timingSignal: false, tempo: nil, timecode: nil,
                              switcherName: "", switcherKind: nil, switcherHost: "", switcherConnected: false,
                              switcherConnecting: false, program: nil, preview: nil, switcherAssumed: false)
        prepareTiming()
        startTimer()
        publish()
    }

    deinit {
        timer?.invalidate()
        switcher?.disconnect()
        ltcInput?.stop()
    }

    /// Stops the clock, inputs and the switcher connection.
    public func shutdown() {
        timer?.invalidate()
        timer = nil
        switcher?.onChange = nil
        switcher?.disconnect()
        switcher = nil
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

    // MARK: - Switcher

    private var mainSwitcherConfig: SwitcherConfig? {
        engine.show.switcher(engine.show.mainOutput?.switcherID) ?? engine.show.switchers.first
    }

    public func connectSwitcher() {
        guard let config = mainSwitcherConfig else { return }
        switcher?.onChange = nil
        switcher?.disconnect()
        companion.host = profile.companionHost
        companion.port = profile.companionPort
        companion.version = CompanionVersion(rawValue: profile.companionVersion) ?? .v3
        let device = SwitcherFactory.make(config, companion: companion)
        device.onChange = { [weak self] in self?.switcherChanged() }
        switcher = device
        wasConnected = false
        lastProgram = nil
        device.connect()
        publish()
    }

    public func disconnectSwitcher() {
        switcher?.onChange = nil
        switcher?.disconnect()
        switcher = nil
        wasConnected = false
        pending.removeAll()
        publish()
    }

    private func switcherChanged() {
        guard let device = switcher else { return }
        let state = device.state
        if state.connected && !wasConnected {
            wasConnected = true
            lastProgram = state.program
            run(engine.setMode(engine.mode))
        }
        if !state.connected { wasConnected = false }
        if state.connected, !state.assumed, let last = lastProgram, state.program != last {
            engine.programChanged(to: state.program, now: Self.now)
        }
        lastProgram = state.connected ? state.program : nil
        processPending(Self.now)
        publish()
    }

    // MARK: - Transport

    public func go() {
        let now = Self.now
        switch timingKind {
        case .internalClock, .taps:
            clock.start(at: engine.position, now: now)
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

    public func next() {
        let now = Self.now
        run(engine.next(now: now))
        if clock.running { clock.jump(to: engine.position, now: now) }
    }

    public func back() {
        let now = Self.now
        run(engine.back(now: now))
        if clock.running { clock.jump(to: engine.position, now: now) }
    }

    /// Section tap: jump to the next section and run from there at the item's tempo.
    public func tap() {
        let now = Self.now
        run(engine.tapSection(now: now))
        if clock.running { clock.jump(to: engine.position, now: now) } else { clock.start(at: engine.position, now: now) }
    }

    public func jump(toSection id: UUID) {
        let now = Self.now
        run(engine.jump(toSection: id, now: now))
        if clock.running { clock.jump(to: engine.position, now: now) }
    }

    public func moveItem(by delta: Int) {
        run(engine.moveItem(by: delta, now: Self.now))
        prepareTiming()
    }

    public func load(itemID: UUID) {
        run(engine.load(itemID: itemID, now: Self.now))
        prepareTiming()
    }

    public func setMode(_ mode: OutputMode) {
        run(engine.setMode(mode))
    }

    public func resume() {
        run(engine.resume())
    }

    /// The script was edited while live.
    public func update(show: Show) {
        let before = timingKind
        engine.update(show: show)
        if timingKind != before { prepareTiming() }
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
        case .start, .resume:
            if engine.transport != .running { run(engine.start(now: now)) }
        case .stop:
            engine.stop()
        default:
            break
        }
        if moved {
            run(engine.setPosition(TimingMath.position(beats: midiFollower.beats, for: item), now: now), publishNow: false)
        }
    }

    private func handleLTC(_ seconds: Double) {
        let now = Self.now
        lastLTC = (seconds, now)
        guard timingKind == .ltc, let item = engine.item, engine.transport == .running else { return }
        let p = ltcFollower.position(forTimecode: seconds, item: item, fps: engine.show.settings.ltcFPS)
        run(engine.setPosition(p, now: now), publishNow: false)
    }

    // MARK: - Clock and commands

    private func startTimer() {
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Self.now
        if (timingKind == .internalClock || timingKind == .taps), clock.running, engine.transport == .running, let item = engine.item {
            let p = clock.advance(now: now, rate: TimingMath.rate(for: item))
            run(engine.setPosition(p, now: now), publishNow: false)
        }
        processPending(now)
        tickCount += 1
        if tickCount % 3 == 0 { publish() }
    }

    private func run(_ commands: [EngineCommand], publishNow: Bool = true) {
        pending += commands
        processPending(Self.now)
        if publishNow { publish() }
    }

    /// Sends queued commands in order. Commands after a mix wait until the switcher reports the
    /// transition finished (or 3 seconds pass).
    private func processPending(_ now: Double) {
        // Switcher callbacks can arrive while a command is being sent; the outer loop keeps order.
        guard !processing else { return }
        guard let device = switcher, device.state.connected else {
            pending.removeAll()
            return
        }
        processing = true
        defer { processing = false }
        while !pending.isEmpty {
            if let deadline = transitionDeadline {
                let inTransition = device.state.inTransition
                if inTransition { transitionSeen = true }
                guard (transitionSeen && !inTransition) || now > deadline else { return }
                transitionDeadline = nil
                transitionSeen = false
            }
            switch pending.removeFirst() {
            case .preview(let input): device.setPreview(input)
            case .cut: device.cut()
            case .auto:
                device.auto()
                transitionDeadline = now + 3
                transitionSeen = device.state.inTransition
            }
        }
    }

    private func publish() {
        let now = Self.now
        if engine.takenAt != lastTakenAt {
            lastTakenAt = engine.takenAt
            takenDate = engine.takenAt.map { Date().addingTimeInterval($0 - now) }
        }
        let state = switcher?.state
        let config = mainSwitcherConfig
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
        let new = EngineStatus(
            itemID: engine.cursor.itemID, index: engine.cursor.index, position: engine.position,
            transport: engine.transport, mode: engine.mode, pauseReason: engine.pause?.reason,
            takenAt: takenDate, secondsToNext: engine.transport == .running ? engine.secondsToNext() : nil,
            timing: kind, timingSignal: signal,
            tempo: kind == .midiClock ? midiFollower.tempo : engine.item?.bpm,
            timecode: timecode,
            switcherName: config?.name ?? "No switcher", switcherKind: config?.kind, switcherHost: config?.host ?? "",
            switcherConnected: state?.connected ?? false,
            switcherConnecting: switcher != nil && !(state?.connected ?? false),
            program: (state?.connected ?? false) ? state?.program : nil,
            preview: (state?.connected ?? false) ? state?.preview : nil,
            switcherAssumed: state?.assumed ?? false)
        if new != status { status = new }
    }

    /// For tests: drive the clock without the timer.
    func tickForTesting() { tick() }
}
