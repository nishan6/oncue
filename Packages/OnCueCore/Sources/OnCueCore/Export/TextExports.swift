import Foundation

// Text exports: the script and the switch log as CSV, the switch log as a CMX 3600 EDL (for
// conforming ISO recordings in Resolve, Premiere or Final Cut), and a song's shots as a marker EDL.

enum CSV {
    static func field(_ value: String) -> String {
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func line(_ fields: [String]) -> String { fields.map(field).joined(separator: ",") }

    static func document(_ rows: [[String]]) -> String { rows.map(line).joined(separator: "\r\n") + "\r\n" }
}

/// Frame-accurate timecode for EDLs (non-drop frame).
public enum EDLTimecode {
    public static func frames(seconds: Double, fps: Int) -> Int { Int((max(0, seconds) * Double(fps)).rounded()) }

    public static func string(frames: Int, fps: Int) -> String {
        let f = max(fps, 1)
        let total = max(0, frames)
        let ff = total % f
        let s = total / f
        return String(format: "%02d:%02d:%02d:%02d", (s / 3600) % 24, (s % 3600) / 60, s % 60, ff)
    }

    /// "HH:MM:SS:FF" -> frames.
    public static func parse(_ text: String, fps: Int) -> Int? {
        let parts = text.replacingOccurrences(of: ";", with: ":").split(separator: ":").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }
        return ((parts[0] * 60 + parts[1]) * 60 + parts[2]) * fps + parts[3]
    }
}

extension Show {
    /// Every shot of every song and segment, in running order.
    public func scriptCSV() -> String {
        var rows: [[String]] = [["Item", "Kind", "Output", "Shot", "Position", "Section", "Camera", "Camera name",
                                 "Operator", "Transition", "Description", "Operator note", "Length (s)"]]
        for item in items {
            let outs: [OutputConfig?] = outputs.isEmpty ? [nil] : outputs.filter { $0.id == mainOutput?.id || !$0.mirrorMain }
            for output in outs {
                let isMain = output == nil || output?.id == mainOutput?.id
                let shotList: [ShotRow] = isMain ? shotRows(forItem: item.id)
                    : shotSpans(forItem: item.id, outputID: output!.id).map(\.row)
                for row in shotList {
                    let cam = camera(row.cue.cameraID)
                    rows.append([item.title, item.kind.label, output?.name ?? "Program", "\(row.number)", item.format(row.cue.at),
                                 item.section(at: row.cue.at)?.name ?? "",
                                 cam.map { "\($0.number)" } ?? "", cam?.displayName ?? "", cam?.operatorName ?? "",
                                 row.cue.transition == .cut ? "Cut" : "Mix", row.cue.text, row.cue.note,
                                 row.lengthSeconds.map { String(format: "%.2f", $0) } ?? ""])
                }
            }
        }
        return CSV.document(rows)
    }

    /// A song's or segment's shots as timeline markers (Resolve's marker EDL, also read by others),
    /// counted from `start` (default 01:00:00:00). Nil for items whose shots have no time.
    public func markerEDL(itemID: UUID, fps: Int, start: String = "01:00:00:00") -> String? {
        guard let item = item(itemID), item.timeBase != .order else { return nil }
        let origin = EDLTimecode.parse(start, fps: fps) ?? fps * 3600
        var out = "TITLE: \(EDL.title(name + " – " + item.title))\nFCM: NON-DROP FRAME\n\n"
        for (k, row) in shotRows(forItem: item.id).enumerated() {
            let at = origin + EDLTimecode.frames(seconds: item.seconds(for: row.cue.at), fps: fps)
            let a = EDLTimecode.string(frames: at, fps: fps), b = EDLTimecode.string(frames: at + 1, fps: fps)
            let cam = camera(row.cue.cameraID)
            var label = "Shot \(row.number) \(cam?.displayName ?? "No camera")"
            if !row.cue.text.isEmpty { label += " – \(row.cue.text)" }
            out += String(format: "%03d  001      V     C        ", k + 1) + "\(a) \(b) \(a) \(b)\n"
            out += " |C:ResolveColor\(EDL.markerColor(cam?.resolvedColor)) |M:\(EDL.clean(label)) |D:1\n\n"
        }
        return out
    }
}

