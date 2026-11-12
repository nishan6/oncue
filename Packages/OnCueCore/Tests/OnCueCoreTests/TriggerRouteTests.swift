import XCTest
@testable import OnCueCore

final class TriggerRouteTests: XCTestCase {
    private func route(_ kind: TriggerInputKind, _ configure: (inout TriggerInput) -> Void = { _ in }) -> TriggerRoute {
        var input = TriggerInput(kind: kind)
        configure(&input)
        return TriggerRoute(name: "r", input: input)
    }

    func testOSCExactAndWildcard() {
        var router = TriggerRouter(routes: [
            route(.osc) { $0.address = "/oncue/go" },
            route(.osc) { $0.address = "/gma3/cue/*" },
        ])
        XCTAssertEqual(router.match(TriggerEvent(kind: .osc, address: "/oncue/go")).count, 1)
        XCTAssertEqual(router.match(TriggerEvent(kind: .osc, address: "/oncue/goo")).count, 0)
        XCTAssertEqual(router.match(TriggerEvent(kind: .osc, address: "/gma3/cue/12", value: 12)).first?.value, 12)
    }

    func testNoteOnOnlyAndChannels() {
        var router = TriggerRouter(routes: [route(.midiNote) { $0.number = 60; $0.channel = 10 }])
        XCTAssertEqual(router.match(TriggerEvent(kind: .midiNote, channel: 10, number: 60, value: 100)).count, 1)
        XCTAssertEqual(router.match(TriggerEvent(kind: .midiNote, channel: 10, number: 60, value: 0)).count, 0, "note off")
        XCTAssertEqual(router.match(TriggerEvent(kind: .midiNote, channel: 1, number: 60, value: 100)).count, 0)
        var any = TriggerRouter(routes: [route(.midiNote) { $0.number = 60 }])
        XCTAssertEqual(any.match(TriggerEvent(kind: .midiNote, channel: 7, number: 60, value: 1)).count, 1)
    }

    func testCCFiresOnceAsItCrosses() {
        var router = TriggerRouter(routes: [route(.midiCC) { $0.number = 20 }])   // threshold 64
        let cc = { (v: Double) in TriggerEvent(kind: .midiCC, channel: 1, number: 20, value: v) }
        XCTAssertEqual(router.match(cc(10)).count, 0)
        XCTAssertEqual(router.match(cc(127)).count, 1)
        XCTAssertEqual(router.match(cc(120)).count, 0, "still held")
        XCTAssertEqual(router.match(cc(0)).count, 0)
        XCTAssertEqual(router.match(cc(100)).count, 1, "pressed again")
    }

    func testArtNetFiresOnceAsTheLevelRises() {
        var router = TriggerRouter(routes: [route(.artNet) { $0.universe = 1; $0.number = 5 }])  // threshold 128
        let dmx = { (v: Double) in TriggerEvent(kind: .artNet, number: 5, value: v, universe: 1) }
        XCTAssertEqual(router.match(dmx(0)).count, 0)
        XCTAssertEqual(router.match(dmx(255)).count, 1)
        XCTAssertEqual(router.match(dmx(255)).count, 0, "DMX repeats ~40 times a second")
        XCTAssertEqual(router.match(dmx(0)).count, 0)
        XCTAssertEqual(router.match(dmx(200)).count, 1)
        XCTAssertEqual(router.match(TriggerEvent(kind: .artNet, number: 5, value: 255, universe: 2)).count, 0)
    }

    func testProgramChangeAndMSC() {
        var router = TriggerRouter(routes: [route(.midiProgram), route(.msc) { $0.msc = .go }])
        XCTAssertEqual(router.match(TriggerEvent(kind: .midiProgram, channel: 3, value: 4)).first?.value, 4)
        XCTAssertEqual(router.match(TriggerEvent(kind: .msc, value: 12.5, msc: .go)).first?.value, 12.5)
        XCTAssertEqual(router.match(TriggerEvent(kind: .msc, msc: .stop)).count, 0)
    }

    func testDisabledRoutesNeverFire() {
        var r = route(.osc) { $0.address = "/x" }
        r.enabled = false
        var router = TriggerRouter(routes: [r])
        XCTAssertTrue(router.match(TriggerEvent(kind: .osc, address: "/x")).isEmpty)
    }

    func testMSCParser() {
        // F0 7F 01 02 01 01 "12.5" 00 "1" F7 : device 1, lighting, GO cue 12.5 in list 1
        let bytes: [UInt8] = [0xF0, 0x7F, 0x01, 0x02, 0x01, 0x01, 0x31, 0x32, 0x2E, 0x35, 0x00, 0x31, 0xF7]
        let parsed = MSCParser.parse(bytes)
        XCTAssertEqual(parsed?.0, .go)
        XCTAssertEqual(parsed?.1, 12.5)
        XCTAssertNil(MSCParser.parse([0xF0, 0x7E, 0x01, 0x02, 0x01, 0x01, 0xF7]), "not MSC")
        XCTAssertNil(MSCParser.parse([0xF0, 0x7F, 0x01, 0x02, 0x01, 0x02, 0xF7])?.1, "STOP with no cue")
    }

    func testArtNetParser() {
        var packet: [UInt8] = Array("Art-Net".utf8) + [0, 0x00, 0x50, 0, 14, 0, 0, 0x03, 0x00, 0x00, 0x04]
        packet += [0, 0, 0, 255]
        let parsed = ArtNetParser.parse(packet)
        XCTAssertEqual(parsed?.universe, 3)
        XCTAssertEqual(parsed?.levels, [0, 0, 0, 255])
        packet[8] = 0x00; packet[9] = 0x20   // ArtPoll
        XCTAssertNil(ArtNetParser.parse(packet))
    }

