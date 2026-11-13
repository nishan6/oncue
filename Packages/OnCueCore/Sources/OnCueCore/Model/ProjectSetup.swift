import Foundation

// MARK: - New show in one screen
//
// Cameras with their names and operators, the main switcher and the setlist, typed or pasted
// when the project is made. One camera per line ("Wide – Arjun", "Jib, Rohan", or just a name);
// one scene per line ("1. Neon Skyline", "Opening speech"); a line starting with * is a segment
// (a speech, an award, a break) instead of a song.

public struct ProjectSetup: Equatable {
    public var cameraCount: Int = 4
    public var cameraLines: String = ""
    public var switcherKind: SwitcherKind = .simulator
    public var switcherHost: String = ""
    public var setlist: String = ""
    public init() {}

    public struct CameraLine: Equatable {
        public var name: String
        public var operatorName: String
    }

    public struct SceneLine: Equatable {
        public var number: String
        public var title: String
        public var segment: Bool
    }

    /// "Wide – Arjun", "Wide - Arjun", "Wide, Arjun", "Wide | Arjun" or "Wide".
    public static func cameras(_ text: String) -> [CameraLine] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            for sep in [" – ", " — ", " - ", ",", "|", "\t"] {
                if let r = line.range(of: sep) {
                    return CameraLine(name: String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces),
                                      operatorName: String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces))
                }
            }
            return CameraLine(name: line, operatorName: "")
        }
    }

    /// "1. Song", "1) Song", "12 Song", "Song", "* Speech".
    public static func scenes(_ text: String) -> [SceneLine] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            var segment = false
            if line.hasPrefix("*") {
                segment = true
                line = line.dropFirst().trimmingCharacters(in: .whitespaces)
            }
            var number = ""
            let digits = line.prefix { $0.isNumber }
            if !digits.isEmpty {
                var rest = Substring(line.dropFirst(digits.count))
                var punct = false
                if let first = rest.first, ".):-".contains(first) { rest = rest.dropFirst(); punct = true }
                let title = rest.trimmingCharacters(in: .whitespaces)
                // "12 Encore" or "1. Intro" are numbered; "24K Magic" is a title.
                if !title.isEmpty, punct || rest.first?.isWhitespace == true {
                    number = String(digits)
                    line = title
                }
            }
            guard !line.isEmpty else { return nil }
            return SceneLine(number: number, title: line, segment: segment)
        }
    }
}

extension Project {
    /// Applies a new-show setup to a starter project: its cameras, main switcher and setlist.
    public mutating func apply(_ setup: ProjectSetup) {
        let lines = ProjectSetup.cameras(setup.cameraLines)
        let count = max(1, min(max(setup.cameraCount, lines.count), 200))
        var main = switchers.first { $0.role == .main } ?? SwitcherConfig(name: "Main switcher", kind: setup.switcherKind, role: .main)
        main.kind = setup.switcherKind
        main.name = setup.switcherKind == .simulator ? "Simulator" : setup.switcherKind.label
        main.host = setup.switcherHost.trimmingCharacters(in: .whitespaces)
        main.inputCount = max(main.inputCount, count)
        switchers = [main] + switchers.filter { $0.id != main.id && $0.role != .main }
        for k in outputs.indices where outputs[k].switcherID == nil || !switchers.contains(where: { $0.id == outputs[k].switcherID }) {
            outputs[k].switcherID = main.id
        }
        cameras = (1...count).map { n in
            var cam = Camera(number: n, switcherID: main.id, input: n)
            if n - 1 < lines.count {
                cam.name = lines[n - 1].name
                cam.operatorName = lines[n - 1].operatorName
            }
            return cam
        }
        let scenes = ProjectSetup.scenes(setup.setlist)
        if !scenes.isEmpty, !playlists.isEmpty {
            playlists[0].items = scenes.enumerated().map { k, s in
                newScene(title: s.title, number: s.number.isEmpty ? "\(k + 1)" : s.number, kind: s.segment ? .segment : .song)
            }
        }
    }
}