extension SwitchLog {
    /// Every entry, cuts and scripted calls, in time order.
    public func csv(show: Show, fps: Double? = nil) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let time = DateFormatter()
        time.dateFormat = "HH:mm:ss.SSS"
        var rows: [[String]] = [["Date", "Time of day", "Timecode", "Kind", "Switcher", "Output", "Input", "Camera",
                                 "Camera name", "Item", "Shot", "Mode", "Free mode"]]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            let cam = show.camera(e.cameraID)
            rows.append([iso.string(from: e.date), time.string(from: e.date), e.timecode ?? "",
                         e.kind == .cut ? "Cut" : "Scripted",
                         show.switchers.first { $0.id == e.switcherID }?.name ?? "",
                         show.outputs.first { $0.id == e.outputID }?.name ?? "",
                         e.input.map(String.init) ?? "", cam.map { "\($0.number)" } ?? "", cam?.displayName ?? "",
                         show.item(e.itemID)?.title ?? "", e.shotNumber.map(String.init) ?? "", e.mode,
                         e.freeMode ? "Yes" : "No"])
        }
        return CSV.document(rows)
    }

    /// The main switcher's program as a CMX 3600 EDL: one event per cut, the reel named after the
    /// camera (CAM1, CAM2...). Times use the LTC recorded with each cut when every cut has one,
    /// otherwise time of day (what ATEM ISO recordings and most recorders stamp).
    public func edl(show: Show, fps: Int, end: Date? = nil) -> String {
        let main = show.mainOutput?.switcherID
        let cuts = self.cuts.filter { main == nil || $0.switcherID == main }.sorted { $0.date < $1.date }
        let useLTC = !cuts.isEmpty && cuts.allSatisfy { $0.timecode.flatMap { EDLTimecode.parse($0, fps: fps) } != nil }
        let calendar = Calendar.current
        func frames(_ entry: SwitchLogEntry) -> Int {
            if useLTC, let tc = entry.timecode, let f = EDLTimecode.parse(tc, fps: fps) { return f }
            let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: entry.date)
            let h: Int = c.hour ?? 0, m: Int = c.minute ?? 0, sec: Int = c.second ?? 0, ns: Int = c.nanosecond ?? 0
            let whole: Int = h * 3600 + m * 60 + sec
            let seconds: Double = Double(whole) + Double(ns) / 1e9
            return EDLTimecode.frames(seconds: seconds, fps: fps)
        }
        let finish = end ?? entries.map(\.date).max()
        var out = "TITLE: \(EDL.title(showName))\nFCM: NON-DROP FRAME\n\n"
        var event = 0
        for (k, cut) in cuts.enumerated() {
            let a = frames(cut)
            let b: Int
            if k + 1 < cuts.count {
                b = frames(cuts[k + 1])
            } else if let finish, finish > cut.date {
                b = a + EDLTimecode.frames(seconds: finish.timeIntervalSince(cut.date), fps: fps)
            } else {
                b = a + fps
            }
            if b <= a { continue }
            event += 1
            let cam = show.camera(cut.cameraID)
            let reel = cam.map { "CAM\($0.number)" } ?? "IN\(cut.input ?? 0)"
            let ta = EDLTimecode.string(frames: a, fps: fps), tb = EDLTimecode.string(frames: b, fps: fps)
            out += String(format: "%03d  ", event % 1000) + reel.padding(toLength: 8, withPad: " ", startingAt: 0)
                + " V     C        \(ta) \(tb) \(ta) \(tb)\n"
            out += "* FROM CLIP NAME: \(EDL.clean(cam.map { "\($0.number) \($0.displayName)" } ?? "Input \(cut.input ?? 0)"))\n"
            if let item = show.item(cut.itemID) { out += "* COMMENT: \(EDL.clean(item.title))\(cut.freeMode ? " (free mode)" : "")\n" }
            out += "\n"
        }
        return out
    }
}

enum EDL {
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "|", with: "/")
    }

    static func title(_ text: String) -> String { String(clean(text).prefix(70)) }

    /// Nearest of Resolve's marker colours to a camera colour.
    static func markerColor(_ hex: String?) -> String {
        guard let rgb = hex.flatMap(HexColor.rgb) else { return "Blue" }
        let palette: [(String, (Double, Double, Double))] = [
            ("Blue", (0.2, 0.45, 1)), ("Cyan", (0.2, 0.85, 0.9)), ("Green", (0.25, 0.8, 0.3)), ("Yellow", (1, 0.85, 0.2)),
            ("Red", (0.95, 0.2, 0.2)), ("Pink", (1, 0.45, 0.75)), ("Purple", (0.6, 0.35, 0.95)), ("Fuchsia", (0.85, 0.3, 0.85)),
            ("Rose", (1, 0.6, 0.65)), ("Lavender", (0.7, 0.65, 1)), ("Sky", (0.55, 0.8, 1)), ("Mint", (0.55, 0.95, 0.75)),
            ("Lemon", (1, 1, 0.55)), ("Sand", (0.85, 0.75, 0.55)), ("Cocoa", (0.55, 0.4, 0.3)), ("Cream", (1, 0.95, 0.85)),
        ]
        return palette.min { a, b in
            let da = pow(a.1.0 - rgb.0, 2) + pow(a.1.1 - rgb.1, 2) + pow(a.1.2 - rgb.2, 2)
            let db = pow(b.1.0 - rgb.0, 2) + pow(b.1.1 - rgb.1, 2) + pow(b.1.2 - rgb.2, 2)
            return da < db
        }?.0 ?? "Blue"
    }
}

/// "#RRGGBB" -> 0...1 components.
public enum HexColor {
    public static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}
