import XCTest
@testable import OnCueCore

final class FrameRateTests: XCTestCase {
    func testPresetsAndLabels() {
        XCTAssertEqual(FrameRate.r25.label, "25")
        XCTAssertEqual(FrameRate.r23976.label, "23.976")
        XCTAssertEqual(FrameRate.r2997.label, "29.97")
        XCTAssertEqual(FrameRate.r2997DF.label, "29.97 DF")
        XCTAssertEqual(FrameRate.r5994DF.label, "59.94 DF")
        XCTAssertEqual(FrameRate.presets.count, 11)
    }

    func testDropFrameOnlyWhereItApplies() {
        XCTAssertFalse(FrameRate(numerator: 25, dropFrame: true).dropFrame)
        XCTAssertTrue(FrameRate(numerator: 30000, denominator: 1001, dropFrame: true).dropFrame)
    }

    func testCustomRates() {
        XCTAssertEqual(FrameRate.custom(29.97), .r2997)
        XCTAssertEqual(FrameRate.custom(120), FrameRate(numerator: 120))
        XCTAssertEqual(FrameRate.custom(12.5), FrameRate(numerator: 25, denominator: 2))
        XCTAssertNil(FrameRate.custom(0))
        XCTAssertNil(FrameRate.custom(5000))
    }

    func testKeyRoundTrip() {
        for rate in FrameRate.presets + [FrameRate(numerator: 25, denominator: 2)] {
            XCTAssertEqual(FrameRate(key: rate.key), rate, rate.key)
        }
    }

    func testClosestPreset() {
        XCTAssertEqual(FrameRate.closest(to: 25), .r25)
        XCTAssertEqual(FrameRate.closest(to: 29.97), .r2997)
        XCTAssertEqual(FrameRate.closest(to: 60), .r60)
    }

    func testFramesAndSecondsAreExactInverse() {
        for rate in FrameRate.presets {
            for f in [0, 1, 59, 1798, 107_892, 2_589_407] {
                XCTAssertEqual(rate.frames(seconds: rate.seconds(frames: f)), f, "\(rate.label) \(f)")
            }
        }
    }
}

final class TimecodeTests: XCTestCase {
    func testNonDropFrame() {
        XCTAssertEqual(Timecode.string(frames: 0, rate: .r25), "00:00:00:00")
        XCTAssertEqual(Timecode.string(frames: 90_000, rate: .r25), "01:00:00:00")
        XCTAssertEqual(Timecode.string(frames: 90_024, rate: .r25), "01:00:00:24")
        XCTAssertEqual(Timecode.frames("01:00:00:00", rate: .r25), 90_000)
        XCTAssertNil(Timecode.frames("01:00:00:25", rate: .r25))
        XCTAssertNil(Timecode.frames("not a time", rate: .r25))
    }

    func testDropFrameKnownValues() {
        let df = FrameRate.r2997DF
        XCTAssertEqual(Timecode.string(frames: 1799, rate: df), "00:00:59;29")
        XCTAssertEqual(Timecode.string(frames: 1800, rate: df), "00:01:00;02")
        XCTAssertEqual(Timecode.string(frames: 17_982, rate: df), "00:10:00;00")
        XCTAssertEqual(Timecode.string(frames: 107_892, rate: df), "01:00:00;00")
        XCTAssertEqual(Timecode.frames("00:01:00;02", rate: df), 1800)
        XCTAssertEqual(Timecode.frames("00:10:00;00", rate: df), 17_982)
        XCTAssertNil(Timecode.frames("00:01:00;00", rate: df), "skipped label")
    }

    func testDropFrameRoundTripsEveryFrameOfAnHour() {
        for rate in [FrameRate.r2997DF, .r5994DF] {
            let hour = rate == .r2997DF ? 107_892 : 215_784
            var f = 0
            while f < hour {
                let text = Timecode.string(frames: f, rate: rate)
                XCTAssertEqual(Timecode.frames(text, rate: rate), f, "\(rate.label) \(text)")
                f += 7
            }
        }
    }
}

