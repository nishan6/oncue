import XCTest
@testable import OnCueCore

/// A show the size of the biggest ones: 72 cameras and an 8½-hour segment with a shot every
/// 5 seconds (6,120 shots), plus a long song. The timeline and shot list rebuild their rows and
/// spans on every edit, so these must stay well inside one frame's budget at 60 Hz.
final class LargeTimelineTests: XCTestCase {
    private func bigShow() -> (Show, UUID, UUID) {
        var show = Show.starter()
        let sim = show.switchers[0].id
        show.cameras = (1...72).map { Camera(number: $0, switcherID: sim, input: $0) }
        var segment = RundownItem(kind: .segment, title: "All-day stream", timeBase: .seconds, syncMode: .freeRun)
        segment.tracks = [Track(kind: .shots, name: "Program shots", outputID: show.outputs[0].id)]
        segment.sections = (0..<34).map { SongSection(name: "Block \($0 + 1)", at: Double($0) * 900) }
        var cues: [Cue] = []
        for k in 0..<6120 {
            var cue = Cue(at: Double(k) * 5, cameraID: show.cameras[k % 72].id)
            cue.text = "Shot \(k + 1)"
            cue.shotSize = ["cu", "ms", "ws"][k % 3]
            cues.append(cue)
        }
        segment.tracks[0].cues = cues
        show.items.append(segment)
        let song = show.items[0].id
        for b in 0..<400 { show.addShot(inItem: song, cameraID: show.cameras[b % 72].id, at: Double(b) * 2) }
        return (show, segment.id, song)
    }

    func testRowsAndSpansStayFast() {
        let (show, segment, song) = bigShow()
        XCTAssertEqual(show.shotRows(forItem: segment).count, 6120)
        let start = Date()
        for _ in 0..<5 {
            _ = show.shotRows(forItem: segment)
            _ = show.shotSpans(forItem: segment)
            _ = show.shotGroups(forItem: segment)
            _ = show.shotRows(forItem: song)
        }
        let each = Date().timeIntervalSince(start) / 5
        XCTAssertLessThan(each, 0.25, "rows, spans and groups for 6,120 shots took \(each) s")
        print("[perf] rows+spans+groups for 6,120 shots: \(String(format: "%.1f", each * 1000)) ms")
    }

    func testEditAndSaveStayFast() throws {
        var (show, segment, _) = bigShow()
        let ids = Set(show.shotRows(forItem: segment).prefix(500).map(\.id))
        var start = Date()
        show.quantizeShots(ids, inItem: segment, to: .second)
        _ = show.moveAll(inItem: segment, from: 3000, by: 10)
        let edit = Date().timeIntervalSince(start)
        XCTAssertLessThan(edit, 0.5, "bulk edits took \(edit) s")

        let project = Project(migrating: show)
        start = Date()
        let data = try ProjectCoding.encode(project)
        guard case .project(let back) = try ProjectCoding.decode(data) else { return XCTFail("not a project") }
        let save = Date().timeIntervalSince(start)
        XCTAssertEqual(back.sceneCount, 2)
        XCTAssertLessThan(save, 3, "save and load took \(save) s")
        print("[perf] bulk edits \(String(format: "%.0f", edit * 1000)) ms; save+load \(data.count / 1024) KB in \(String(format: "%.0f", save * 1000)) ms")
    }
}
