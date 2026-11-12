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
