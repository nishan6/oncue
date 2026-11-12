import Foundation

/// MIDI Time Code: quarter-frame messages (F1 0n) and full-frame SysEx (F0 7F 7F 01 01 hh mm ss ff F7).
/// Gives seconds since midnight, like the LTC decoder.
public struct MTCDecoder {
    private var pieces = [Int](repeating: 0, count: 8)
    private var seen: UInt8 = 0
    private var lastPiece = -1
    public private(set) var fps: Double = 25

    public init() {}

    static func fps(forRateBits bits: Int) -> Double {
        switch bits {
        case 0: return 24
        case 1: return 25
        case 2: return 29.97
        default: return 30
        }
    }

    /// A quarter-frame data byte (the byte after F1). Returns the time when a full set of eight has
    /// arrived in order: the time code describes the frame two frames ago, so two frames are added.
    public mutating func quarterFrame(_ data: UInt8) -> Double? {
        let piece = Int(data >> 4) & 0x07
        let value = Int(data & 0x0F)
        if piece == 0 || piece == lastPiece + 1 {
            if piece == 0 { seen = 0 }
            pieces[piece] = value
            seen |= 1 << piece
        } else {
            seen = 0
        }
        lastPiece = piece
        guard piece == 7, seen == 0xFF else { return nil }
        let frames = pieces[0] | (pieces[1] << 4)
        let seconds = pieces[2] | (pieces[3] << 4)
        let minutes = pieces[4] | (pieces[5] << 4)
        let hours = pieces[6] | ((pieces[7] & 0x01) << 4)
        fps = Self.fps(forRateBits: (pieces[7] >> 1) & 0x03)
        return Double(hours * 3600 + minutes * 60 + seconds) + Double(frames + 2) / fps
    }

    /// A full-frame SysEx message (from F0 to F7). Sent when the source locates or stops.
    public mutating func fullFrame(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 10, bytes[0] == 0xF0, bytes[1] == 0x7F, bytes[3] == 0x01, bytes[4] == 0x01 else { return nil }
        let hr = Int(bytes[5])
        fps = Self.fps(forRateBits: (hr >> 5) & 0x03)
        seen = 0
        lastPiece = -1
        return Double((hr & 0x1F) * 3600 + Int(bytes[6]) * 60 + Int(bytes[7])) + Double(bytes[8]) / fps
    }

    /// The eight quarter-frame data bytes for a time (for tests and for sending MTC).
    public static func quarterFrames(hours: Int, minutes: Int, seconds: Int, frames: Int, rateBits: Int) -> [UInt8] {
        let values = [frames & 0x0F, frames >> 4, seconds & 0x0F, seconds >> 4, minutes & 0x0F, minutes >> 4,
                      hours & 0x0F, (hours >> 4) | (rateBits << 1)]
        return values.enumerated().map { UInt8(($0.offset << 4) | ($0.element & 0x0F)) }
    }
}
