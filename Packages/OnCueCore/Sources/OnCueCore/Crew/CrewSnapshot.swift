import Foundation

// What the crew page shows. Built from the show and, in Live Mode, the engine's position.
// The phone counts down locally from `secondsUntil` and the server time, so updates can be sparse.

public struct CrewCamera: Codable, Equatable {
    public var number: Int
    public var name: String
    public var operatorName: String
    public var color: String
}

public struct CrewShot: Codable, Equatable {
    public var id: String
    public var itemID: String
    public var number: Int
    public var position: String
    public var camera: Int?
    public var text: String
    public var note: String
    public var transition: String
    /// Shot size, movement, framing and subjects, short forms ("CU · PUSH · 2S · Lead vocal").
    public var details: String = ""
    /// Seconds until this shot, while a timing source runs (nil otherwise).
    public var secondsUntil: Double?
    public var comments: [CrewComment]
}

public struct CrewComment: Codable, Equatable {
    public var author: String
    public var text: String
    public var date: Date
    public var resolved: Bool
}

public struct CrewItem: Codable, Equatable {
    public var id: String
    public var title: String
    public var kind: String
    public var shots: [CrewShot]
}

public struct CrewSnapshot: Codable, Equatable {
    public var showName: String
    public var serverTime: Date
    public var live: Bool
    public var itemID: String?
    public var itemTitle: String
    public var section: String
    public var mode: String
    public var paused: Bool
    public var freeMode: Bool
    /// Camera numbers on program and preview (from the switcher when connected, else the script).
    public var program: Int?
    public var preview: Int?
    /// The shot on air and the next one (camera numbers and ids).
    public var nowShotID: String?
    public var nextShotID: String?
    public var cameras: [CrewCamera]
    /// Live: the current item's shots. Review: every item.
    public var items: [CrewItem]
    /// Bumps when the script changes, so phones can show "script changed".
    public var scriptVersion: Int
    /// Accessibility: pages also show tally by shape (● on air, ▲ stand by, dashed preview edge).
    public var tallyShapes: Bool = false
}

extension Show {
    /// The crew page's view of the show. Pass the engine status in Live Mode, nil when editing.
    public func crewSnapshot(status: EngineStatus?, position: Double?, running: Bool, scriptVersion: Int, now: Date = Date(),
                             vocabulary: ShotVocabulary = ShotVocabulary()) -> CrewSnapshot {
        let cams = sortedCameras.map { CrewCamera(number: $0.number, name: $0.displayName, operatorName: $0.operatorName, color: $0.resolvedColor) }

        func shots(for item: RundownItem, timed: Bool) -> [CrewShot] {
            shotRows(forItem: item.id).map { row in
                let seconds: Double? = {
                    guard timed, running, let position, item.timeBase != .order, row.cue.at > position + 1e-9 else { return nil }
                    return item.seconds(for: row.cue.at - position)
                }()
                let cueComments = comments.filter { $0.cueID == row.id }.map {
                    CrewComment(author: $0.author, text: $0.text, date: $0.date, resolved: $0.resolved)
                }
                return CrewShot(id: row.id.uuidString, itemID: item.id.uuidString, number: row.number,
                                position: item.format(row.cue.at), camera: camera(row.cue.cameraID)?.number,
                                text: row.cue.text, note: row.cue.note, transition: row.cue.transition == .cut ? "cut" : "mix",
                                details: row.cue.detailLine(vocabulary), secondsUntil: seconds, comments: cueComments)
            }
        }

        if let status, let item = item(status.itemID) {
            let cursor = status.cursor
            let main = status.mainSwitcher
            let programCam = main?.program.flatMap { camera(input: $0, switcherID: main?.id)?.number }
                ?? camera(liveNow(cursor)?.cue.cameraID)?.number
            let previewCam = main?.preview.flatMap { camera(input: $0, switcherID: main?.id)?.number }
                ?? camera(liveNext(cursor)?.cue.cameraID)?.number
            return CrewSnapshot(
                showName: name, serverTime: now, live: true, itemID: item.id.uuidString, itemTitle: item.title,
                section: item.section(at: status.position)?.name ?? "",
                mode: status.mode(mainOutput?.id).label, paused: status.pauseReason != nil, freeMode: status.freeMode,
                program: programCam, preview: previewCam,
                nowShotID: liveNow(cursor)?.id.uuidString, nextShotID: liveNext(cursor)?.id.uuidString,
                cameras: cams,
                items: [CrewItem(id: item.id.uuidString, title: item.title, kind: item.kind.rawValue, shots: shots(for: item, timed: true))],
                scriptVersion: scriptVersion)
        }
        return CrewSnapshot(
            showName: name, serverTime: now, live: false, itemID: nil, itemTitle: "", section: "", mode: "Review",
            paused: false, freeMode: false, program: nil, preview: nil, nowShotID: nil, nextShotID: nil,
            cameras: cams,
            items: items.map { CrewItem(id: $0.id.uuidString, title: $0.title, kind: $0.kind.rawValue, shots: shots(for: $0, timed: false)) },
            scriptVersion: scriptVersion)
    }

    /// Adds a comment from the crew page or review (by text ids from the page).
    @discardableResult
    public mutating func addComment(itemID: String?, cueID: String?, author: String, text: String, date: Date = Date()) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let item = itemID.flatMap(UUID.init(uuidString:))
        let cue = cueID.flatMap(UUID.init(uuidString:))
        if let item, self.item(item) == nil { return false }
        let name = author.trimmingCharacters(in: .whitespacesAndNewlines)
        comments.append(Comment(itemID: item, cueID: cue, author: name.isEmpty ? "Crew" : String(name.prefix(40)),
                                text: String(t.prefix(1000)), date: date))
        return true
    }

    public mutating func setCommentResolved(_ id: UUID, _ resolved: Bool) {
        guard let i = comments.firstIndex(where: { $0.id == id }) else { return }
        comments[i].resolved = resolved
    }

    public mutating func deleteComment(_ id: UUID) {
        comments.removeAll { $0.id == id }
    }
}
