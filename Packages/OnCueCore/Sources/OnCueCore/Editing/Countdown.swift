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
