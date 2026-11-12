import Foundation
import AVFoundation
import CoreAudio

// SMPTE linear timecode (LTC) from an audio input.
//
// LTC is biphase-mark coded: the level flips at every bit boundary, and a 1 has an extra flip in
// the middle of its bit. Each frame is 80 bits ending in the sync word 0011 1111 1111 1101.

/// One decoded LTC frame.
public struct LTCFrame: Equatable {
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var frames: Int
    public var dropFrame: Bool

    public init(hours: Int, minutes: Int, seconds: Int, frames: Int, dropFrame: Bool = false) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
        self.dropFrame = dropFrame
    }

    /// Seconds since midnight at a nominal frame rate.
    public func seconds(fps: Double) -> Double {
        Double(hours * 3600 + minutes * 60 + seconds) + Double(frames) / max(fps.rounded(), 1)
    }

    /// The 80 bits of the frame, in transmission order (sync word last).
    public var bits: [UInt8] {
        var b = [UInt8](repeating: 0, count: 80)
        func put(_ value: Int, at start: Int, count: Int) {
            for k in 0..<count { b[start + k] = UInt8((value >> k) & 1) }
        }
        put(frames % 10, at: 0, count: 4)
        put(frames / 10, at: 8, count: 2)
        b[10] = dropFrame ? 1 : 0
        put(seconds % 10, at: 16, count: 4)
        put(seconds / 10, at: 24, count: 3)
        put(minutes % 10, at: 32, count: 4)
        put(minutes / 10, at: 40, count: 3)
        put(hours % 10, at: 48, count: 4)
        put(hours / 10, at: 56, count: 2)
        for (k, bit) in LTCDecoder.syncWord.enumerated() { b[64 + k] = bit }
        return b
    }
}

/// Decodes LTC from audio samples. Feed it samples in order; it reports each complete frame.
public struct LTCDecoder {
    static let syncWord: [UInt8] = [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1]

    private let sampleRate: Double
    private let nominalPeriod: Double
    /// Samples per bit, adapted to the incoming signal (LTC speed varies slightly).
    private var period: Double
    private var high = false
    private var started = false
    private var sinceTransition = 0
    private var halfPending = false
    private var bits: [UInt8] = []
    private let threshold: Float

    public init(sampleRate: Double, fps: Double, threshold: Float = 0.02) {
        self.sampleRate = sampleRate
        nominalPeriod = sampleRate / (max(fps, 1) * 80)
        period = nominalPeriod
        self.threshold = threshold
    }

    /// Processes samples; returns the frames completed within them.
    public mutating func process(_ samples: UnsafeBufferPointer<Float>) -> [LTCFrame] {
        var found: [LTCFrame] = []
        for s in samples {
            sinceTransition += 1
            var transition = false
            if !started {
                if s > threshold { high = true; started = true } else if s < -threshold { high = false; started = true }
                continue
            }
            if high, s < -threshold { high = false; transition = true }
            else if !high, s > threshold { high = true; transition = true }
            guard transition else {
                if Double(sinceTransition) > period * 3 { reset() }
                continue
            }
            let d = Double(sinceTransition)
            sinceTransition = 0
            if d > period * 0.75 {
                // A full bit cell: a 0 (a half cell left waiting means we lost alignment).
                if halfPending { halfPending = false; bits.removeAll(); continue }
                if d < period * 1.5 { period = period * 0.9 + d * 0.1 }
                if let frame = push(0) { found.append(frame) }
            } else {
                if d > period * 0.25 { period = period * 0.9 + d * 2 * 0.1 }
                if halfPending {
                    halfPending = false
                    if let frame = push(1) { found.append(frame) }
                } else {
                    halfPending = true
                }
            }
            // Keep the adaptive period within reason.
            period = min(max(period, nominalPeriod * 0.6), nominalPeriod * 1.6)
        }
        return found
    }

    public mutating func process(_ samples: [Float]) -> [LTCFrame] {
        samples.withUnsafeBufferPointer { process($0) }
    }

    private mutating func reset() {
        halfPending = false
        bits.removeAll()
        period = nominalPeriod
    }

    private mutating func push(_ bit: UInt8) -> LTCFrame? {
        bits.append(bit)
        if bits.count > 80 { bits.removeFirst(bits.count - 80) }
        guard bits.count == 80, Array(bits[64..<80]) == Self.syncWord else { return nil }
        let frame = Self.decode(bits)
        bits.removeAll()
        return frame
    }

