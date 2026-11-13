import Foundation

// MARK: - Multi View and Full Page
//
// Viewer layouts built from the crew snapshot, so the Mac monitors and the browser page show the
// same thing. Multi View: one column per camera with its tally, the shot it has on air, its next
// shots and the countdown to them. Full Page: one camera's shots, or the whole script. View only.

public enum ViewerTally: String, Codable, Equatable {
    case program, preview, clear
}

public struct MultiViewColumn: Equatable {
    public var camera: CrewCamera
    public var tally: ViewerTally
    /// The shot on air, when it is this camera's.
    public var current: CrewShot?
    /// This camera's next shots after the one on air, in order.
    public var upcoming: [CrewShot]
}

extension CrewSnapshot {
    /// Live: the current item's shots after the one on air. Not live: every item's shots.
    var viewerShots: (now: CrewShot?, after: [CrewShot]) {
        if live {
            let shots = items.first?.shots ?? []
            let k = shots.firstIndex { $0.id == nowShotID }
            return (k.map { shots[$0] }, k.map { Array(shots[($0 + 1)...]) } ?? shots)
        }
        return (nil, items.flatMap(\.shots))
    }

    public func tally(camera: Int) -> ViewerTally {
        if program == camera { return .program }
        if preview == camera { return .preview }
        return .clear
    }

    /// One column per camera (or the chosen cameras, in that order).
    public func multiViewColumns(upcoming count: Int = 3, cameras only: [Int]? = nil) -> [MultiViewColumn] {
        let (now, after) = viewerShots
        let chosen = only.map { numbers in numbers.compactMap { n in cameras.first { $0.number == n } } } ?? cameras
        return chosen.map { cam in
            MultiViewColumn(camera: cam, tally: tally(camera: cam.number),
                            current: now?.camera == cam.number ? now : nil,
                            upcoming: Array(after.lazy.filter { $0.camera == cam.number }.prefix(max(count, 0))))
        }
    }

    /// Full page: the shot on air (any camera) and the shots still to come, for one camera
    /// (`camera` > 0) or every camera (0).
    public func fullPage(camera: Int) -> (now: CrewShot?, upcoming: [CrewShot]) {
        let (now, after) = viewerShots
        guard camera > 0 else { return (now, after) }
        return (now, after.filter { $0.camera == camera })
    }
}

extension Cue {
    /// Short forms of the shot's size, movement, framing and subjects, for crew views.
    public func detailLine(_ v: ShotVocabulary) -> String {
        var parts: [String] = []
        if !shotSize.isEmpty { parts.append(v.size(shotSize)?.short ?? shotSize) }
        if !movement.isEmpty { parts.append(v.movement(movement)?.short ?? movement) }
        if !framing.isEmpty { parts.append(v.framing(framing)?.short ?? framing) }
        let who = subjects.map { v.castMember($0)?.label ?? $0 }.filter { !$0.isEmpty }
        if !who.isEmpty { parts.append(who.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}
