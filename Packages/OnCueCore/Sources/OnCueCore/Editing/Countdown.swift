import Foundation

/// What the countdown shows at one moment in Live Mode.
public struct CountdownReading: Equatable {
    /// Seconds to the next cut; nil when nothing is timed (manual NEXT with no planned length).
    public var nextCut: Double?
    /// The next section and the seconds to it; nil when there is none or the song isn't running
    /// against a timing source.
    public var nextSection: (name: String, seconds: Double)?
    /// The camera to call on standby: the next shot's camera, inside the standby window.
    public var standbyCameraID: UUID?

    public static func == (a: CountdownReading, b: CountdownReading) -> Bool {
        a.nextCut == b.nextCut && a.standbyCameraID == b.standbyCameraID
            && a.nextSection?.name == b.nextSection?.name && a.nextSection?.seconds == b.nextSection?.seconds
    }
}

public enum Countdown {
    /// - Parameters:
    ///   - position: the engine's position in the item's time base, when a timing source is running.
    ///   - secondsToNext: the engine's real time to the next cut, or a planned estimate.
    public static func reading(item: RundownItem, next: ShotRow?, position: Double?, secondsToNext: Double?,
                               settings: CountdownSettings, vocabulary: ShotVocabulary = ShotVocabulary()) -> CountdownReading {
        var r = CountdownReading()
        if settings.showNextShot { r.nextCut = secondsToNext.map { max($0, 0) } }
        if settings.showNextSection, let position, item.timeBase != .order,
           let section = item.sortedSections.first(where: { $0.at > position + 1e-9 }) {
            r.nextSection = (section.name, item.seconds(for: section.at - position))
        }
        if settings.showStandby, let next, let left = secondsToNext, left >= 0, left <= settings.standbySeconds,
           !vocabulary.isCut(next.cue) {
            r.standbyCameraID = next.cue.cameraID
        }
        return r
    }
}

/// A department call or player cue coming up in Live Mode.
public struct UpcomingCall: Identifiable, Equatable {
    public var id: UUID { cue.id }
    public let kind: TrackKind
    public let cue: Cue
    /// Seconds from the current position, when the item has a time base.
    public let inSeconds: Double?
}

extension Show {
    /// The next Cues-track calls and Media Player Control cues at or after `position`, in order.
    public func upcomingCalls(inItem id: UUID, after position: Double, limit: Int = 4) -> [UpcomingCall] {
        guard let item = item(id) else { return [] }
        var out: [UpcomingCall] = []
        for track in item.tracks where !track.muted && (track.kind == .calls || track.kind == .player) {
            for cue in track.cues where cue.at >= position - 1e-9 {
                let secs = item.timeBase == .order ? nil : item.seconds(for: cue.at - position)
                out.append(UpcomingCall(kind: track.kind, cue: cue, inSeconds: secs))
            }
        }
        return Array(out.sorted { $0.cue.at < $1.cue.at }.prefix(limit))
    }
}