    static func decode(_ b: [UInt8]) -> LTCFrame? {
        func value(_ start: Int, _ count: Int) -> Int {
            (0..<count).reduce(0) { $0 | Int(b[start + $1]) << $1 }
        }
        let frames = value(0, 4) + 10 * value(8, 2)
        let seconds = value(16, 4) + 10 * value(24, 3)
        let minutes = value(32, 4) + 10 * value(40, 3)
        let hours = value(48, 4) + 10 * value(56, 2)
        guard frames < 60, seconds < 60, minutes < 60, hours < 24 else { return nil }
        return LTCFrame(hours: hours, minutes: minutes, seconds: seconds, frames: frames, dropFrame: b[10] == 1)
    }
}

/// Generates LTC audio (used by the tests, and handy for checking an input without a source).
public enum LTCEncoder {
    public static func samples(frames: [LTCFrame], fps: Double, sampleRate: Double, amplitude: Float = 0.5) -> [Float] {
        let perBit = sampleRate / (fps * 80)
        var out: [Float] = []
        var level = amplitude
        var clock = 0.0
        for frame in frames {
            for bit in frame.bits {
                level = -level
                let start = clock
                let mid = start + perBit / 2
                let end = start + perBit
                while Double(out.count) < mid { out.append(level) }
                if bit == 1 { level = -level }
                while Double(out.count) < end { out.append(level) }
                clock = end
            }
        }
        // A real stream keeps going: the next frame's first edge completes the last bit.
        level = -level
        let tail = clock + perBit
        while Double(out.count) < tail { out.append(level) }
        return out
    }
}

/// Captures an audio input and decodes LTC from one channel. Calls `onTimecode` on the main thread
/// with seconds since midnight for every frame.
final class LTCInput {
    var onTimecode: ((Double) -> Void)?
    private(set) var lastError: String?

    private let deviceUID: String
    private let channel: Int
    private let fps: Double
    private let engine = AVAudioEngine()
    private var decoder: LTCDecoder?
    private var running = false

    init(deviceUID: String, channel: Int, fps: Double) {
        self.deviceUID = deviceUID
        self.channel = channel
        self.fps = fps
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.begin() } else { self.lastError = "Microphone access was not allowed (System Settings > Privacy & Security > Microphone)." }
            }
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }

    private func begin() {
        let input = engine.inputNode
        if !deviceUID.isEmpty, let id = Self.deviceID(forUID: deviceUID), let unit = input.audioUnit {
            var device = id
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &device, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { lastError = "The audio input is not available."; return }
        decoder = LTCDecoder(sampleRate: format.sampleRate, fps: fps)
        let channelIndex = min(max(channel, 0), Int(format.channelCount) - 1)
        let fps = self.fps
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData else { return }
            let samples = UnsafeBufferPointer(start: data[channelIndex], count: Int(buffer.frameLength))
            guard var decoder = self.decoder else { return }
            let frames = decoder.process(samples)
            self.decoder = decoder
            guard let last = frames.last else { return }
            let seconds = last.seconds(fps: fps)
            DispatchQueue.main.async { self.onTimecode?(seconds) }
        }
        do {
            try engine.start()
            running = true
        } catch {
            lastError = "Could not start the audio input: \(error.localizedDescription)"
        }
    }

    /// Finds a Core Audio device by its unique ID.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return nil }
        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                                        mScope: kAudioObjectPropertyScopeGlobal,
                                                        mElement: kAudioObjectPropertyElementMain)
            var cf: Unmanaged<CFString>?
            var cfSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &cfSize, &cf) == noErr,
                  let value = cf?.takeRetainedValue() else { continue }
            if (value as String) == uid { return id }
        }
        return nil
    }
}

/// An audio input device that can carry LTC.
public struct AudioInputDevice: Identifiable, Hashable {
    public var id: String { uid }
    public let uid: String
    public let name: String
    public let channels: Int

    /// Audio devices with at least one input channel.
    public static func all() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            let channels = inputChannels(id)
            guard channels > 0, let uid = string(id, kAudioDevicePropertyDeviceUID),
                  let name = string(id, kAudioObjectPropertyName) else { return nil }
            return AudioInputDevice(uid: uid, name: name, channels: channels)
        }
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var cf: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &cf) == noErr, let value = cf?.takeRetainedValue() else { return nil }
        return value as String
    }

    private static func inputChannels(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioObjectPropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
