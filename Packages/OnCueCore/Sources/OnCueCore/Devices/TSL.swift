import Foundation

// MARK: - TSL UMD tally (3.1, 4.0, 5.0)
//
// Encoders and decoders for the TSL UMD protocol family used by Ross, Grass Valley, multiviewers
// and most tally systems. Built from TSL's published protocol documents; marked Built until it
// has driven a real tally system.

/// One tally display: program (red), preview (green), and the text shown on the UMD.
public struct TallyState: Equatable, Hashable {
    public var index: Int
    public var program: Bool
    public var preview: Bool
    public var text: String

    public init(index: Int, program: Bool = false, preview: Bool = false, text: String = "") {
        self.index = index
        self.program = program
        self.preview = preview
        self.text = text
    }
}

public enum TSLVersion: String, Codable, CaseIterable, Identifiable {
    case v31, v40, v50
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .v31: return "TSL UMD 3.1"
        case .v40: return "TSL UMD 4.0"
        case .v50: return "TSL UMD 5.0"
        }
    }
}

public enum TSL {
    // MARK: 3.1: 18 bytes. Address (0–126) + 0x80, control byte, 16 ASCII characters.
    // Control: bit 0 tally 1, bit 1 tally 2, bit 2 tally 3, bit 3 tally 4, bits 4–5 brightness.
    // Convention: tally 1 = program (red), tally 2 = preview (green).

    public static func encode31(_ t: TallyState, brightness: Int = 3) -> [UInt8] {
        let address = UInt8(max(0, min(t.index, 126))) | 0x80
        var control: UInt8 = 0
        if t.program { control |= 0x01 }
        if t.preview { control |= 0x02 }
        control |= UInt8(max(0, min(brightness, 3))) << 4
        return [address, control] + ascii(t.text, length: 16)
    }

    public static func decode31(_ b: [UInt8]) -> TallyState? {
        guard b.count >= 18, b[0] & 0x80 != 0 else { return nil }
        let text = String(bytes: b[2..<18].map { $0 >= 0x20 && $0 < 0x7F ? $0 : 0x20 }, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return TallyState(index: Int(b[0] & 0x7F), program: b[1] & 0x01 != 0, preview: b[1] & 0x02 != 0, text: text)
    }

    // MARK: 4.0: the 3.1 message, then a checksum, a byte count and display data (XDATA) for two
    // displays: tally colours for the left and right lamps (2 bits each: 0 off, 1 red, 2 green, 3 amber).

    public static func encode40(_ t: TallyState, brightness: Int = 3) -> [UInt8] {
        var msg = encode31(t, brightness: brightness)
        // Checksum: 2's complement of the sum of the bytes, modulo 128 (TSL 4.0 spec).
        let sum = msg.reduce(0) { ($0 + Int($1)) & 0xFF }
        let checksum = UInt8((-sum) & 0x7F)
        let colour: UInt8 = t.program ? 1 : (t.preview ? 2 : 0)
        // VBC: bits 0–3 = number of XDATA bytes (2), bits 4–6 = minor version (0).
        let vbc: UInt8 = 0x02
        // XDATA per display: bits 0–1 right tally, 2–3 text tally, 4–5 left tally.
        let display = colour | (colour << 4)
        msg += [checksum, vbc, display, display]
        return msg
    }

    // MARK: 5.0: little-endian. PBC (packet byte count, excluding itself), version 0, flags
    // (bit 0 = UTF-16LE text), screen, then DMSG: index (2 bytes), control (2 bytes), length (2),
    // text. Control bits 0–1 right tally, 2–3 text tally, 4–5 left tally, 6–7 brightness.
    // Over TCP each packet is wrapped in DLE/STX framing.

    public static func encode50(_ t: TallyState, screen: Int = 0, brightness: Int = 3, unicode: Bool = false) -> [UInt8] {
        let colour: UInt16 = t.program ? 1 : (t.preview ? 2 : 0)
        var control: UInt16 = colour | (colour << 2) | (colour << 4)
        control |= UInt16(max(0, min(brightness, 3))) << 6
        let text: [UInt8] = unicode
            ? Array(t.text.utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
            : Array(t.text.unicodeScalars.map { $0.isASCII ? UInt8($0.value) : 0x3F })
        var body: [UInt8] = [0x00, unicode ? 0x01 : 0x00]           // version, flags
        body += le16(UInt16(max(0, min(screen, 65534))))
        body += le16(UInt16(max(0, min(t.index, 65534))))
        body += le16(control)
        body += le16(UInt16(text.count))
        body += text
        return le16(UInt16(body.count)) + body
    }

    public static func decode50(_ b: [UInt8]) -> (screen: Int, tallies: [TallyState])? {
        guard b.count >= 6 else { return nil }
        let pbc = Int(b[0]) | Int(b[1]) << 8
        guard b.count >= pbc + 2, b[2] == 0x00 else { return nil }
        let unicode = b[3] & 0x01 != 0
        let screen = Int(b[4]) | Int(b[5]) << 8
        var k = 6
        var out: [TallyState] = []
        while k + 6 <= pbc + 2 {
            let index = Int(b[k]) | Int(b[k + 1]) << 8
            let control = Int(b[k + 2]) | Int(b[k + 3]) << 8
            let length = Int(b[k + 4]) | Int(b[k + 5]) << 8
            k += 6
            guard k + length <= b.count else { return nil }
            let raw = Array(b[k..<(k + length)])
            k += length
            let text: String
            if unicode {
                var units: [UInt16] = []
                var i = 0
                while i + 1 < raw.count { units.append(UInt16(raw[i]) | UInt16(raw[i + 1]) << 8); i += 2 }
                text = String(decoding: units, as: UTF16.self)
            } else {
                text = String(decoding: raw, as: UTF8.self)
            }
            // Text tally colour decides: 1 red = program, 2 green = preview, 3 amber = both.
            let colour = (control >> 2) & 0x03
            out.append(TallyState(index: index, program: colour == 1 || colour == 3, preview: colour == 2 || colour == 3, text: text))
        }
        return (screen, out)
    }

    /// TSL 5.0 over TCP: DLE (0xFE) STX (0x02) before each packet, and any 0xFE in it doubled.
    public static func frameTCP(_ packet: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [0xFE, 0x02]
        for byte in packet {
            out.append(byte)
            if byte == 0xFE { out.append(0xFE) }
        }
        return out
    }

    private static func ascii(_ s: String, length: Int) -> [UInt8] {
        var bytes = s.unicodeScalars.map { $0.isASCII && $0.value >= 0x20 ? UInt8($0.value) : 0x3F }
        if bytes.count > length { bytes = Array(bytes.prefix(length)) }
        return bytes + Array(repeating: 0x20, count: length - bytes.count)
    }

    private static func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8)] }
}
