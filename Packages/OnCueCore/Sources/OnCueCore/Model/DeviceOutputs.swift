import Foundation

// MARK: - Device commands from cues
//
// A "Device commands" track sends MIDI, MIDI Show Control, TCP/UDP strings, HTTP requests,
// serial strings and DMX levels (Art-Net or sACN) to targets set up once per show. Each target
// can be simulated: OnCue shows what it would send and nothing leaves the Mac.

public enum DeviceTargetKind: String, Codable, CaseIterable, Identifiable {
    case midi, tcp, udp, http, serial, artNet, sACN, hyperDeck
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .midi: return "MIDI out"
        case .tcp: return "TCP"
        case .udp: return "UDP"
        case .http: return "HTTP"
        case .serial: return "Serial (RS-232/422)"
        case .artNet: return "Art-Net DMX"
        case .sACN: return "sACN DMX (E1.31)"
        case .hyperDeck: return "HyperDeck"
        }
    }
    /// What a cue can send to this kind of target.
    public var sendKinds: [DeviceSendKind] {
        switch self {
        case .midi: return [.midiNote, .midiCC, .midiProgram, .msc]
        case .tcp, .udp, .serial: return [.text]
        case .http: return [.http]
        case .artNet, .sACN: return [.dmx]
        case .hyperDeck: return [.hyperDeck]
        }
    }
}

public enum LineEnding: String, Codable, CaseIterable, Identifiable {
    case none, cr, lf, crlf
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .none: return "None"
        case .cr: return "CR"
        case .lf: return "LF"
        case .crlf: return "CR LF"
        }
    }
    public var bytes: [UInt8] {
        switch self {
        case .none: return []
        case .cr: return [0x0D]
        case .lf: return [0x0A]
        case .crlf: return [0x0D, 0x0A]
        }
    }
}

public struct DeviceTarget: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var kind: DeviceTargetKind = .udp
    public var host: String = ""
    public var port: Int = 0
    /// MIDI destination name (as macOS lists it).
    public var midiDestination: String = ""
    /// Serial device path ("/dev/cu.usbserial-…") and settings.
    public var serialPath: String = ""
    public var baud: Int = 9600
    public var lineEnding: LineEnding = .none
    /// HTTP base address ("http://192.168.10.20:8000").
    public var baseURL: String = ""
    /// DMX universe: Art-Net port address (0 = first), or sACN universe (1–63999).
    public var universe: Int = 0
    /// Nothing leaves the Mac; what would be sent is shown in Live.
    public var simulated = false

    public init(name: String, kind: DeviceTargetKind) {
        self.name = name
        self.kind = kind
        switch kind {
        case .artNet: port = 6454; universe = 0
        case .sACN: port = 5568; universe = 1
        case .http: baseURL = "http://"
        case .hyperDeck: port = 9993
        default: break
        }
    }
}

public enum DeviceSendKind: String, Codable, CaseIterable, Identifiable {
    case midiNote, midiCC, midiProgram, msc, text, http, dmx, hyperDeck
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .midiNote: return "MIDI note"
        case .midiCC: return "MIDI CC"
        case .midiProgram: return "Program change"
        case .msc: return "MIDI Show Control"
        case .text: return "String"
        case .http: return "HTTP request"
        case .dmx: return "DMX level"
        case .hyperDeck: return "HyperDeck"
        }
    }
}

/// HyperDeck transport commands (Blackmagic HyperDeck Ethernet Protocol, TCP 9993).
public enum HyperDeckAction: String, Codable, CaseIterable, Identifiable {
    case record, stop, play, playLoop, gotoClip, nextClip, previousClip
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .record: return "Record"
        case .stop: return "Stop"
        case .play: return "Play"
        case .playLoop: return "Play looped"
        case .gotoClip: return "Go to clip"
        case .nextClip: return "Next clip"
        case .previousClip: return "Previous clip"
        }
    }
}

public enum HTTPMethod: String, Codable, CaseIterable, Identifiable {
    case get = "GET", post = "POST", put = "PUT"
    public var id: String { rawValue }
}

/// What one cue sends.
public struct DeviceSend: Codable, Hashable {
    public var kind: DeviceSendKind = .text
    /// MIDI channel 1–16.
    public var channel: Int = 1
    /// Note, CC or program number (program 1 = the first).
    public var number: Int = 0
    /// Velocity or CC value.
    public var value: Int = 127
    public var msc: MSCCommand = .go
    /// MSC cue number ("12.5"), empty for none; cue list optional.
    public var mscCue: String = ""
    public var mscList: String = ""
    /// MSC device ID; 127 = all devices.
    public var mscDevice: Int = 127
    /// MSC command format; 0x01 = lighting (general), 0x7F = all types.
    public var mscFormat: Int = 0x01
    /// String for TCP/UDP/serial. \r \n \t \\ and \xHH escapes are understood.
    public var text: String = ""
    public var method: HTTPMethod = .get
    /// Path after the target's base address, or a full URL.
    public var path: String = ""
    public var body: String = ""
    /// DMX channel 1–512, level 0–255, fade in seconds.
    public var dmxChannel: Int = 1
    public var dmxLevel: Int = 255
    public var dmxFade: Double = 0
    public var hyperDeck: HyperDeckAction = .record
    /// Clip number for Go to clip; file name for Record (empty = the deck's own naming).
    public var clip: Int = 1
    public var recordName: String = ""

