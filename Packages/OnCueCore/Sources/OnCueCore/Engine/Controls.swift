import Foundation

// Hardware controls: MIDI controllers (APC40 mkII by default, anything with MIDI learn), OSC from
// Companion (so a Stream Deck XL), and LED / variable feedback.

public enum ControlMapping {
    /// The binding a MIDI message triggers (presses only: note on or CC above zero).
    public static func binding(for channel: Int, number: Int, isCC: Bool, value: Int, in bindings: [MIDIBinding]) -> MIDIBinding? {
        guard value > 0 else { return nil }
        return bindings.first { $0.channel == channel && $0.number == number && $0.isCC == isCC }
    }

    /// APC40 mkII pad colours (velocity on channel 1): red program, green preview, dim for other cameras.
    public enum APCColor: Int {
        case off = 0, dim = 1, red = 5, green = 21, amber = 9
    }

    /// LED colour per note for the pads bound to "take / preview camera N".
    public static func padColors(show: Show, bindings: [MIDIBinding], program: UUID?, preview: UUID?) -> [Int: APCColor] {
        var colors: [Int: APCColor] = [:]
        for binding in bindings where !binding.isCC && (binding.command == .takeCamera || binding.command == .previewCamera) {
            guard let camera = show.camera(number: binding.cameraNumber) else {
                colors[binding.number] = .off
                continue
            }
            if camera.id == program { colors[binding.number] = .red }
            else if camera.id == preview { colors[binding.number] = .green }
            else { colors[binding.number] = colors[binding.number] ?? .dim }
        }
        return colors
    }

    /// OSC control address: /oncue/<command>[/<camera>] or /oncue/<command> with an int argument.
    public static func command(fromOSC address: String, intArgument: Int?) -> (ControlCommand, Int)? {
        let parts = address.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0].lowercased() == "oncue" else { return nil }
        let name = parts[1].lowercased()
        guard let command = ControlCommand.allCases.first(where: { $0.rawValue.lowercased() == name }) else { return nil }
        let camera = parts.count >= 3 ? Int(parts[2]) : intArgument
        return (command, camera ?? 0)
    }
}

/// Tap tempo: the average of the last taps, reset after a pause.
public struct TapTempo {
    private var taps: [Double] = []
    public init() {}

    @discardableResult
    public mutating func tap(at time: Double) -> Double? {
        if let last = taps.last, time - last > 2 { taps.removeAll() }
        taps.append(time)
        if taps.count > 5 { taps.removeFirst() }
        guard taps.count >= 3 else { return nil }
        let intervals = zip(taps.dropFirst(), taps).map { $0 - $1 }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        return average > 0 ? 60 / average : nil
    }
}

/// Names of MIDI destinations (controller LED output).
public enum MIDIDestinations {
    public static func names() -> [String] {
        let manager = MIDIManager()
        return manager.destinations.map(\.name)
    }
}

/// Listens to a MIDI controller for MIDI learn in the setup screens.
public final class MIDILearnSession {
    public var onMessage: ((_ channel: Int, _ number: Int, _ isCC: Bool) -> Void)?
    private let manager = MIDIManager()

    public init(source: String) {
        manager.configure(clockSource: "", controllerSource: source, controllerDestination: "")
        manager.onControl = { [weak self] channel, number, isCC, value in
            guard value > 0 else { return }
            self?.onMessage?(channel, number, isCC)
        }
    }
}

extension Show {
    /// Maps a control to a MIDI message, replacing any binding for the same action (and camera)
    /// or the same message.
    public mutating func setMIDIBinding(_ command: ControlCommand, camera: Int = 0, channel: Int, number: Int, isCC: Bool) {
        midiBindings.removeAll { ($0.command == command && $0.cameraNumber == camera) || ($0.channel == channel && $0.number == number && $0.isCC == isCC) }
        midiBindings.append(MIDIBinding(command: command, cameraNumber: camera, channel: channel, number: number, isCC: isCC))
    }

    public mutating func removeMIDIBinding(_ command: ControlCommand, camera: Int = 0) {
        midiBindings.removeAll { $0.command == command && $0.cameraNumber == camera }
    }

    public mutating func resetMIDIBindingsToAPC40() {
        midiBindings = MIDIBinding.apc40Defaults()
    }
}
