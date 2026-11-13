import Foundation

// MARK: - Typing a shot
//
// "cu push 2s lead vocal" → size Close-up, movement Push in, framing Two-shot, subjects Lead
// vocal. Words are matched against the project's own lists (short forms and full names, any
// case, longest match first); a number on its own is the camera; anything left over becomes the
// shot's description.

public struct ShotPhrase: Equatable {
    public var camera: Int?
    public var size: String?
    public var movement: String?
    public var framing: String?
    public var subjects: [String] = []
    public var status: String?
    /// Words that matched nothing, in order.
    public var text: String = ""

    public init() {}

    /// Applies what was typed to a shot: only the parts that were given change.
    public func apply(to cue: inout Cue, cameraID: (Int) -> UUID?) {
        if let camera, let id = cameraID(camera) { cue.cameraID = id }
        if let size { cue.shotSize = size }
        if let movement { cue.movement = movement }
        if let framing { cue.framing = framing }
        for s in subjects where !cue.subjects.contains(s) { cue.subjects.append(s) }
        if let status { cue.shotStatus = status }
        if !text.isEmpty { cue.text = text }
    }

    /// The parts as short labels, for the hint under the field ("CU · PUSH · 2S · Lead vocal").
    public func summary(_ v: ShotVocabulary) -> String {
        var parts: [String] = []
        if let camera { parts.append("Cam \(camera)") }
        if let size { parts.append(v.size(size)?.short ?? size) }
        if let movement { parts.append(v.movement(movement)?.short ?? movement) }
        if let framing { parts.append(v.framing(framing)?.short ?? framing) }
        parts += subjects.map { v.castMember($0)?.label ?? $0 }
        if let status { parts.append(v.status(status)?.label ?? status) }
        if !text.isEmpty { parts.append("“\(text)”") }
        return parts.joined(separator: " · ")
    }

    public static func parse(_ input: String, vocabulary v: ShotVocabulary) -> ShotPhrase {
        enum Kind { case size, movement, framing, cast, status }
        // Every way to name a term, as lowercase word lists.
        var names: [(words: [String], kind: Kind, key: String)] = []
        func add(_ terms: [ShotTerm], _ kind: Kind) {
            for t in terms {
                for name in Set([t.short, t.label, t.key].map { $0.lowercased() }) where !name.isEmpty {
                    names.append((words(name), kind, t.key))
                }
            }
        }
        add(v.sizes, .size)
        add(v.movements, .movement)
        add(v.framings, .framing)
        add(v.cast, .cast)
        // Statuses with the cut role are left out: "cut" typed here means a cut, not "drop this shot".
        for s in v.statuses where s.role != .cut {
            names.append((words(s.label.lowercased()), .status, s.key))
        }
        names.sort { $0.words.count > $1.words.count }

        var out = ShotPhrase()
        var leftover: [String] = []
        let original = input.split(whereSeparator: \.isWhitespace).map(String.init)
        let tokens = original.map { $0.lowercased() }
        var i = 0
        while i < tokens.count {
            if out.camera == nil, let n = Int(tokens[i]), n > 0, n < 1000 {
                out.camera = n
                i += 1
                continue
            }
            if let m = names.first(where: { n in
                i + n.words.count <= tokens.count && Array(tokens[i..<(i + n.words.count)]) == n.words
            }) {
                switch m.kind {
                case .size where out.size == nil: out.size = m.key
                case .movement where out.movement == nil: out.movement = m.key
                case .framing where out.framing == nil: out.framing = m.key
                case .cast: if !out.subjects.contains(m.key) { out.subjects.append(m.key) }
                case .status where out.status == nil: out.status = m.key
                default: leftover += original[i..<(i + m.words.count)]
                }
                i += m.words.count
                continue
            }
            leftover.append(original[i])
            i += 1
        }
        out.text = leftover.joined(separator: " ")
        return out
    }

    private static func words(_ s: String) -> [String] {
        s.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}
