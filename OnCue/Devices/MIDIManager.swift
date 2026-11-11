import Foundation
import CoreMIDI

enum MIDIClockEvent {
    case tick(TimeInterval)
    case start
    case stop
    case resume
    /// Song Position Pointer in 16th notes.
    case songPosition(Int)
}

struct MIDIEndpointInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let ref: MIDIEndpointRef
}

/// CoreMIDI: clock in (Ableton over USB MIDI, IAC or network MIDI sessions),
/// controller in (APC40 mkII or anything else, with MIDI learn) and LED feedback out.
/// Network MIDI shows up here once a session is connected in Audio MIDI Setup > MIDI Network Setup.
final class MIDIManager {
    var onClock: ((MIDIClockEvent) -> Void)?
    var onControl: ((_ channel: Int, _ number: Int, _ isCC: Bool, _ value: Int) -> Void)?
    var onDevicesChanged: (() -> Void)?

    private(set) var sources: [MIDIEndpointInfo] = []
    private(set) var destinations: [MIDIEndpointInfo] = []
    private(set) var lastClockActivity: Date?
    private(set) var lastControlActivity: Date?

    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var connected: [MIDIEndpointRef] = []
    private var clockName = ""
    private var controllerName = ""
    private var destinationName = ""

    private static let clockTag = 1
    private static let controllerTag = 2

    init() {
        MIDIClientCreateWithBlock("OnCue" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
                self?.reconnect()
            }
        }
        MIDIInputPortCreateWithBlock(client, "OnCue In" as CFString, &inPort) { [weak self] list, refCon in
            self?.read(list, tag: Int(bitPattern: refCon))
        }
        MIDIOutputPortCreate(client, "OnCue Out" as CFString, &outPort)
        refresh()
    }

    func refresh() {
        sources = (0..<MIDIGetNumberOfSources()).map { i in
            let ref = MIDIGetSource(i)
            return MIDIEndpointInfo(name: Self.name(of: ref), ref: ref)
        }
        destinations = (0..<MIDIGetNumberOfDestinations()).map { i in
            let ref = MIDIGetDestination(i)
            return MIDIEndpointInfo(name: Self.name(of: ref), ref: ref)
        }
        onDevicesChanged?()
    }

    func configure(clockSource: String, controllerSource: String, controllerDestination: String) {
        let changed = clockSource != clockName || controllerSource != controllerName || controllerDestination != destinationName
        clockName = clockSource
        controllerName = controllerSource
        let destChanged = controllerDestination != destinationName
        destinationName = controllerDestination
        if changed { reconnect() }
        if destChanged { introduceAPC40IfNeeded() }
    }

    private func reconnect() {
        for ref in connected { MIDIPortDisconnectSource(inPort, ref) }
        connected.removeAll()
        for s in sources {
            var tag = 0
            if !clockName.isEmpty && s.name == clockName { tag |= Self.clockTag }
            if !controllerName.isEmpty && s.name == controllerName { tag |= Self.controllerTag }
            guard tag != 0 else { continue }
            MIDIPortConnectSource(inPort, s.ref, UnsafeMutableRawPointer(bitPattern: tag))
            connected.append(s.ref)
        }
    }

    // MARK: Output

    /// Note on to the controller (used for APC40 pad colours).
    func sendNote(channel: Int, note: Int, velocity: Int) {
        sendRaw([UInt8(0x90 | (channel & 0x0F)), UInt8(note & 0x7F), UInt8(velocity & 0x7F)])
    }

    /// APC40 mkII: switch to "Alternate Ableton Live" mode so the host owns every LED.
    func introduceAPC40IfNeeded() {
        guard destinationName.localizedCaseInsensitiveContains("APC40") else { return }
        sendRaw([0xF0, 0x47, 0x7F, 0x29, 0x60, 0x00, 0x04, 0x42, 0x09, 0x07, 0x01, 0xF7])
    }

    private func sendRaw(_ bytes: [UInt8]) {
        guard let dest = destinations.first(where: { $0.name == destinationName })?.ref else { return }
        let size = 1024
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { buffer.deallocate() }
        let list = buffer.bindMemory(to: MIDIPacketList.self, capacity: 1)
        var packet = MIDIPacketListInit(list)
        bytes.withUnsafeBufferPointer { ptr in
            packet = MIDIPacketListAdd(list, size, packet, 0, bytes.count, ptr.baseAddress!)
        }
        MIDISend(outPort, dest, list)
    }

    // MARK: Input

    private func read(_ list: UnsafePointer<MIDIPacketList>, tag: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        for packet in list.unsafeSequence() {
            let len = Int(packet.pointee.length)
            guard len > 0, let offset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data) else { continue }
            let start = (UnsafeRawPointer(packet) + offset).assumingMemoryBound(to: UInt8.self)
            let bytes = Array(UnsafeBufferPointer(start: start, count: len))
            parse(bytes, tag: tag, time: now)
        }
    }

    private func parse(_ bytes: [UInt8], tag: Int, time: TimeInterval) {
        var i = 0
        var runningStatus: UInt8 = 0
        while i < bytes.count {
            let b = bytes[i]
            if b >= 0xF8 {
                // Real-time messages can appear anywhere.
                if tag & Self.clockTag != 0 {
                    let ev: MIDIClockEvent?
                    switch b {
                    case 0xF8: ev = .tick(time)
                    case 0xFA: ev = .start
                    case 0xFB: ev = .resume
                    case 0xFC: ev = .stop
                    default: ev = nil
                    }
                    if let ev { emitClock(ev) }
                }
                i += 1
                continue
            }
            if b == 0xF2, i + 2 < bytes.count {
                let pos = Int(bytes[i + 1]) | Int(bytes[i + 2]) << 7
                if tag & Self.clockTag != 0 { emitClock(.songPosition(pos)) }
                i += 3
                continue
            }
            if b == 0xF0 {
                // Skip SysEx.
                while i < bytes.count && bytes[i] != 0xF7 { i += 1 }
                i += 1
                continue
            }
            var status = b
            var dataStart = i + 1
            if b < 0x80 {
                status = runningStatus
                dataStart = i
            } else {
                runningStatus = b
            }
            let kind = status & 0xF0
            let ch = Int(status & 0x0F)
            switch kind {
            case 0x90, 0x80, 0xB0:
                guard dataStart + 1 < bytes.count else { return }
                let d1 = Int(bytes[dataStart]), d2 = Int(bytes[dataStart + 1])
                if tag & Self.controllerTag != 0 {
                    let isCC = kind == 0xB0
                    let value = kind == 0x80 ? 0 : d2
                    DispatchQueue.main.async {
                        self.lastControlActivity = Date()
                        self.onControl?(ch, d1, isCC, value)
                    }
                }
                i = dataStart + 2
            case 0xC0, 0xD0:
                i = dataStart + 1
            default:
                i = dataStart + 2
            }
        }
    }

    private func emitClock(_ ev: MIDIClockEvent) {
        DispatchQueue.main.async {
            self.lastClockActivity = Date()
            self.onClock?(ev)
        }
    }

    private static func name(of ref: MIDIEndpointRef) -> String {
        var cf: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &cf) == noErr, let s = cf?.takeRetainedValue() {
            return s as String
        }
        return "MIDI \(ref)"
    }
}