    public init(kind: DeviceSendKind = .text) { self.kind = kind }

    public var summary: String {
        switch kind {
        case .midiNote: return "Note \(number) vel \(value) ch \(channel)"
        case .midiCC: return "CC \(number) = \(value) ch \(channel)"
        case .midiProgram: return "Program \(number) ch \(channel)"
        case .msc: return "MSC \(msc.label)" + (mscCue.isEmpty ? "" : " \(mscCue)") + (mscList.isEmpty ? "" : "/\(mscList)")
        case .text: return text.isEmpty ? "(empty string)" : text
        case .http: return "\(method.rawValue) \(path)"
        case .dmx: return "Ch \(dmxChannel) @ \(dmxLevel)" + (dmxFade > 0 ? " in \(String(format: "%g", dmxFade)) s" : "")
        case .hyperDeck:
            switch hyperDeck {
            case .gotoClip: return "Go to clip \(clip)"
            case .record: return recordName.isEmpty ? "Record" : "Record “\(recordName)”"
            default: return hyperDeck.label
            }
        }
    }
}

// MARK: - Wire formats

public enum DeviceWire {
    /// MIDI bytes for note on, CC or program change.
    public static func midi(_ s: DeviceSend) -> [UInt8]? {
        let ch = UInt8(max(1, min(s.channel, 16)) - 1)
        switch s.kind {
        case .midiNote: return [0x90 | ch, UInt8(clamping: max(0, min(s.number, 127))), UInt8(clamping: max(0, min(s.value, 127)))]
        case .midiCC: return [0xB0 | ch, UInt8(clamping: max(0, min(s.number, 127))), UInt8(clamping: max(0, min(s.value, 127)))]
        case .midiProgram: return [0xC0 | ch, UInt8(clamping: max(0, min(s.number - 1, 127)))]
        case .msc: return msc(s)
        default: return nil
        }
    }

    /// MIDI Show Control: F0 7F <device> 02 <format> <command> [cue 00 list] F7.
    public static func msc(_ s: DeviceSend) -> [UInt8] {
        var out: [UInt8] = [0xF0, 0x7F, UInt8(clamping: max(0, min(s.mscDevice, 127))), 0x02,
                            UInt8(clamping: max(0, min(s.mscFormat, 127))), UInt8(s.msc.rawValue)]
        let cue = s.mscCue.filter { $0.isNumber || $0 == "." }
        if !cue.isEmpty {
            out += Array(cue.utf8)
            let list = s.mscList.filter { $0.isNumber || $0 == "." }
            if !list.isEmpty { out += [0x00] + Array(list.utf8) }
        }
        out.append(0xF7)
        return out
    }

