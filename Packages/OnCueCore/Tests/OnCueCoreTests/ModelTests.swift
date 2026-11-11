import XCTest
@testable import OnCueCore

final class ModelTests: XCTestCase {

    func testStarterShow() {
        let show = Show.starter()
        XCTAssertEqual(show.schemaVersion, Show.currentSchemaVersion)
        XCTAssertEqual(show.cameraCount, 4)
        XCTAssertEqual(show.itemCount, 1)
        XCTAssertEqual(show.switchers.first?.kind, .simulator)
        XCTAssertEqual(show.outputs.count, 1)
        XCTAssertNotNil(show.items.first?.shotsTrack(for: show.mainOutput?.id))
        XCTAssertEqual(show.cameras.map(\.input), [1, 2, 3, 4])
    }

    func testCameraLabels() {
        var cam = Camera(number: 3)
        XCTAssertEqual(cam.displayName, "Cam 3")
        XCTAssertEqual(cam.label, "Cam 3")
        cam.name = "Jib"
        cam.operatorName = "Ravi"
        XCTAssertEqual(cam.displayName, "Jib")
        XCTAssertEqual(cam.label, "Jib (Ravi)")
        cam.name = "   "
        XCTAssertEqual(cam.displayName, "Cam 3", "blank names fall back to the number")
    }

    func testBarsPositionsParseAndFormat() {
        let item = RundownItem(title: "Song", timeBase: .bars, beatsPerBar: 4)
        XCTAssertEqual(item.parse("1.1"), 0)
        XCTAssertEqual(item.parse("17.1"), 64)
        XCTAssertEqual(item.parse("17.3"), 66)
        XCTAssertEqual(item.parse("5"), 16)
        XCTAssertEqual(item.format(0), "1.1")
        XCTAssertEqual(item.format(66), "17.3")
        XCTAssertNil(item.parse("verse"))
    }

    func testSecondsPositionsParseAndFormat() {
        let item = RundownItem(title: "Segment", timeBase: .seconds)
        XCTAssertEqual(item.parse("1:23.5"), 83.5)
        XCTAssertEqual(item.parse("90"), 90)
        XCTAssertEqual(item.format(83.5), "1:23.5")
    }

    func testOrderPositions() {
        let item = RundownItem(title: "List", timeBase: .order)
        XCTAssertEqual(item.parse("#12"), 12)
        XCTAssertEqual(item.format(12), "#12")
    }

    func testSectionsAndEnds() {
        var item = RundownItem(title: "Song")
        item.sections = [SongSection(name: "Chorus", at: 48), SongSection(name: "Intro", at: 0), SongSection(name: "Verse", at: 16)]
        XCTAssertEqual(item.sortedSections.map(\.name), ["Intro", "Verse", "Chorus"])
        XCTAssertEqual(item.section(at: 20)?.name, "Verse")
        XCTAssertEqual(item.section(at: 48)?.name, "Chorus")
        let verse = item.sortedSections[1]
        XCTAssertEqual(item.sectionEnd(verse), 48)
        XCTAssertNil(item.sectionEnd(item.sortedSections[2]))
    }

    func testSecondsFromBeats() {
        let item = RundownItem(title: "Song", timeBase: .bars, bpm: 120)
        XCTAssertEqual(item.seconds(for: 8), 4, accuracy: 1e-9)
        XCTAssertEqual(item.seconds(for: 8, tempo: 60), 8, accuracy: 1e-9)
    }

    func testTimecodeHelpers() {
        XCTAssertEqual(TimeFormat.parseTimecode("01:00:00:12", fps: 25) ?? -1, 3600.48, accuracy: 1e-9)
        XCTAssertEqual(TimeFormat.timecode(3600.48, fps: 25), "01:00:00:12")
        XCTAssertNil(TimeFormat.parseTimecode("10:00", fps: 25))
        XCTAssertEqual(TimeFormat.hms(3725), "01:02:05")
        XCTAssertEqual(TimeFormat.parseSeconds("1:02:05"), 3725)
    }

    func testEnsureShotTracksAddsTrackPerOutput() {
        var show = Show.starter()
        show.outputs.append(OutputConfig(name: "LED wall"))
        show.ensureShotTracks()
        let item = show.items[0]
        XCTAssertNotNil(item.shotsTrack(for: show.outputs[1].id))
        XCTAssertEqual(item.tracks.filter { $0.kind == .shots }.count, 2)
    }
}
