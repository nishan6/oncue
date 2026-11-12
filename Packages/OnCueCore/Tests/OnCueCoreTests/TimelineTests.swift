import XCTest
@testable import OnCueCore

final class TimelineTests: XCTestCase {

    // MARK: Camera colours

    func testCameraColourDefaultsByNumberAndCanBeChosen() {
        var show = Show.starter()
        let cam = show.sortedCameras[1]
        XCTAssertEqual(cam.resolvedColor, CameraPalette.colors[1])
        XCTAssertEqual(Camera(number: 13).resolvedColor, CameraPalette.colors[0], "palette repeats after twelve")
        show.updateCamera(cam.id) { $0.color = "#123abc" }
        XCTAssertEqual(show.camera(cam.id)?.resolvedColor, "#123ABC")
        show.updateCamera(cam.id) { $0.color = "not a colour" }
        XCTAssertEqual(show.camera(cam.id)?.resolvedColor, CameraPalette.colors[1], "invalid colours fall back")
    }

    func testCameraColourRoundTripsAndIsOptionalInOldFiles() throws {
        var show = Show.starter()
        show.updateCamera(show.cameras[0].id) { $0.color = "#FF00AA" }
        let decoded = try ShowCoding.decode(try ShowCoding.encode(show))
        XCTAssertEqual(decoded.cameras[0].color, "#FF00AA")

        let old = #"{"number": 3, "name": "Jib"}"#.data(using: .utf8)!
        let cam = try JSONDecoder().decode(Camera.self, from: old)
        XCTAssertEqual(cam.color, "")
        XCTAssertEqual(cam.resolvedColor, CameraPalette.colors[2])
    }

    // MARK: Spans

    func testShotSpansRunToTheNextShotAndTheSongEnd() {
        var show = Show.starter()
        let song = show.items[0].id // sections at 0, 16, 48 beats
        show.addShot(inItem: song, cameraID: show.cameras[0].id, at: 0)
        show.addShot(inItem: song, cameraID: show.cameras[1].id, at: 8)
        let spans = show.shotSpans(forItem: song)
        XCTAssertEqual(spans.map(\.start), [0, 8])
        XCTAssertEqual(spans[0].end, 8)
        // Last section starts at 48; the default section length is 8 bars of 4.
        XCTAssertEqual(show.itemEnd(forItem: song), 80)
        XCTAssertEqual(spans[1].end, 80)
        let sections = show.sectionSpans(forItem: song)
        XCTAssertEqual(sections.map(\.end), [16, 48, 80])
    }

    func testPlannedLengthExtendsTheEnd() {
        var show = Show.starter()
        let seg = show.addSegment()
        show.updateItem(seg) { $0.plannedDuration = 300; $0.sections = [] }
        show.addShot(inItem: seg, cameraID: show.cameras[0].id, at: 10)
        XCTAssertEqual(show.itemEnd(forItem: seg), 300)
        XCTAssertEqual(show.shotSpans(forItem: seg).first?.end, 300)
    }