    /// A string with escapes turned into bytes, plus the line ending.
    public static func text(_ s: String, ending: LineEnding) -> [UInt8] {
        var out: [UInt8] = []
        let chars = Array(s.unicodeScalars)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\", i + 1 < chars.count {
                let n = chars[i + 1]
                switch n {
                case "r": out.append(0x0D); i += 2; continue
                case "n": out.append(0x0A); i += 2; continue
                case "t": out.append(0x09); i += 2; continue
                case "\\": out.append(0x5C); i += 2; continue
                case "x" where i + 3 < chars.count:
                    if let b = UInt8(String(chars[i + 2]) + String(chars[i + 3]), radix: 16) {
                        out.append(b); i += 4; continue
                    }
                default: break
                }
            }
            out += Array(String(c).utf8)
            i += 1
        }
        return out + ending.bytes
    }

    /// HyperDeck Ethernet Protocol command line.
    public static func hyperDeck(_ s: DeviceSend) -> String {
        switch s.hyperDeck {
        case .record:
            let name = s.recordName.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "record\r\n" : "record: name: \(name)\r\n"
        case .stop: return "stop\r\n"
        case .play: return "play\r\n"
        case .playLoop: return "play: loop: true\r\n"
        case .gotoClip: return "goto: clip id: \(max(1, s.clip))\r\n"
        case .nextClip: return "goto: clip id: +1\r\n"
        case .previousClip: return "goto: clip id: -1\r\n"
        }
    }

    /// The URL for an HTTP cue: a full URL in the path wins, otherwise base + path.
    public static func url(_ s: DeviceSend, base: String) -> URL? {
        let path = s.path.trimmingCharacters(in: .whitespaces)
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") { return URL(string: path) }
        var b = base.trimmingCharacters(in: .whitespaces)
        while b.hasSuffix("/") { b.removeLast() }
        let p = path.isEmpty ? "" : (path.hasPrefix("/") ? path : "/" + path)
        return URL(string: b + p)
    }

    /// ArtDmx packet for a universe (port address), all 512 channels.
    public static func artDmx(universe: Int, levels: [UInt8], sequence: UInt8) -> [UInt8] {
        var data = Array(levels.prefix(512))
        if data.count < 512 { data += Array(repeating: 0, count: 512 - data.count) }
        var p: [UInt8] = Array("Art-Net".utf8) + [0]
        p += [0x00, 0x50]                    // OpDmx, little endian
        p += [0x00, 14]                      // protocol version 14
        p += [sequence, 0]                   // sequence, physical
        p += [UInt8(universe & 0xFF), UInt8((universe >> 8) & 0x7F)]
        p += [0x02, 0x00]                    // length 512, big endian
        return p + data
    }

    /// E1.31 (sACN) data packet: root, framing and DMP layers, 512 channels.
    public static func sACN(universe: Int, levels: [UInt8], sequence: UInt8, cid: UUID, source: String = "OnCue",
                            priority: UInt8 = 100) -> [UInt8] {
        var data = Array(levels.prefix(512))
        if data.count < 512 { data += Array(repeating: 0, count: 512 - data.count) }
        func be16(_ v: Int) -> [UInt8] { [UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        func flagsLength(_ length: Int) -> [UInt8] { be16(0x7000 | (length & 0x0FFF)) }
        let dmpLength = 10 + 1 + data.count
        let framingLength = 77 + dmpLength
        let rootLength = 22 + framingLength
        var p: [UInt8] = be16(0x0010) + be16(0x0000)
        p += Array("ASC-E1.17".utf8) + [0, 0, 0]
        p += flagsLength(rootLength) + [0x00, 0x00, 0x00, 0x04]            // VECTOR_ROOT_E131_DATA
        let u = cid.uuid
        p += [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
        p += flagsLength(framingLength) + [0x00, 0x00, 0x00, 0x02]         // VECTOR_E131_DATA_PACKET
        var name = Array(source.utf8.prefix(63))
        name += Array(repeating: 0, count: 64 - name.count)
        p += name
        p += [priority] + be16(0) + [sequence, 0x00] + be16(max(1, min(universe, 63999)))
        p += flagsLength(dmpLength) + [0x02, 0xA1] + be16(0x0000) + be16(0x0001) + be16(data.count + 1)
        p += [0x00] + data                                                  // start code 0
        return p
    }

    /// sACN multicast address for a universe: 239.255.hi.lo.
    public static func sACNMulticast(universe: Int) -> String {
        let u = max(1, min(universe, 63999))
        return "239.255.\(u >> 8).\(u & 0xFF)"
    }
}

/// DMX levels per universe with fades, sent at a steady rate by the engine.
public struct DMXMixer {
    private var levels: [UUID: [Double]] = [:]
    private var fades: [String: (from: Double, to: Double, start: Double, duration: Double)] = [:]

    public init() {}

    public mutating func set(target: UUID, channel: Int, level: Int, fade: Double, now: Double) {
        guard (1...512).contains(channel) else { return }
        let key = "\(target)#\(channel)"
        let current = value(target: target, channel: channel)
        let to = Double(max(0, min(level, 255)))
        if fade <= 0 {
            fades[key] = nil
            write(target, channel, to)
        } else {
            fades[key] = (current, to, now, fade)
        }
    }

    public func value(target: UUID, channel: Int) -> Double {
        levels[target]?[channel - 1] ?? 0
    }

    /// Advances fades. Returns the targets whose levels changed.
    public mutating func advance(now: Double) -> Set<UUID> {
        var changed: Set<UUID> = []
        for (key, f) in fades {
            let parts = key.split(separator: "#")
            guard parts.count == 2, let target = UUID(uuidString: String(parts[0])), let channel = Int(parts[1]) else { continue }
            let t = min(max((now - f.start) / f.duration, 0), 1)
            write(target, channel, f.from + (f.to - f.from) * t)
            changed.insert(target)
            if t >= 1 { fades[key] = nil }
        }
        return changed
    }

    public func bytes(target: UUID) -> [UInt8] {
        (levels[target] ?? Array(repeating: 0, count: 512)).map { UInt8(max(0, min($0.rounded(), 255))) }
    }

    public var fading: Bool { !fades.isEmpty }

    private mutating func write(_ target: UUID, _ channel: Int, _ v: Double) {
        var u = levels[target] ?? Array(repeating: 0, count: 512)
        u[channel - 1] = v
        levels[target] = u
    }
}
