import Foundation

// The show engine: follows a playhead through a song or segment and decides what the switcher
// should do. It is pure logic: callers feed it positions (from a timing source) and switcher
// reports, and it returns commands. Times are monotonic seconds supplied by the caller, so every
// behaviour is testable without a clock or hardware.

/// What the engine asks the main switcher to do, in order.
public enum EngineCommand: Equatable {
    /// Put an input on preview.
    case preview(input: Int)
    /// Cut preview to program.
    case cut
    /// Mix (auto transition) preview to program. Commands after it wait for the transition to end.
    case auto
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

public final class ShowEngine {
    public private(set) var show: Show
    public private(set) var cursor: LiveCursor
    /// Playhead in the item's time base (beats, seconds or step).
    public private(set) var position: Double
    public private(set) var transport: EngineTransport = .standby
    public private(set) var mode: OutputMode
    public private(set) var pause: EnginePause?
    /// When the shot on air was taken (caller's monotonic seconds).
    public private(set) var takenAt: Double?

    /// Program inputs OnCue expects to see after its own cuts, in order, each until a deadline.
    /// A list, not a single value: fast NEXTs queue several cuts behind a mix.
    private var expected: [(input: Int, until: Double)] = []

    public init(show: Show, itemID: UUID, mode: OutputMode = .display) {
        self.show = show
        self.cursor = LiveCursor(itemID: itemID)
        self.mode = mode
        self.position = 0
    }

    // MARK: - Reading

    public var item: RundownItem? { show.item(cursor.itemID) }
    public var rows: [ShotRow] { show.shotRows(forItem: cursor.itemID) }
    public var onAir: ShotRow? { show.liveNow(cursor) }
    public var next: ShotRow? { show.liveNext(cursor) }
    public var isPaused: Bool { pause != nil }

    /// The switcher input for a shot's camera on the main switcher (nil: no camera or no input).
    public func input(of row: ShotRow?) -> Int? {
        guard let row, let camera = show.camera(row.cue.cameraID), camera.input > 0 else { return nil }
        if let switcherID = camera.switcherID, let main = show.mainOutput?.switcherID, switcherID != main { return nil }
        return camera.input
    }

    /// Seconds until the next shot, from the playhead and the item's tempo (nil in NEXT order).
    public func secondsToNext() -> Double? {
        guard let item, item.timeBase != .order, let next else { return nil }
        return item.seconds(for: max(next.cue.at - position, 0))
    }

    // MARK: - Script changes

    /// The show was edited while live: keep the position and recompute the shot on air.
    public func update(show newShow: Show) {
        show = newShow
        guard show.item(cursor.itemID) != nil else {
            if let first = show.items.first { cursor = LiveCursor(itemID: first.id) }
            return
        }
        if transport != .standby {
            cursor.index = index(at: position) ?? -1
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
        takenAt = nil
        expected.removeAll()
        return primePreview()
    }

    /// GO: start following the timing source from the current position.
    public func start(now: Double) -> [EngineCommand] {
        transport = .running
        return setPosition(position, now: now)
    }

    public func stop() {
        transport = .stopped
    }

    /// The timing source moved the playhead. Takes the shot the playhead is now in, if it changed.
    public func setPosition(_ newPosition: Double, now: Double) -> [EngineCommand] {
        position = max(newPosition, 0)
        guard transport == .running else { return [] }
        guard let target = index(at: position), target != cursor.index else { return [] }
        return take(target, now: now)
    }

    /// NEXT: take the next shot now, moving the playhead to it.
    public func next(now: Double) -> [EngineCommand] {
        let target = cursor.index + 1
        guard rows.indices.contains(target) else { return [] }
        if transport == .standby { transport = .running }
        position = rows[target].cue.at
        return take(target, now: now)
    }

    /// Back one shot.
    public func back(now: Double) -> [EngineCommand] {
        let target = cursor.index - 1
        guard target >= -1 else { return [] }
        if target == -1 {
            cursor.index = -1
            position = 0
            takenAt = nil
            transport = .standby
            return primePreview()
        }
        position = rows[target].cue.at
        return take(target, now: now)
    }

    /// Section tap: the playhead jumps to the start of the next section.
    public func tapSection(now: Double) -> [EngineCommand] {
        guard let item else { return [] }
        let sections = item.sortedSections
        let nextSection: SongSection?
        if transport == .standby && cursor.index < 0 {
            nextSection = sections.first
        } else {
            nextSection = sections.first { $0.at > position + 1e-6 }
        }
        guard let section = nextSection else { return [] }
        if transport != .running { transport = .running }
        return setPosition(section.at, now: now)
    }

    /// Jump to a section and take its first shot.
    public func jump(toSection sectionID: UUID, now: Double) -> [EngineCommand] {
        guard let section = item?.sections.first(where: { $0.id == sectionID }) else { return [] }
        if transport != .running { transport = .running }
        return setPosition(section.at, now: now)
    }

    /// Previous or next song or segment, standing by.
    public func moveItem(by delta: Int, now: Double) -> [EngineCommand] {
        var c = cursor
        guard show.moveItem(&c, by: delta) else { return [] }
        return load(itemID: c.itemID, now: now)
    }

    // MARK: - Modes and pause

    public func setMode(_ newMode: OutputMode) -> [EngineCommand] {
        mode = newMode
        return primePreview()
    }

    /// The switcher's program changed. In Auto cut, a change OnCue did not ask for is a manual
    /// cut: automation pauses until the director resumes it.
    public func programChanged(to input: Int, now: Double) {
        expected.removeAll { $0.until < now }
        if let k = expected.firstIndex(where: { $0.input == input }) {
            expected.removeFirst(k + 1)
            return
        }
        guard mode == .cut, transport == .running, pause == nil else { return }
        if input == self.input(of: onAir) { return }
        pause = EnginePause(reason: "Manual cut to input \(input)")
        expected.removeAll()
    }

    /// The controller sent a cut or mix to `input` (what was on preview at that moment).
    public func noteTransitionSent(to input: Int, mix: Bool, now: Double) {
        expected.append((input, now + (mix ? 6 : 2)))
    }

    public func pauseAutomation(reason: String) {
        pause = EnginePause(reason: reason)
    }

    /// Resume after a manual cut: the next scripted shot goes to preview, and cuts continue from
    /// the next shot on.
    public func resume() -> [EngineCommand] {
        pause = nil
        return primePreview()
    }

    // MARK: - Internals

    /// Index of the shot the playhead is in (nil before the first shot).
    func index(at p: Double) -> Int? {
        rows.lastIndex { $0.cue.at <= p + 1e-6 }
    }

    private func take(_ index: Int, now: Double) -> [EngineCommand] {
        cursor.index = index
        takenAt = now
        guard pause == nil, mode != .display else { return [] }
        let shot = rows[index]
        let following = rows.indices.contains(index + 1) ? rows[index + 1] : nil
        var commands: [EngineCommand] = []
        switch mode {
        case .cut:
            if let input = input(of: shot) {
                let mix = shot.cue.transition == .auto
                commands += [.preview(input: input), mix ? .auto : .cut]
                expected.append((input, now + 10))
            }
            if let nextInput = input(of: following) { commands.append(.preview(input: nextInput)) }
        case .preview:
            if let nextInput = input(of: following) { commands.append(.preview(input: nextInput)) }
        case .display:
            break
        }
        return commands
    }

    /// Puts the next scripted shot on preview (Auto preview and Auto cut).
    private func primePreview() -> [EngineCommand] {
        guard pause == nil, mode != .display, let nextInput = input(of: next) else { return [] }
        return [.preview(input: nextInput)]
    }
}
