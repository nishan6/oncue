import XCTest
@testable import OnCueCore

/// Multiple switchers and outputs, FX / OSC / PTZ / control cues, loop, free mode, panic,
/// switch log analysis and camera down.
final class ShowControlTests: XCTestCase {

    private func baseShow() -> (Show, UUID, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [SongSection(name: "Verse", at: 0), SongSection(name: "Chorus", at: 8)] }
        for (k, at) in [0.0, 4, 8].enumerated() {
            show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: at)
        }
        return (show, song, show.mainOutput!.switcherID!)
    }

    // MARK: Sub-switchers and outputs

    func testSubSwitcherRoutesThroughItsFeed() {
        var (show, song, main) = baseShow()
        // Camera 3 sits on a sub-switcher (its input 7) that feeds main input 10.
        let sub = SwitcherConfig(name: "Sub", kind: .simulator, role: .sub, parentID: main, feedInput: 10)
        show.switchers.append(sub)
        show.updateCamera(show.sortedCameras[2].id) { $0.switcherID = sub.id; $0.input = 7 }
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        // Shot 2 (camera 2) on air: shot 3 is prepared by putting the sub on camera 3, main preview on the feed.
        let atShot2 = engine.setPosition(4, now: 1)
        XCTAssertEqual(atShot2, [.preview(switcher: main, input: 2), .cut(switcher: main),
                                 .program(switcher: sub.id, input: 7), .preview(switcher: main, input: 10)])
        let atShot3 = engine.setPosition(8, now: 2)
        XCTAssertEqual(atShot3, [.program(switcher: sub.id, input: 7), .preview(switcher: main, input: 10), .cut(switcher: main)])
        XCTAssertEqual(engine.route(show.sortedCameras[2].id, to: main), ShowEngine.Route(input: 10, feeds: [(sub.id, 7)]))
    }

    func testSeparateOutputWithItsOwnTrackAndMode() {
        var (show, song, main) = baseShow()
        let led = SwitcherConfig(name: "LED", kind: .simulator, role: .output)
        show.switchers.append(led)
        let ledOutput = OutputConfig(name: "LED wall", switcherID: led.id)
        show.outputs.append(ledOutput)
        show.ensureShotTracks()
        // Cameras are split to the LED switcher on inputs 21, 22...
        for (k, cam) in show.sortedCameras.enumerated() {
            show.updateCamera(cam.id) { $0.extraInputs = [CameraInput(switcherID: led.id, input: 21 + k)] }
        }
        let trackID = show.item(song)!.shotsTrack(for: ledOutput.id)!.id
        let t = show.items[0].tracks.firstIndex { $0.id == trackID }!
        show.items[0].tracks[t].cues = [Cue(at: 0, cameraID: show.sortedCameras[3].id), Cue(at: 6, cameraID: show.sortedCameras[0].id)]

        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.setMode(.cut, for: ledOutput.id)
        _ = engine.load(itemID: song, now: 0)
        let start = engine.start(now: 0)
        XCTAssertTrue(start.contains(.cut(switcher: led.id)))
        XCTAssertTrue(start.contains(.preview(switcher: led.id, input: 24)), "LED takes its own track's camera 4")
        XCTAssertFalse(start.contains(.cut(switcher: main)), "main output stays in display")
        let at6 = engine.setPosition(6, now: 1)
        XCTAssertEqual(at6, [.preview(switcher: led.id, input: 21), .cut(switcher: led.id)])
    }

    func testMirroringOutputFollowsTheMainCut() {
        var (show, song, _) = baseShow()
        let imag = SwitcherConfig(name: "IMAG", kind: .simulator, role: .output)
        show.switchers.append(imag)
        var output = OutputConfig(name: "IMAG", switcherID: imag.id)
        output.mirrorMain = true
        show.outputs.append(output)
        for cam in show.sortedCameras { show.updateCamera(cam.id) { $0.extraInputs = [CameraInput(switcherID: imag.id, input: cam.number + 100)] } }
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.setMode(.cut, for: output.id)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        XCTAssertEqual(engine.setPosition(4, now: 1), [.preview(switcher: imag.id, input: 102), .cut(switcher: imag.id),
                                                       .preview(switcher: imag.id, input: 103)])
    }

    func testAuxOutputSetsTheAux() {
        var (show, song, main) = baseShow()
        var aux = OutputConfig(name: "Stage screen", switcherID: main)
        aux.bus = .aux
        aux.auxIndex = 1
        aux.mirrorMain = true
        show.outputs.append(aux)
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.setMode(.cut, for: aux.id)
        _ = engine.load(itemID: song, now: 0)
        XCTAssertEqual(engine.start(now: 0), [.aux(switcher: main, aux: 1, input: 1)])
    }

    // MARK: FX, OSC, PTZ, control

    func testCuesFireOnceWhenThePlayheadPassesThem() {
        var (show, song, main) = baseShow()
        let target = OSCTarget(name: "Resolume", host: "127.0.0.1", port: 7000)
        show.oscTargets = [target]
        let ptzCam = PTZCamera(name: "PTZ 1")
        show.ptzCameras = [ptzCam]
        let fx = show.addTrackCue(.fx, inItem: song, at: 2)!
        show.updateCue(fx, inItem: song) { $0.fxAction = .dskOn; $0.fxIndex = 0 }
        let oscTrack = show.ensureTrack(.osc, inItem: song)!
        let ptzTrack = show.ensureTrack(.ptz, inItem: song)!
        let i = show.itemIndex(song)!
        show.items[i].tracks[show.items[i].tracks.firstIndex { $0.id == oscTrack }!].cues =
            [Cue(at: 3, oscTargetID: target.id, oscAddress: "/composition/columns/2/connect", oscArgs: "1")]
        show.items[i].tracks[show.items[i].tracks.firstIndex { $0.id == ptzTrack }!].cues =
            [Cue(at: 5, ptzCameraID: ptzCam.id, ptzPreset: 3)]

        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        let to35 = engine.setPosition(3.5, now: 1)
        XCTAssertTrue(to35.contains(.dsk(switcher: main, index: 0, on: true)))
        XCTAssertTrue(to35.contains(.osc(target: target.id, address: "/composition/columns/2/connect", args: "1")))
        XCTAssertFalse(engine.setPosition(3.6, now: 2).contains { if case .osc = $0 { return true } else { return false } }, "fires once")
        XCTAssertTrue(engine.setPosition(6, now: 3).contains(.ptz(camera: ptzCam.id, preset: 3)))
        _ = engine.back(now: 4)
        XCTAssertTrue(engine.setPosition(6.5, now: 5).contains(.ptz(camera: ptzCam.id, preset: 3)),
                      "going back re-arms the cues ahead, like replaying a timeline")
    }

    func testDisplayModeSendsOSCButNotFX() {
        var (show, song, _) = baseShow()
        let target = OSCTarget(name: "Lights")
        show.oscTargets = [target]
        let fx = show.addTrackCue(.fx, inItem: song, at: 1)!
        show.updateCue(fx, inItem: song) { $0.fxAction = .macro; $0.fxIndex = 4 }
        let oscTrack = show.ensureTrack(.osc, inItem: song)!
        let i = show.itemIndex(song)!
        show.items[i].tracks[show.items[i].tracks.firstIndex { $0.id == oscTrack }!].cues =
            [Cue(at: 1, oscTargetID: target.id, oscAddress: "/go")]
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        let commands = engine.setPosition(2, now: 1)
        XCTAssertEqual(commands, [.osc(target: target.id, address: "/go", args: "")])
    }

    func testControlTrackLoadsTheNextItem() {
        var (show, song, _) = baseShow()
        let second = show.addSong(title: "Second")
        let control = show.ensureTrack(.control, inItem: song)!
        let i = show.itemIndex(song)!
        show.items[i].tracks[show.items[i].tracks.firstIndex { $0.id == control }!].cues = [Cue(at: 10, controlAction: .loadNext)]
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        _ = engine.setPosition(11, now: 1)
        XCTAssertEqual(engine.cursor.itemID, second)
        XCTAssertEqual(engine.transport, .standby)
    }

    func testControlStopHaltsTheTransport() {
        var (show, song, _) = baseShow()
        let control = show.ensureTrack(.control, inItem: song)!
        let i = show.itemIndex(song)!
        show.items[i].tracks[show.items[i].tracks.firstIndex { $0.id == control }!].cues = [Cue(at: 6, controlAction: .wait)]
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        _ = engine.setPosition(7, now: 1)
        XCTAssertEqual(engine.transport, .stopped)
        _ = engine.setPosition(9, now: 2)
        XCTAssertEqual(engine.onAir?.number, 2, "waiting: the clock does not move the script")
    }

    // MARK: Loop, free mode, panic

    func testLoopRepeatsTheSectionUntilReleased() {
        let (show, song, _) = baseShow() // Verse 0-8, Chorus 8-end
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        _ = engine.setPosition(raw: 5, now: 1)
        engine.toggleLoop()
        _ = engine.setPosition(raw: 9, now: 2)
        XCTAssertEqual(engine.position, 1, accuracy: 1e-9, "wrapped to the verse start")
        XCTAssertEqual(engine.onAir?.number, 1)
        engine.toggleLoop()
        _ = engine.setPosition(raw: 17, now: 3)
        XCTAssertEqual(engine.position, 9, accuracy: 1e-9, "released: carries on from the repeat")
        XCTAssertEqual(engine.onAir?.number, 3)
    }

    func testFreeModeHoldsTheScriptAndSendsNothing() {
        let (show, song, _) = baseShow()
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        _ = engine.setFreeMode(true)
        XCTAssertEqual(engine.setPosition(raw: 6, now: 1), [])
        XCTAssertEqual(engine.onAir?.number, 1)
        engine.programChanged(to: 4, now: 2)
        XCTAssertFalse(engine.isPaused, "free mode: the director's cuts are expected")
        XCTAssertFalse(engine.setFreeMode(false).isEmpty, "leaving free mode prepares the next shot")
        _ = engine.setPosition(raw: 10, now: 3)
        XCTAssertEqual(engine.position, 4, accuracy: 1e-9, "continues from where the script held")
    }

    func testPanicDropsEveryOutputToDisplay() {
        let (show, song, _) = baseShow()
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        engine.panic()
        XCTAssertEqual(engine.mode, .display)
        XCTAssertEqual(engine.start(now: 0), [])
    }

    // MARK: Switch log

    func testAnalysisMatchesScriptedShotsToCuts() {
        let (show, song, main) = baseShow()
        let cams = show.sortedCameras
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        var log = SwitchLog(showID: show.id, showName: show.name, started: t0)
        let out = show.mainOutput!.id
        func scripted(_ s: Double, _ cam: Int, _ n: Int) {
            log.entries.append(SwitchLogEntry(kind: .scripted, date: t0 + s, outputID: out, cameraID: cams[cam].id, itemID: song, shotNumber: n, mode: "cut"))
        }
        func cut(_ s: Double, _ cam: Int) {
            log.entries.append(SwitchLogEntry(kind: .cut, date: t0 + s, switcherID: main, input: cam + 1, cameraID: cams[cam].id, mode: "cut"))
        }
        scripted(0, 0, 1); cut(0.1, 0)
        scripted(10, 1, 2); cut(9.6, 1)        // early by 0.4
        scripted(20, 2, 3)                      // missed
        cut(25, 3)                              // off script
        let a = ShowAnalysis(log: log, show: show, end: t0 + 30)
        XCTAssertEqual(a.cutCount, 3)
        XCTAssertEqual(a.hits, 2)
        XCTAssertEqual(a.missed, 1)
        XCTAssertEqual(a.offScript.count, 1)
        XCTAssertEqual(a.averageOffset!, (0.1 - 0.4) / 2, accuracy: 1e-5)
        XCTAssertEqual(a.cameras.first { $0.cameraID == cams[1].id }!.onAirSeconds, 15.4, accuracy: 1e-5)
        XCTAssertEqual(a.cutsPerMinute, 3 / (29.9 / 60), accuracy: 1e-4)

        let decoded = try! SwitchLog.decode(log.encoded())
        XCTAssertEqual(decoded.entries.count, log.entries.count)
        XCTAssertEqual(decoded.entries[1].date.timeIntervalSince1970, log.entries[1].date.timeIntervalSince1970, accuracy: 0.001,
                       "milliseconds survive")
    }

    func testVarietyHintsPreferCamerasOffAirLongest() {
        let (show, _, main) = baseShow()
        let cams = show.sortedCameras
        var log = SwitchLog(showID: show.id, showName: "x", started: Date())
        for (k, cam) in [0, 1, 0, 2].enumerated() {
            log.entries.append(SwitchLogEntry(kind: .cut, date: Date(timeIntervalSince1970: Double(k)), switcherID: main,
                                              input: cam + 1, cameraID: cams[cam].id, mode: "display"))
        }
        let hints = show.varietyHints(log: log, now: Date(), count: 2, excluding: cams[2].id)
        XCTAssertEqual(hints.map(\.number), [4, 2], "never used first, then the oldest")
    }

    // MARK: Camera down

    func testCameraDownMovesOnlyTheRequestedUpcomingShots() {
        var (show, song, _) = baseShow()
        let cam1 = show.sortedCameras[0].id, cam4 = show.sortedCameras[3].id
        show.addShot(inItem: song, cameraID: cam1, at: 12)
        let next = show.addSong(title: "Next")
        show.addShot(inItem: next, cameraID: cam1, at: 0)
        show.addShot(inItem: next, cameraID: cam1, at: 4)
        let cursor = LiveCursor(itemID: song, index: 0) // shot 1 (camera 1) on air
        XCTAssertEqual(show.upcomingShotCount(camera: cam1, from: cursor), 3)
        let moved = show.reassignUpcomingShots(from: cam1, to: cam4, count: 2, after: cursor)
        XCTAssertEqual(moved, 2)
        XCTAssertEqual(show.shotRows(forItem: song)[0].cue.cameraID, cam1, "the shot on air stays")
        XCTAssertEqual(show.shotRows(forItem: song).last?.cue.cameraID, cam4)
        XCTAssertEqual(show.shotRows(forItem: next).map(\.cue.cameraID), [cam4, cam1], "only two moved")
    }
}
