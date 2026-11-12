import XCTest
@testable import OnCueCore

final class DraftScriptTests: XCTestCase {
    private func cut(_ show: Show, _ date: Date, cam: Int) -> SwitchLogEntry {
        let c = show.camera(number: cam)!
        return SwitchLogEntry(kind: .cut, date: date, switcherID: show.mainOutput?.switcherID, input: c.input, cameraID: c.id, mode: "display")
    }

    private func call(_ show: Show, _ date: Date, item: Int) -> SwitchLogEntry {
        SwitchLogEntry(kind: .scripted, date: date, outputID: show.mainOutput?.id, itemID: show.items[item].id, shotNumber: 1, mode: "display")
    }

    func testDraftFromSwitchLog() throws {
        var show = Show.starter()
        show.updateItem(show.items[0].id) { $0.bpm = 120 }
        show.addSegment(title: "Talk")
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        var log = SwitchLog(showID: show.id, showName: show.name, started: t0)
        log.entries = [cut(show, t0.addingTimeInterval(-5), cam: 2),      // on air before the song
                       call(show, t0, item: 0),
                       cut(show, t0.addingTimeInterval(2), cam: 3),       // 4 beats at 120
                       cut(show, t0.addingTimeInterval(4.1), cam: 1),     // 8.2 beats -> 8.25
                       call(show, t0.addingTimeInterval(10), item: 1),
                       cut(show, t0.addingTimeInterval(10.2), cam: 4),
                       cut(show, t0.addingTimeInterval(13), cam: 2)]
        let plans = show.draftPlans(from: log)
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].cuts.map { ($0.seconds * 1000).rounded() }, [0, 2000, 4100], "opening camera counted at the start")
        XCTAssertEqual(plans[0].cuts.first?.cameraID, show.camera(number: 2)?.id)
        XCTAssertEqual(plans[1].cuts.count, 2, "the cut right at the start needs no opening shot")

        let before = show.items.count
        let ids = show.applyDrafts(plans, label: "draft")
        XCTAssertEqual(show.items.count, before + 2)
        XCTAssertEqual(show.items[1].id, ids[0], "the draft sits right after its song")
        XCTAssertEqual(show.items[1].title, "Song 1 (draft)")
        let rows = show.shotRows(forItem: ids[0])
        XCTAssertEqual(rows.map(\.cue.at), [0, 4, 8.25])
        XCTAssertEqual(rows.map { show.camera($0.cue.cameraID)?.number }, [2, 3, 1])
        XCTAssertEqual(show.items[1].sections.count, show.items[0].sections.count, "sections come along")
        XCTAssertNotEqual(show.items[1].sections.first?.id, show.items[0].sections.first?.id)
        XCTAssertTrue(show.shotRows(forItem: show.items[0].id).isEmpty, "the original is untouched")
        let talk = show.shotRows(forItem: ids[1])
        XCTAssertEqual(talk.map { ($0.cue.at * 10).rounded() }, [2, 30])
    }

    func testDraftFromEDL() throws {
        var show = Show.starter()
        show.updateCamera(show.camera(number: 3)!.id) { $0.name = "Crane" }
        let edl = """
        TITLE: Rehearsal
        FCM: NON-DROP FRAME

        001  CAM2     V     C        10:00:00:00 10:00:04:00 01:00:00:00 01:00:04:00
        * FROM CLIP NAME: 2 Handheld
        002  A003C001 V     C        10:00:04:00 10:00:06:12 01:00:04:00 01:00:06:12
        * FROM CLIP NAME: Crane sweep
        003  AX       AA    C        10:00:04:00 10:00:06:12 01:00:04:00 01:00:06:12
        004  ISO4     V     C        10:00:06:12 10:00:09:00 01:00:06:12 01:00:09:00
        """
        let plan = try XCTUnwrap(show.draftPlan(fromEDL: edl, fps: 25, title: "Rehearsal edit"))
        XCTAssertEqual(plan.cuts.map { ($0.seconds * 100).rounded() }, [0, 400, 648], "audio events skipped")
        XCTAssertEqual(plan.cuts.map { show.camera($0.cameraID)?.number }, [2, 3, 4])
        let ids = show.applyDrafts([plan], label: "draft")
        XCTAssertEqual(show.items.last?.id, ids[0])
        XCTAssertEqual(show.items.last?.title, "Rehearsal edit")
        XCTAssertEqual(show.shotRows(forItem: ids[0]).map { ($0.cue.at * 10).rounded() }, [0, 40, 65])
        XCTAssertNil(show.draftPlan(fromEDL: "not an edl", fps: 25, title: "x"))
    }
}
