import Foundation

// Timing sources turn into a playhead position in the item's time base. These are pure value
// types; EngineController feeds them real MIDI, audio and clock input.

/// MIDI clock and transport, as received from Ableton (or any DAW) over USB, IAC or network MIDI.
public enum ClockEvent: Equatable {
    case tick(TimeInterval)
    case start
    case stop
    case resume
    /// Song Position Pointer, in sixteenth notes.
    case songPosition(Int)
}

/// Follows MIDI clock: 24 ticks per quarter note, Start resets to zero, Song Position Pointer
/// jumps, Stop and Continue pause and resume. Tempo is measured from the tick spacing.
public struct MIDIClockFollower {
    public private(set) var running = false
    /// Clock ticks since the song start (24 per quarter note).
    public private(set) var ticks = 0
    public private(set) var lastTickTime: TimeInterval?
    private var intervals: [TimeInterval] = []

    public init() {}

    /// Quarter notes since the song start.
    public var beats: Double { Double(ticks) / 24 }

    /// Tempo measured from the last ticks (needs about half a beat of clock).
    public var tempo: Double? {
        guard intervals.count >= 12 else { return nil }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        return average > 0 ? 60 / (average * 24) : nil
    }

    /// Applies an event. Returns true when the position changed.
    @discardableResult
    public mutating func handle(_ event: ClockEvent) -> Bool {
        switch event {
        case .start:
            running = true
            ticks = 0
            return true
        case .resume:
            running = true
            return false
        case .stop:
            running = false
            return false
        case .songPosition(let sixteenths):
            ticks = max(sixteenths, 0) * 6
            return true
        case .tick(let time):
            if let last = lastTickTime {
                let gap = time - last
                if gap > 0, gap < 0.25 {
                    intervals.append(gap)
                    if intervals.count > 48 { intervals.removeFirst() }
                }
            }
            lastTickTime = time
            guard running else { return false }
            ticks += 1
            return true
        }
    }
}

/// OnCue's own clock: free run, and the clock between section taps. Runs at the item's tempo.
public struct InternalClock {
    public private(set) var position: Double = 0
    public private(set) var running = false
    private var lastTime: Double?

    public init() {}

    public mutating func start(at position: Double, now: Double) {
        self.position = position
        lastTime = now
        running = true
    }

    public mutating func stop() {
        running = false
        lastTime = nil
    }

    public mutating func jump(to position: Double, now: Double) {
        self.position = position
        lastTime = now
    }

    /// Advances to `now` at `rate` units per second and returns the position.
    public mutating func advance(now: Double, rate: Double) -> Double {
        if running, let last = lastTime { position += max(now - last, 0) * rate }
        lastTime = now
        return position
    }
}

/// Follows LTC: the item's position is the timecode minus the item's LTC start. With no start set,
/// the first timecode received after GO is the start.
public struct LTCFollower {
    public private(set) var anchor: Double?

    public init() {}

    public mutating func reset() { anchor = nil }

    /// Item position (in its time base) for a received timecode, in seconds since midnight.
    public mutating func position(forTimecode seconds: Double, item: RundownItem, fps: Double) -> Double {
        if anchor == nil {
            anchor = TimeFormat.parseTimecode(item.ltcStart, fps: fps) ?? seconds
        }
        return TimingMath.position(seconds: seconds - (anchor ?? seconds), for: item)
    }
}

public enum TimingMath {
    /// Units per second for the internal clock: beats per second, 1 for seconds, 0 in NEXT order.
    public static func rate(for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars: return max(item.bpm, 1) / 60
        case .seconds: return 1
        case .order: return 0
        }
    }

    /// Position for a number of quarter notes from a MIDI clock.
    public static func position(beats: Double, for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars, .order: return beats
        case .seconds: return beats * 60 / max(item.bpm, 1)
        }
    }

    /// Position for elapsed seconds.
    public static func position(seconds: Double, for item: RundownItem) -> Double {
        switch item.timeBase {
        case .bars: return seconds * max(item.bpm, 1) / 60
        case .seconds, .order: return seconds
        }
    }
}
