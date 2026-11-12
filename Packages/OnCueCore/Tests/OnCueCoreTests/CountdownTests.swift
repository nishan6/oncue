import XCTest
@testable import OnCueCore

final class CountdownTests: XCTestCase {
    private func song() -> RundownItem {
        var item = RundownItem(title: "Song")
        item.timeBase = .bars
        item.bpm = 120
        item.sections = [SongSection(name: "Verse", at: 0), SongSection(name: "Chorus", at: 16)]
        return item
    }

    private func row(camera: UUID?, status: String = "planned") -> ShotRow {
        var cue = Cue(at: 8)
        cue.cameraID = camera
        cue.shotStatus = status
        return ShotRow(cue: cue, number: 2, sectionID: nil, lengthSeconds: nil, issues: [])
    }

    func testNextSectionInSeconds() {
        // 120 BPM: 8 beats to the chorus = 4 seconds.
        let r = Countdown.reading(item: song(), next: nil, position: 8, secondsToNext: nil, settings: CountdownSettings())
        XCTAssertEqual(r.nextSection?.name, "Chorus")
        XCTAssertEqual(r.nextSection?.seconds ?? 0, 4, accuracy: 1e-9)
    }

    func testNoSectionWithoutATimingSourceOrAfterTheLast() {
        XCTAssertNil(Countdown.reading(item: song(), next: nil, position: nil, secondsToNext: 3, settings: CountdownSettings()).nextSection)
        XCTAssertNil(Countdown.reading(item: song(), next: nil, position: 20, secondsToNext: 3, settings: CountdownSettings()).nextSection)
    }

    func testStandbyOnlyInsideTheWindow() {
        let cam = UUID()
        let settings = CountdownSettings()   // 5 s
        XCTAssertNil(Countdown.reading(item: song(), next: row(camera: cam), position: 0, secondsToNext: 5.1, settings: settings).standbyCameraID)
        XCTAssertEqual(Countdown.reading(item: song(), next: row(camera: cam), position: 0, secondsToNext: 5, settings: settings).standbyCameraID, cam)
        XCTAssertEqual(Countdown.reading(item: song(), next: row(camera: cam), position: 0, secondsToNext: 0.2, settings: settings).standbyCameraID, cam)
        XCTAssertNil(Countdown.reading(item: song(), next: row(camera: cam), position: 0, secondsToNext: nil, settings: settings).standbyCameraID,
                     "manual NEXT with no timing: no standby")
    }

    func testStandbySkipsGreyedOutShotsAndCanBeTurnedOff() {
        let cam = UUID()
        XCTAssertNil(Countdown.reading(item: song(), next: row(camera: cam, status: "cut"), position: 0, secondsToNext: 2,
                                       settings: CountdownSettings()).standbyCameraID)
        var off = CountdownSettings()
        off.showStandby = false
        off.showNextShot = false
        let r = Countdown.reading(item: song(), next: row(camera: cam), position: 0, secondsToNext: 2, settings: off)
        XCTAssertNil(r.standbyCameraID)
        XCTAssertNil(r.nextCut)
    }
}

final class UpcomingCallTests: XCTestCase {
    func testCallsAndPlayerCuesInOrder() {
        var show = Show.starter()
        let id = show.items[0].id
        show.addTrackCue(.calls, inItem: id, at: 8, text: "LX 14 GO")
        show.addTrackCue(.player, inItem: id, at: 4)
        show.addTrackCue(.calls, inItem: id, at: 2, text: "already gone")
        show.addTrackCue(.notes, inItem: id, at: 5, text: "not a call")
        let calls = show.upcomingCalls(inItem: id, after: 3)
        XCTAssertEqual(calls.map(\.kind), [.player, .calls])
        XCTAssertEqual(calls.last?.cue.text, "LX 14 GO")
        XCTAssertEqual(calls.first?.cue.playerAction, .play)
        // 120 BPM default: 5 beats = 2.5 s.
        XCTAssertEqual(calls.last?.inSeconds ?? 0, show.items[0].seconds(for: 5), accuracy: 1e-9)
    }
}