    func testOrderItemsGiveEachShotOneStep() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [] }
        show.setTimeBase(.order, forItem: song)
        for _ in 0..<3 { show.addShot(inItem: song, cameraID: show.cameras[0].id) }
        let spans = show.shotSpans(forItem: song)
        XCTAssertEqual(spans.map(\.start), [1, 2, 3])
        XCTAssertEqual(spans.map(\.end), [2, 3, 4])
    }

    func testSnap() {
        var item = RundownItem(title: "x")
        XCTAssertEqual(Show.snap(5.4, for: item), 5)
        XCTAssertEqual(Show.snap(-3, for: item), 0)
        item.timeBase = .seconds
        XCTAssertEqual(Show.snap(5.3, for: item), 5.5)
        item.timeBase = .order
        XCTAssertEqual(Show.snap(0.2, for: item), 1)
    }

    // MARK: Lyrics, notes and FX

    func testTrackCuesAreCreatedOnTheRightTrack() {
        var show = Show.starter()
        let song = show.items[0].id
        let lyric = show.addTrackCue(.lyrics, inItem: song, at: 16, text: "First line")!
        let note = show.addTrackCue(.notes, inItem: song, at: 4, text: "Pyro")!
        let fx = show.addTrackCue(.fx, inItem: song, at: 0, text: "Lower third")!
        XCTAssertEqual(show.trackCues(.lyrics, inItem: song).map(\.text), ["First line"])
        XCTAssertEqual(show.trackKind(ofCue: lyric, inItem: song), .lyrics)
        XCTAssertEqual(show.trackKind(ofCue: note, inItem: song), .notes, "a notes track is created for songs")
        XCTAssertEqual(show.cue(fx, inItem: song)?.fxAction, .macro)
        XCTAssertTrue(show.shotRows(forItem: song).isEmpty, "track cues are not shots")

        show.moveCue(lyric, inItem: song, to: 20)
        XCTAssertEqual(show.cue(lyric, inItem: song)?.at, 20)
        show.deleteCues([lyric, note], inItem: song)
        XCTAssertTrue(show.trackCues(.lyrics, inItem: song).isEmpty)
        XCTAssertEqual(show.item(song)?.tracks.filter { $0.kind == .notes }.count, 1, "ensureTrack reuses the track")
    }

    func testMovingAShotOnTheTimelineReordersTheShotList() {
        var show = Show.starter()
        let song = show.items[0].id
        let a = show.addShot(inItem: song, cameraID: show.cameras[0].id, at: 0)!
        let b = show.addShot(inItem: song, cameraID: show.cameras[1].id, at: 4)!
        show.moveCue(a, inItem: song, to: 8)
        XCTAssertEqual(show.shotRows(forItem: song).map(\.id), [b, a])
    }

    func testSampleShowHasEveryTrackKind() {
        let show = Show.sample()
        let opener = show.items[0].id
        XCTAssertFalse(show.trackCues(.lyrics, inItem: opener).isEmpty)
        XCTAssertFalse(show.trackCues(.notes, inItem: opener).isEmpty)
        XCTAssertFalse(show.trackCues(.fx, inItem: opener).isEmpty)
        XCTAssertEqual(show.shotSpans(forItem: opener).count, 19)
        XCTAssertEqual(show.itemEnd(forItem: opener), 88 * 4)
    }

    func testRunLength() {
        let show = Show.sample()
        // Neon Skyline: 88 bars of 4 at 128 BPM.
        XCTAssertEqual(show.runLength(forItem: show.items[0].id)!, 88 * 4 * 60 / 128, accuracy: 0.001)
        XCTAssertEqual(show.runLength(forItem: show.items[2].id), 180, "segment runs its planned length")
        XCTAssertNil(show.runLength(forItem: show.items[3].id), "NEXT order has no length")
    }

    // MARK: Live cursor

    func testLiveCursorSteppingAndJumping() {
        let show = Show.sample()
        let opener = show.items[0].id
        var cursor = LiveCursor(itemID: opener)
        XCTAssertTrue(cursor.isStandingBy)
        XCTAssertNil(show.liveNow(cursor))
        XCTAssertEqual(show.liveNext(cursor)?.number, 1)

        XCTAssertTrue(show.advance(&cursor))
        XCTAssertEqual(show.liveNow(cursor)?.number, 1)
        XCTAssertEqual(show.liveNext(cursor)?.number, 2)
        XCTAssertEqual(show.liveUpcoming(cursor, limit: 3).map(\.number), [3, 4, 5])

        let chorus = show.item(opener)!.sortedSections[3] // Chorus
        XCTAssertTrue(show.jump(&cursor, toSection: chorus.id))
        XCTAssertEqual(show.liveNow(cursor)?.sectionID, chorus.id)

        XCTAssertTrue(show.stepBack(&cursor))
        XCTAssertNotEqual(show.liveNow(cursor)?.sectionID, chorus.id)

        cursor.index = 18
        XCTAssertFalse(show.advance(&cursor), "stays on the last shot")
        XCTAssertNil(show.liveNext(cursor))

        XCTAssertTrue(show.moveItem(&cursor, by: 1))
        XCTAssertEqual(cursor, LiveCursor(itemID: show.items[1].id))
        XCTAssertFalse(show.moveItem(&cursor, by: -5))
        cursor = LiveCursor(itemID: opener, index: 0)
        XCTAssertTrue(show.stepBack(&cursor))
        XCTAssertTrue(cursor.isStandingBy)
        XCTAssertFalse(show.stepBack(&cursor))
    }
}