final class TempoMapTests: XCTestCase {
    func testTicksBeatsSeconds() {
        let map = TempoMap(bpm: 120, beatsPerBar: 4)
        XCTAssertEqual(map.ticks(beats: 4.5), 4320)
        XCTAssertEqual(map.seconds(ticks: 960), 0.5, accuracy: 1e-12)
        XCTAssertEqual(map.ticks(seconds: 1), 1920)
        let bb = map.barBeat(ticks: 4 * 960 + 2 * 960 + 10)
        XCTAssertEqual(bb.bar, 2)
        XCTAssertEqual(bb.beat, 3)
        XCTAssertEqual(bb.tick, 10)
    }
}

final class ProjectTests: XCTestCase {
    private func legacyShow() -> Show {
        var show = Show.starter()
        show.name = "Arena v1"
        show.settings.ltcFPS = 25
        var seg = RundownItem.newSegment(title: "Host link", show: show)
        seg.plannedDuration = 61.03
        if let t = seg.tracks.firstIndex(where: { $0.kind == .shots }) {
            seg.tracks[t].cues = [Cue(at: 12.33), Cue(at: 20.0)]
        }
        show.items.append(seg)
        if let t = show.items[0].tracks.firstIndex(where: { $0.kind == .shots }) {
            show.items[0].tracks[t].cues = [Cue(at: 4.5), Cue(at: 16.333_333)]
        }
        return show
    }

    func testMigrationMakesOnePlaylistAndNumbersScenes() {
        let show = legacyShow()
        let project = Project(migrating: show)
        XCTAssertEqual(project.schemaVersion, 2)
        XCTAssertEqual(project.playlists.count, 1)
        XCTAssertEqual(project.playlists[0].name, "Arena v1")
        XCTAssertEqual(project.playlists[0].items.map(\.title), show.items.map(\.title))
        XCTAssertEqual(project.playlists[0].items.map(\.number), ["1", "2"])
        XCTAssertEqual(project.frameRate, .r25)
        XCTAssertEqual(project.cameras, show.cameras)
    }

    func testMigrationSnapsToTheGrid() throws {
        let project = Project(migrating: legacyShow())
        let seg = project.playlists[0].items[1]
        let shots = try XCTUnwrap(seg.tracks.first { $0.kind == .shots })
        // 12.33 s × 25 = 308.25 frames → 308 frames = 12.32 s
        XCTAssertEqual(shots.cues[0].at, 12.32, accuracy: 1e-9)
        XCTAssertEqual(shots.cues[1].at, 20.0, accuracy: 1e-9)
        XCTAssertEqual(seg.plannedDuration, 61.04, accuracy: 1e-9)
        let song = project.playlists[0].items[0]
        let songShots = try XCTUnwrap(song.tracks.first { $0.kind == .shots })
        XCTAssertEqual(songShots.cues[0].at, 4.5, accuracy: 1e-12, "beats stay exact")
        XCTAssertEqual(songShots.cues[1].at, 15_680.0 / 960, accuracy: 1e-12)
    }

    func testProjectRoundTripIsExactAndStoresWholeNumbers() throws {
        var project = Project(migrating: legacyShow())
        project.artist = "Shilpa Rao"
        project.venue = "Rishikesh"
        project.showDate = Date(timeIntervalSince1970: 1_800_000_000)
        // The file stores dates to the second.
        project.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        project.editedAt = Date(timeIntervalSince1970: 1_700_000_100)
        project.playlists[0].items[0].status = .wip
        project.playlists[0].items[1].frameRate = .r2997DF
        project.quantizePositions()
        let data = try ProjectCoding.encode(project)
        guard case .project(let back) = try ProjectCoding.decode(data) else { return XCTFail("not a project") }
        XCTAssertEqual(back, project)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let playlists = try XCTUnwrap(json["playlists"] as? [[String: Any]])
        let items = try XCTUnwrap(playlists[0]["items"] as? [[String: Any]])
        XCTAssertEqual(items[0]["positionUnit"] as? String, "ticks")
        XCTAssertEqual(items[1]["positionUnit"] as? String, "frames")
        let tracks = try XCTUnwrap(items[1]["tracks"] as? [[String: Any]])
        let shots = try XCTUnwrap(tracks.first { ($0["kind"] as? String) == "shots" })
        let cues = try XCTUnwrap(shots["cues"] as? [[String: Any]])
        for cue in cues {
            let at = try XCTUnwrap(cue["at"] as? Double)
            XCTAssertEqual(at, at.rounded(), "stored as whole frames")
        }
    }

