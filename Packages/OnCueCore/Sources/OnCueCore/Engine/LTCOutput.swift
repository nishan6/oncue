import Foundation
import AVFoundation
import CoreAudio

/// Streams LTC audio: asks for the time at each frame boundary, so it can follow the clock or a song.
public struct LTCGenerator {
    public let sampleRate: Double
    public let fps: Double
    public var amplitude: Float = 0.5
    private var bits: [UInt8] = []
    private var bitIndex = 80
    private var position: Double = 0     // samples into the current bit
    private var level: Float = 0.5
    private var halfDone = false
    private var perBit: Double { sampleRate / (fps * 80) }

    public init(sampleRate: Double, fps: Double, amplitude: Float = 0.5) {
        self.sampleRate = sampleRate
        self.fps = fps
        self.amplitude = amplitude
        level = amplitude
    }

    /// Fills `count` samples. `time` gives the timecode (seconds since midnight) for each new frame.
    public mutating func render(into out: UnsafeMutablePointer<Float>, count: Int, time: () -> Double) {
        for i in 0..<count {
            if bitIndex >= 80 {
                bits = Self.frame(at: time(), fps: fps).bits
                bitIndex = 0
                position = 0
                halfDone = false
                level = -level
            }
            out[i] = level
            position += 1
            if !halfDone && position >= perBit / 2 {
                halfDone = true
                if bits[bitIndex] == 1 { level = -level }
            }
            if position >= perBit {
                position -= perBit
                bitIndex += 1
                halfDone = false
                if bitIndex < 80 { level = -level }
            }
        }
    }

    public mutating func render(count: Int, time: () -> Double) -> [Float] {
        var out = [Float](repeating: 0, count: count)
        out.withUnsafeMutableBufferPointer { render(into: $0.baseAddress!, count: count, time: time) }
        return out
    }

    /// The LTC frame for a time (seconds since midnight), wrapping at 24 hours.
    public static func frame(at seconds: Double, fps: Double) -> LTCFrame {
        let f = max(fps.rounded(), 1)
        // A tiny allowance so a time that should land exactly on a frame (e.g. 7199.8 s at 25 fps)
        // is not rounded down to the frame before by floating-point error.
        let total = Int((max(seconds, 0) * f + 1e-6).rounded(.down)) % Int(86_400 * f)
        let ff = total % Int(f), s = total / Int(f)
        return LTCFrame(hours: s / 3600, minutes: (s % 3600) / 60, seconds: s % 60, frames: ff)
    }
}

/// What the LTC output carries.
public enum LTCOutputMode: String, Codable, CaseIterable, Identifiable {
    case off, timeOfDay, song
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .off: return "Off"
        case .timeOfDay: return "Time of day"
        case .song: return "Song position (from its LTC start, or 01:00:00:00)"
        }
    }
}

/// Plays LTC on an audio output (both channels of the chosen device).
public final class LTCOutput {
    public private(set) var lastError: String?
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let lock = NSLock()
    private var anchor: (seconds: Double, at: Double, running: Bool) = (0, 0, false)
    private let mode: LTCOutputMode

    public init(mode: LTCOutputMode) { self.mode = mode }

    /// Song mode: the timecode at this moment and whether it is moving.
    public func set(seconds: Double, running: Bool) {
        lock.lock()
        anchor = (seconds, ProcessInfo.processInfo.systemUptime, running)
        lock.unlock()
    }

    private func now() -> Double {
        switch mode {
        case .timeOfDay, .off:
            let c = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
            let hours: Int = c.hour ?? 0
            let minutes: Int = c.minute ?? 0
            let secs: Int = c.second ?? 0
            let whole: Int = hours * 3600 + minutes * 60 + secs
            let fraction: Double = Double(c.nanosecond ?? 0) / 1e9
            return Double(whole) + fraction
        case .song:
            lock.lock()
            let a = anchor
            lock.unlock()
            return a.running ? a.seconds + (ProcessInfo.processInfo.systemUptime - a.at) : a.seconds
        }
    }

    public func start(deviceUID: String, fps: Double) {
        guard mode != .off else { return }
        let output = engine.outputNode
        if !deviceUID.isEmpty, let id = LTCInput.deviceID(forUID: deviceUID), let unit = output.audioUnit {
            var device = id
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &device, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let rate = output.outputFormat(forBus: 0).sampleRate > 0 ? output.outputFormat(forBus: 0).sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return }
        var generator = LTCGenerator(sampleRate: rate, fps: fps)
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            guard let self, let data = list.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            generator.render(into: data, count: Int(frameCount), time: self.now)
            for k in 1..<list.count {
                if let other = list[k].mData { memcpy(other, data, Int(frameCount) * MemoryLayout<Float>.size) }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        do {
            try engine.start()
        } catch {
            lastError = "LTC output couldn't start: \(error.localizedDescription)"
        }
    }

    public func stop() {
        engine.stop()
        if let source { engine.detach(source) }
        source = nil
    }
}
