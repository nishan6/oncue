import XCTest
@testable import OnCueCore

final class DeviceWireTests: XCTestCase {
    func testMIDI() {
        var s = DeviceSend(kind: .midiNote)
        s.channel = 10; s.number = 36; s.value = 100
        XCTAssertEqual(DeviceWire.midi(s), [0x99, 36, 100])
        s.kind = .midiCC; s.channel = 1; s.number = 7; s.value = 64
        XCTAssertEqual(DeviceWire.midi(s), [0xB0, 7, 64])
        s.kind = .midiProgram; s.number = 1
        XCTAssertEqual(DeviceWire.midi(s), [0xC0, 0], "program 1 is sent as 0")
    }

    func testMSCRoundTripsThroughTheParser() {
        var s = DeviceSend(kind: .msc)
        s.msc = .go; s.mscCue = "12.5"; s.mscList = "1"
        let bytes = DeviceWire.msc(s)
        XCTAssertEqual(bytes, [0xF0, 0x7F, 0x7F, 0x02, 0x01, 0x01, 0x31, 0x32, 0x2E, 0x35, 0x00, 0x31, 0xF7])
        let parsed = MSCParser.parse(bytes)
        XCTAssertEqual(parsed?.0, .go)
        XCTAssertEqual(parsed?.1, 12.5)
        s.mscCue = ""
        XCTAssertEqual(DeviceWire.msc(s), [0xF0, 0x7F, 0x7F, 0x02, 0x01, 0x01, 0xF7])
    }

    func testTextEscapesAndEndings() {
        XCTAssertEqual(DeviceWire.text("PLAY\\r", ending: .none), Array("PLAY".utf8) + [0x0D])
        XCTAssertEqual(DeviceWire.text("\\x02POW ON\\x03", ending: .crlf), [0x02] + Array("POW ON".utf8) + [0x03, 0x0D, 0x0A])
        XCTAssertEqual(DeviceWire.text("a\\\\b", ending: .lf), Array("a\\b".utf8) + [0x0A])
        XCTAssertEqual(DeviceWire.text("\\xZZ", ending: .none), Array("\\xZZ".utf8), "bad escapes are sent as typed")
    }

    func testHTTPURL() {
        var s = DeviceSend(kind: .http)
        s.path = "api/location/1/0/0/press"
        XCTAssertEqual(DeviceWire.url(s, base: "http://10.0.0.5:8000/")?.absoluteString, "http://10.0.0.5:8000/api/location/1/0/0/press")
        s.path = "https://example.com/x"
        XCTAssertEqual(DeviceWire.url(s, base: "http://10.0.0.5")?.absoluteString, "https://example.com/x")
    }

    func testArtDmxParsesBack() {
        var levels = [UInt8](repeating: 0, count: 512)
        levels[0] = 255; levels[511] = 7
        let packet = DeviceWire.artDmx(universe: 3, levels: levels, sequence: 9)
        XCTAssertEqual(packet.count, 530)
        let back = ArtNetParser.parse(packet)
        XCTAssertEqual(back?.universe, 3)
        XCTAssertEqual(back?.levels.first, 255)
        XCTAssertEqual(back?.levels.last, 7)
    }

    func testSACNLayout() {
        var levels = [UInt8](repeating: 0, count: 512)
        levels[0] = 200
        let p = DeviceWire.sACN(universe: 2, levels: levels, sequence: 1, cid: UUID())
        XCTAssertEqual(p.count, 638)
        XCTAssertEqual(Array(p[4..<13]), Array("ASC-E1.17".utf8))
        XCTAssertEqual(Int(p[16]) << 8 | Int(p[17]), 0x7000 | 622, "root layer flags and length")
        XCTAssertEqual(Int(p[38]) << 8 | Int(p[39]), 0x7000 | 600, "framing layer")
        XCTAssertEqual(Int(p[113]) << 8 | Int(p[114]), 2, "universe")
        XCTAssertEqual(Int(p[115]) << 8 | Int(p[116]), 0x7000 | 523, "DMP layer")
        XCTAssertEqual(p[125], 0, "start code")
        XCTAssertEqual(p[126], 200, "channel 1")
        XCTAssertEqual(DeviceWire.sACNMulticast(universe: 300), "239.255.1.44")
    }

    func testDMXFades() {
        var mixer = DMXMixer()
        let t = UUID()
        mixer.set(target: t, channel: 5, level: 255, fade: 2, now: 10)
        XCTAssertEqual(mixer.advance(now: 11), [t])
        XCTAssertEqual(mixer.value(target: t, channel: 5), 127.5, accuracy: 0.01)
        _ = mixer.advance(now: 13)
        XCTAssertEqual(mixer.bytes(target: t)[4], 255)
        XCTAssertFalse(mixer.fading)
        mixer.set(target: t, channel: 5, level: 0, fade: 0, now: 14)
        XCTAssertEqual(mixer.bytes(target: t)[4], 0)
    }
}

final class EngineDeviceTests: XCTestCase {
    func testDeviceCueFiresToASimulatedTarget() {
        var show = Show.starter()
        let song = show.items[0].id
        var target = DeviceTarget(name: "MA3", kind: .midi)
        target.simulated = true
        show.deviceTargets = [target]
        show.addShot(inItem: song, cameraID: show.sortedCameras[0].id, at: 0)
        if let c = show.addTrackCue(.device, inItem: song, at: 0) {
            show.updateCue(c, inItem: song) { cue in
                cue.sendTargetID = target.id
                var s = DeviceSend(kind: .msc)
                s.mscCue = "7"
                cue.send = s
            }
        }
        let c = EngineController(show: show, itemID: song, profile: MachineProfile(),
                                 logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { c.shutdown() }
        c.connectSwitcher()
        c.go()
        XCTAssertEqual(c.recentDeviceSends.first?.summary, "MSC GO 7")
        XCTAssertEqual(c.recentDeviceSends.first?.simulated, true)
        XCTAssertNil(c.recentDeviceSends.first?.error)
    }

    func testTallyInCatchesAManualCut() {
        var show = Show.starter()
        let song = show.items[0].id
        for k in 0..<3 { show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) }
        var tally = TallyInputConfig()
        tally.switcherID = show.switchers[0].id
        show.tallyInputs = [tally]
        let c = EngineController(show: show, itemID: song, profile: MachineProfile(),
                                 logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { c.shutdown() }
        c.connectSwitcher()
        c.go()
        XCTAssertNil(c.engine.pause)
        // The last camera reported on program: nothing in the script put it there.
        let other = show.sortedCameras.last!
        c.tallyIn(tally, index: other.number)
        XCTAssertNotNil(c.engine.pause)
        XCTAssertEqual(c.tallyInProgram[tally.id], other.input)
    }
}