    func testLegacyFileIsRecognised() throws {
        let data = try ShowCoding.encode(legacyShow())
        guard case .legacyShow(let show) = try ProjectCoding.decode(data) else { return XCTFail("expected legacy") }
        XCTAssertEqual(show.name, "Arena v1")
    }

    func testNewerFileIsRefused() {
        let data = Data(#"{"schemaVersion": 99, "playlists": []}"#.utf8)
        XCTAssertThrowsError(try ProjectCoding.decode(data)) { error in
            XCTAssertEqual(error as? ShowFileError, .unsupportedVersion(found: 99, supported: 2))
        }
    }

    func testBridgeEditsComeBackToThePlaylist() {
        var project = Project.starter(name: "Bridge", frameRate: .r25)
        let id = project.playlists[0].id
        var show = project.show(playlist: id)
        show.items[0].title = "Opener"
        show.cameras[0].name = "Wide"
        project.apply(show, playlist: id)
        XCTAssertEqual(project.playlists[0].items[0].title, "Opener")
        XCTAssertEqual(project.cameras[0].name, "Wide")
    }

    func testStarterUsesSceneDefaults() {
        let project = Project.starter(name: "Defaults", frameRate: .r50)
        let scene = project.playlists[0].items[0]
        XCTAssertEqual(scene.number, "1")
        XCTAssertEqual(scene.plannedDuration, 180)
        XCTAssertTrue(scene.tracks.contains { $0.kind == .shots })
        XCTAssertTrue(scene.tracks.contains { $0.kind == .fx })
        XCTAssertTrue(scene.tracks.contains { $0.kind == .osc })
        XCTAssertTrue(scene.tracks.contains { $0.kind == .ptz })
        XCTAssertTrue(scene.tracks.contains { $0.kind == .lyrics })
        XCTAssertEqual(project.properties.roles.count, 10)
        XCTAssertEqual(project.properties.sceneDefaults.tracks.count, 9)
    }

    func testAddingAShowAsAPlaylistMatchesCamerasByNumber() {
        var project = Project.starter(name: "Tour", frameRate: .r25)
        let show = legacyShow()
        let before = project.cameras.count
        let id = project.addPlaylist(from: show)
        XCTAssertEqual(project.playlists.count, 2)
        XCTAssertEqual(project.cameras.count, max(before, show.cameras.count))
        let added = project.playlist(id)!
        let camIDs = Set(project.cameras.map(\.id))
        for item in added.items {
            for t in item.tracks { for c in t.cues { if let cam = c.cameraID { XCTAssertTrue(camIDs.contains(cam)) } } }
        }
    }
}

final class ProjectVersionTests: XCTestCase {
    func testRestoreKeepsLaterVersionsAndAddsNewOnes() throws {
        var project = Project.starter(name: "Versions", frameRate: .r25)
        project.saveVersion(name: "A")
        let a = project.versions[0].id
        project.playlists[0].items[0].title = "Changed"
        project.saveVersion(name: "B")
        XCTAssertEqual(project.versions.count, 2)

        try project.restoreVersion(a)
        XCTAssertEqual(project.playlists[0].items[0].title, "Scene 1")
        let names = project.versions.map(\.name)
        XCTAssertEqual(names.prefix(2), ["A", "B"], "later versions are kept")
        XCTAssertTrue(names.contains("Before restoring “A”"))
        XCTAssertEqual(names.last, "Restored “A”")

        // The pre-restore state can itself be restored.
        let before = try XCTUnwrap(project.versions.first { $0.name == "Before restoring “A”" })
        try project.restoreVersion(before.id)
        XCTAssertEqual(project.playlists[0].items[0].title, "Changed")
    }

    func testAutomaticVersionSkippedWhenNothingChanged() {
        var project = Project.starter(name: "Same", frameRate: .r25)
        XCTAssertTrue(project.saveVersion(name: "1", automatic: true))
        XCTAssertFalse(project.saveVersion(name: "2", automatic: true))
    }
}