    func testValidation() {
        var p = Project.starter(name: "T", frameRate: .r25)
        let good = TriggerRoute(name: "GO", input: { var i = TriggerInput(kind: .osc); i.address = "/oncue/go"; return i }())
        var bad = TriggerRoute(name: "bad", input: { var i = TriggerInput(kind: .osc); i.address = "oncue/go"; return i }())
        bad.action.kind = .jumpToItem
        var dup = good
        dup.id = UUID()
        p.properties.triggerRoutes = [good, bad, dup]
        let issues = p.triggerIssues()
        XCTAssertTrue(issues.contains { $0.routeID == bad.id && $0.message.contains("start with") })
        XCTAssertTrue(issues.contains { $0.routeID == bad.id && $0.message.contains("Choose a song") })
        XCTAssertTrue(issues.contains { $0.routeID == dup.id && $0.level == .warning })
        XCTAssertFalse(issues.contains { $0.routeID == good.id })
    }

    func testResolveSongFromValue() {
        var p = Project.starter(name: "T", frameRate: .r25)
        let list = p.playlists[0].id
        p.playlists[0].items.append(RundownItem(title: "Second"))
        p.playlists[0].items[1].number = "12"
        XCTAssertEqual(p.resolveItem(number: 1, playlist: list)?.id, p.playlists[0].items[0].id)
        XCTAssertEqual(p.resolveItem(number: 12, playlist: list)?.title, "Second", "scene number wins")
        XCTAssertNil(p.resolveItem(number: 5, playlist: list))
    }

    func testRoutesRoundTrip() throws {
        var p = Project.starter(name: "T", frameRate: .r25)
        var r = TriggerRoute(name: "MA3 cue → song", input: { var i = TriggerInput(kind: .msc); i.msc = .fire; return i }())
        r.action.kind = .jumpToItem
        r.action.target = .fromValue
        p.properties.triggerRoutes = [r]
        p.properties.chase.freewheel = .forSeconds
        let data = try ProjectCoding.encode(p)
        guard case .project(let back) = try ProjectCoding.decode(data) else { return XCTFail("not a project") }
        XCTAssertEqual(back.properties.triggerRoutes, [r])
        XCTAssertEqual(back.properties.chase.freewheel, .forSeconds)
    }
}

final class FreewheelTests: XCTestCase {
    func testUntilSongEnd() {
        let s = ChaseSettings()
        XCTAssertNil(s.freewheelPosition(last: (10, 100), now: 100.2, rate: 2, end: 64), "short gaps are not dropouts")
        XCTAssertEqual(s.freewheelPosition(last: (10, 100), now: 103, rate: 2, end: 64), 16)
        XCTAssertEqual(s.freewheelPosition(last: (10, 100), now: 200, rate: 2, end: 64), 64, "stops at the song's end")
    }

    func testForSecondsAndOff() {
        var s = ChaseSettings()
        s.freewheel = .forSeconds
        s.freewheelSeconds = 2
        XCTAssertEqual(s.freewheelPosition(last: (10, 100), now: 110, rate: 1, end: 64), 12)
        s.freewheel = .off
        XCTAssertNil(s.freewheelPosition(last: (10, 100), now: 110, rate: 1, end: 64))
    }
}

final class EngineTriggerTests: XCTestCase {
    private func osc(_ address: String, _ action: TriggerAction) -> TriggerRoute {
        var input = TriggerInput(kind: .osc)
        input.address = address
        return TriggerRoute(name: address, input: input, action: action)
    }

    func testRoutesDriveTheEngine() {
        var show = Show.starter()
        let song = show.items[0].id
        var second = RundownItem(title: "Second")
        second.timeBase = .seconds
        show.items.append(second)
        for k in 0..<3 { show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) }
        let controller = EngineController(show: show, itemID: song, profile: MachineProfile(),
                                          logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { controller.shutdown() }
        controller.connectSwitcher()

        var jump = TriggerAction(kind: .jumpToItem)
        jump.target = .fromValue
        var note = TriggerAction(kind: .markNote)
        note.noteText = "Late cut"
        controller.resolveItem = { value in value == 2 ? second.id : nil }
        var marked: [String] = []
        controller.onMarkNote = { _, _, text in marked.append(text) }
        controller.configureTriggers(routes: [
            osc("/ma/song", jump),
            osc("/pedal/note", note),
            osc("/pedal/chase", TriggerAction(kind: .toggleChase)),
        ], chase: ChaseSettings())

        XCTAssertTrue(controller.handleTrigger(TriggerEvent(kind: .osc, address: "/ma/song", value: 2)))
        XCTAssertEqual(controller.status.itemID, second.id)
        XCTAssertFalse(controller.handleTrigger(TriggerEvent(kind: .osc, address: "/nothing")))

        controller.handleTrigger(TriggerEvent(kind: .osc, address: "/pedal/note"))
        XCTAssertEqual(marked, ["Late cut"])

        controller.handleTrigger(TriggerEvent(kind: .osc, address: "/pedal/chase"))
        XCTAssertTrue(controller.chasePaused)
        controller.handleTrigger(TriggerEvent(kind: .osc, address: "/pedal/chase"))
        XCTAssertFalse(controller.chasePaused)
    }

    func testFireCueJumpsToTheShot() {
        var show = Show.starter()
        let song = show.items[0].id
        var ids: [UUID] = []
        for k in 0..<3 { if let id = show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) { ids.append(id) } }
        let controller = EngineController(show: show, itemID: song, profile: MachineProfile(),
                                          logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { controller.shutdown() }
        controller.connectSwitcher()
        controller.go()
        var fire = TriggerAction(kind: .fireCue)
        fire.cueID = ids[2]
        controller.perform(fire, value: nil)
        XCTAssertEqual(controller.engine.onAir?.id, ids[2])
    }
}
