import Foundation

/// Scene numbers and start timecodes for new and reordered scenes. Nothing here changes a number
/// on its own: the app asks before applying `renumbered`.
public enum SceneNumbering {
    /// The number a scene inserted at `index` would get.
    /// - automatic / fixed: one more than the highest whole number used (fixed numbers never
    ///   shift, so an insert takes the next free number);
    /// - fixedWithSuffix: the previous scene's number with the next free letter ("3" → "3a",
    ///   "3a" → "3b"); at the very start, the next free whole number.
    public static func numberForInsert(at index: Int, in items: [RundownItem], mode: NumberingMode, from start: Int) -> String {
        let used = Set(items.map(\.number))
        switch mode {
        case .automatic:
            return "\(start + min(max(index, 0), items.count))"
        case .fixed:
            return nextWhole(used: used, from: start)
        case .fixedWithSuffix:
            guard index > 0, index <= items.count else { return nextWhole(used: used, from: start) }
            let previous = items[index - 1].number
            let base = String(previous.prefix { $0.isNumber })
            guard !base.isEmpty else { return nextWhole(used: used, from: start) }
            if index == items.count, let n = Int(base), !used.contains("\(n + 1)") { return "\(n + 1)" }
            for letter in "abcdefghijklmnopqrstuvwxyz" {
                let candidate = base + String(letter)
                if !used.contains(candidate) { return candidate }
            }
            return nextWhole(used: used, from: start)
        }
    }

    static func nextWhole(used: Set<String>, from start: Int) -> String {
        let highest = used.compactMap { Int($0.prefix { $0.isNumber }) }.max() ?? (start - 1)
        return "\(max(highest + 1, start))"
    }

    /// Numbers that follow the running order: start, start + 1, ...
    public static func renumbered(_ items: [RundownItem], from start: Int) -> [RundownItem] {
        var out = items
        for i in out.indices { out[i].number = "\(start + i)" }
        return out
    }

    /// Whether the numbers already follow the order (so no question needs asking after a move).
    public static func followsOrder(_ items: [RundownItem], from start: Int) -> Bool {
        items.enumerated().allSatisfy { $0.element.number == "\(start + $0.offset)" }
    }

    /// Ways to set a new scene's start timecode; the app asks each time.
    public enum StartChoice: String, CaseIterable, Identifiable {
        case projectDefault, hourPerNumber, continueFromPrevious
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .projectDefault: return "Same as the project default"
            case .hourPerNumber: return "One hour per scene number"
            case .continueFromPrevious: return "Continue from the previous scene"
            }
        }
    }

    /// The start timecode for a new scene, or nil when the choice can't give one (no previous
    /// scene with a start timecode, or a number that is not a whole hour 0–23).
    public static func startTimecode(_ choice: StartChoice, number: String, previous: RundownItem?,
                                     defaults: SceneDefaults, rate: FrameRate) -> String? {
        switch choice {
        case .projectDefault:
            return defaults.startTimecode
        case .hourPerNumber:
            guard let n = Int(number.prefix { $0.isNumber }), n >= 0, n < 24 else { return nil }
            return Timecode.string(frames: Timecode.frames("\(n < 10 ? "0" : "")\(n):00:00:00", rate: rate) ?? 0, rate: rate)
        case .continueFromPrevious:
            guard let previous, let start = Timecode.frames(previous.ltcStart, rate: previous.frameRate ?? rate) else { return nil }
            let length = (previous.frameRate ?? rate).frames(seconds: previous.plannedDuration)
            return Timecode.string(frames: start + length, rate: rate)
        }
    }
}
