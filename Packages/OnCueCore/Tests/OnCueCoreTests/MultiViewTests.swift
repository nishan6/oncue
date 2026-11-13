import XCTest
@testable import OnCueCore

/// Multi View columns and Full Page lists, built from the crew snapshot.
final class MultiViewTests: XCTestCase {
    private func fixture() -> (Show, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        let cams = show.sortedCameras
        for (cam, at) in [(0, 0.0), (1, 4), (2, 8), (0, 9), (0, 10), (0, 11), (0, 12)] {
            show.addShot(inItem: song, cameraID: cams[cam].id, at: at)
        }
        return (show, song)
    }

    private func status(_ item: UUID, position: Double) -> EngineStatus {
        EngineStatus(itemID: item, index: 0, position: position, transport: .running, modes: [:], pauseReason: nil,
                     freeMode: false, loopSectionID: nil, takenAt: nil, secondsToNext: nil, timing: .internalClock,
                     timingSignal: true, tempo: nil, timecode: nil, switchers: [], hints: [], logFile: nil, cutCount: 0)
    }

    func testLiveColumnsShowTallyCurrentAndNextShots() {
        let (show, song) = fixture()
        let snap = show.crewSnapshot(status: status(song, position: 2), position: 2, running: true, scriptVersion: 0)
        let cols = snap.multiViewColumns(upcoming: 3)
        XCTAssertEqual(cols.map(\.camera.number), show.sortedCameras.map(\.number))
        XCTAssertEqual(cols[0].tally, .program)
        XCTAssertEqual(cols[0].current?.number, 1, "camera 1 has the shot on air")
        XCTAssertEqual(cols[0].upcoming.map(\.number), [4, 5, 6], "only its next three, after the one on air")
        XCTAssertEqual(cols[1].tally, .preview)
        XCTAssertNil(cols[1].current)
        XCTAssertEqual(cols[1].upcoming.map(\.number), [2])
        XCTAssertEqual(cols[2].tally, .clear)
        XCTAssertNotNil(cols[1].upcoming[0].secondsUntil, "countdown to the camera's next shot")
    }

    func testChosenCamerasKeepTheirOrder() {
        let (show, song) = fixture()
        let snap = show.crewSnapshot(status: status(song, position: 2), position: 2, running: true, scriptVersion: 0)
        XCTAssertEqual(snap.multiViewColumns(cameras: [3, 1, 99]).map(\.camera.number), [3, 1], "unknown cameras are skipped")
    }

    func testNotLiveListsTheWholeScript() {
        let (show, _) = fixture()
        let snap = show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 0)
        let cols = snap.multiViewColumns(upcoming: 8)
        XCTAssertEqual(cols[0].upcoming.map(\.number), [1, 4, 5, 6, 7])
        XCTAssertTrue(cols.allSatisfy { $0.current == nil && $0.tally == .clear })
    }

    func testFullPageOneCameraOrWholeScript() {
        let (show, song) = fixture()
        let snap = show.crewSnapshot(status: status(song, position: 2), position: 2, running: true, scriptVersion: 0)
        let one = snap.fullPage(camera: 2)
        XCTAssertEqual(one.now?.number, 1)
        XCTAssertEqual(one.upcoming.map(\.number), [2])
        XCTAssertEqual(snap.fullPage(camera: 0).upcoming.map(\.number), [2, 3, 4, 5, 6, 7])
    }

    func testShotDetailsUseTheProjectVocabulary() {
        var (show, song) = fixture()
        var vocab = ShotVocabulary()
        let lead = ShotTerm.custom("Lead vocal")
        vocab.cast = [lead]
        let id = show.shotRows(forItem: song)[0].id
        show.updateItem(song) { item in
            for t in item.tracks.indices {
                for c in item.tracks[t].cues.indices where item.tracks[t].cues[c].id == id {
                    item.tracks[t].cues[c].shotSize = "cu"
                    item.tracks[t].cues[c].movement = "push-in"
                    item.tracks[t].cues[c].framing = "1+3"
                    item.tracks[t].cues[c].subjects = [lead.key]
                }
            }
        }
        let snap = show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 0, vocabulary: vocab)
        XCTAssertEqual(snap.items[0].shots[0].details, "CU · PUSH · 1+3 · Lead vocal", "unknown keys show as typed")
        XCTAssertEqual(snap.items[0].shots[1].details, "")
    }

    func testMonitorConfigDecodesOlderFiles() throws {
        let m = try JSONDecoder().decode(MonitorConfig.self, from: Data(#"{"name":"FM","kind":"fullPage","upcoming":40}"#.utf8))
        XCTAssertEqual(m.kind, .fullPage)
        XCTAssertEqual(m.fullPageCamera, 0, "whole script by default")
        XCTAssertEqual(m.upcoming, 8, "clamped")
    }
}
