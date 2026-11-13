import XCTest
@testable import OnCueCore

final class GroupMoveTests: XCTestCase {
    private func fixture() -> (Show, UUID, [UUID]) {
        var show = Show.starter()
        let song = show.items[0].id
        let cams = show.sortedCameras
        var ids: [UUID] = []
        for (k, at) in [0.0, 4, 8, 12].enumerated() {
            show.addShot(inItem: song, cameraID: cams[k % cams.count].id, at: at)
        }
        ids = show.shotRows(forItem: song).map(\.id)
        return (show, song, ids)
    }

    func testMovesSelectionTogether() {
        var (show, song, ids) = fixture()
        XCTAssertTrue(show.moveCues([ids[1], ids[2]], inItem: song, by: 2))
        XCTAssertEqual(show.cue(ids[1], inItem: song)?.at, 6)
        XCTAssertEqual(show.cue(ids[2], inItem: song)?.at, 10)
        XCTAssertEqual(show.cue(ids[3], inItem: song)?.at, 12, "others stay")
    }

    func testRefusesToMoveBeforeTheStart() {
        var (show, song, ids) = fixture()
        XCTAssertFalse(show.moveCues([ids[0], ids[1]], inItem: song, by: -1))
        XCTAssertEqual(show.cue(ids[0], inItem: song)?.at, 0)
    }

    func testCopiesKeepDetailsWithNewIDs() {
        var (show, song, ids) = fixture()
        show.updateCue(ids[1], inItem: song) { $0.shotSize = "cu"; $0.text = "Vocals" }
        let made = show.copyCues([ids[1]], inItem: song, by: 1)
        XCTAssertEqual(made.count, 1)
        XCTAssertNotEqual(made[0], ids[1])
        let copy = show.cue(made[0], inItem: song)
        XCTAssertEqual(copy?.at, 5)
        XCTAssertEqual(copy?.shotSize, "cu")
        XCTAssertEqual(copy?.text, "Vocals")
        XCTAssertEqual(show.shotRows(forItem: song).count, 5)
        XCTAssertTrue(show.copyCues([ids[0]], inItem: song, by: -1).isEmpty)
    }
}
