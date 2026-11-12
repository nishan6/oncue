import XCTest
@testable import OnCueCore

final class BulkEditingTests: XCTestCase {
    private func showWithShots(_ positions: [Double]) -> (Show, UUID, [UUID]) {
        var show = Show.starter()
        let id = show.items[0].id
        var ids: [UUID] = []
        for p in positions { if let s = show.addShot(inItem: id, at: p) { ids.append(s) } }
        return (show, id, ids)
    }

    func testQuantizeToTheBar() {
        var (show, id, ids) = showWithShots([1, 6.5, 13])
        show.quantizeShots(Set(ids), inItem: id, to: .bar)
        XCTAssertEqual(show.shotRows(forItem: id).map(\.cue.at), [0, 8, 12])
    }

    func testQuantizeKeepsShotsApart() {
        var (show, id, ids) = showWithShots([4.2, 4.6])
        show.quantizeShots(Set(ids), inItem: id, to: .beat)
        XCTAssertEqual(show.shotRows(forItem: id).map(\.cue.at), [4, 5])
    }

    func testMoveAllOpensAndClosesAGap() {
        var (show, id, _) = showWithShots([0, 8, 16])
        show.addTrackCue(.calls, inItem: id, at: 16, text: "LX GO")
        XCTAssertTrue(show.moveAll(inItem: id, from: 8, by: 4))
        XCTAssertEqual(show.shotRows(forItem: id).map(\.cue.at), [0, 12, 20])
        XCTAssertEqual(show.item(id)?.tracks.first { $0.kind == .calls }?.cues.first?.at, 20)
        XCTAssertTrue(show.moveAll(inItem: id, from: 12, by: -4))
        XCTAssertEqual(show.shotRows(forItem: id).map(\.cue.at), [0, 8, 16])
    }

    func testMoveAllRefusesToOverlap() {
        var (show, id, _) = showWithShots([0, 8])
        XCTAssertFalse(show.moveAll(inItem: id, from: 8, by: -10))
        XCTAssertEqual(show.shotRows(forItem: id).map(\.cue.at), [0, 8])
    }

    func testSelectFromHere() {
        let (show, id, ids) = showWithShots([0, 8, 16])
        XCTAssertEqual(show.shotIDs(inItem: id, from: 8), Array(ids[1...]))
    }
}
