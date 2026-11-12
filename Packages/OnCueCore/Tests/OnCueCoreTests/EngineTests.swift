import XCTest
import Network
@testable import OnCueCore

final class EngineTests: XCTestCase {

    /// Starter show (cameras 1–4 on inputs 1–4), one song with shots on cameras 1, 2, 3 at beats 0, 4, 8.
    private func scriptedShow(transitions: [TransitionKind] = [.cut, .cut, .cut]) -> (Show, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [SongSection(name: "Verse", at: 0), SongSection(name: "Chorus", at: 8)] }
        for (k, t) in transitions.enumerated() {
            let id = show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4))!
            show.updateCue(id, inItem: song) { $0.transition = t }
        }
        return (show, song)
    }

    // MARK: Engine

    func testDisplayModeSendsNothingButFollowsThePlayhead() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song)
        XCTAssertEqual(engine.load(itemID: song, now: 0), [])
        XCTAssertEqual(engine.start(now: 0), [])
        XCTAssertEqual(engine.onAir?.number, 1)
        XCTAssertEqual(engine.setPosition(5, now: 1), [])
        XCTAssertEqual(engine.onAir?.number, 2)
        XCTAssertEqual(engine.next?.number, 3)
    }

    func testAutoCutTakesShotsAndPreloadsTheNext() {
        let (show, song) = scriptedShow(transitions: [.cut, .auto, .cut])
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        XCTAssertEqual(engine.load(itemID: song, now: 0), [.preview(switcher: S, input: 1)], "first shot waits on preview")
        XCTAssertEqual(engine.start(now: 0), [.preview(switcher: S, input: 1), .cut(switcher: S), .preview(switcher: S, input: 2)])
        XCTAssertEqual(engine.setPosition(3.9, now: 1), [], "nothing until the next shot's position")
        XCTAssertEqual(engine.setPosition(4, now: 2), [.preview(switcher: S, input: 2), .auto(switcher: S), .preview(switcher: S, input: 3)], "a mix shot mixes")
        XCTAssertEqual(engine.setPosition(9, now: 3), [.preview(switcher: S, input: 3), .cut(switcher: S)])
        XCTAssertNil(engine.next)
    }

    func testAutoPreviewOnlyLoadsPreview() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song, mode: .preview)
        _ = engine.load(itemID: song, now: 0)
        XCTAssertEqual(engine.start(now: 0), [.preview(switcher: S, input: 2)])
        XCTAssertEqual(engine.setPosition(4, now: 1), [.preview(switcher: S, input: 3)])
    }

    func testManualCutPausesAutoCutUntilResume() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        engine.programChanged(to: 1, now: 0.1)
        XCTAssertFalse(engine.isPaused, "OnCue's own cut is expected")
        engine.programChanged(to: 4, now: 1)
        XCTAssertEqual(engine.pause?.reason, "Manual cut to input 4 on Simulator")
        XCTAssertEqual(engine.setPosition(4, now: 2), [], "paused: no commands")
        XCTAssertEqual(engine.onAir?.number, 2, "the playhead still follows")
        XCTAssertEqual(engine.resume(), [.preview(switcher: S, input: 3)])
        XCTAssertEqual(engine.setPosition(8, now: 3), [.preview(switcher: S, input: 3), .cut(switcher: S)])
    }

    func testAutoPreviewIgnoresTheDirectorsCuts() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song, mode: .preview)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        engine.programChanged(to: 2, now: 1)
        XCTAssertFalse(engine.isPaused)
    }

    func testNextBackTapAndJump() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        XCTAssertEqual(engine.next(now: 0), [.preview(switcher: S, input: 1), .cut(switcher: S), .preview(switcher: S, input: 2)])
        XCTAssertEqual(engine.transport, .running)
        _ = engine.next(now: 1)
        XCTAssertEqual(engine.position, 4)
        _ = engine.back(now: 2)
        XCTAssertEqual(engine.onAir?.number, 1)
        _ = engine.tapSection(now: 3)
        XCTAssertEqual(engine.position, 8, "tap goes to the next section")
        XCTAssertEqual(engine.onAir?.number, 3)
        let verse = show.item(song)!.sortedSections[0].id
        _ = engine.jump(toSection: verse, now: 4)
        XCTAssertEqual(engine.onAir?.number, 1)
        _ = engine.back(now: 5)
        XCTAssertEqual(engine.transport, .standby)
        XCTAssertNil(engine.onAir)
    }

    func testCamerasWithoutAnInputAreSkippedNotSent() {
        let pair = scriptedShow()
        var show = pair.0
        let song = pair.1
        let S = show.mainOutput!.switcherID!
        show.updateCamera(show.sortedCameras[1].id) { $0.input = 0 }
        let engine = ShowEngine(show: show, itemID: song, mode: .cut)
        _ = engine.load(itemID: song, now: 0)
        XCTAssertEqual(engine.start(now: 0), [.preview(switcher: S, input: 1), .cut(switcher: S)])
        XCTAssertEqual(engine.setPosition(4, now: 1), [.preview(switcher: S, input: 3)])
    }

    func testSecondsToNextUsesTheTempo() {
        let (show, song) = scriptedShow() // 120 BPM
        let engine = ShowEngine(show: show, itemID: song)
        _ = engine.load(itemID: song, now: 0)
        _ = engine.start(now: 0)
        _ = engine.setPosition(2, now: 1)
        XCTAssertEqual(engine.secondsToNext()!, 1, accuracy: 1e-9, "2 beats at 120 BPM")
    }

    // MARK: Timing

    func testMIDIClockFollower() {
        var f = MIDIClockFollower()
        f.handle(.tick(0))
        XCTAssertEqual(f.ticks, 0, "ticks before Start do not move")
        f.handle(.start)
        for k in 1...48 { f.handle(.tick(Double(k) * 0.5 / 24)) } // 120 BPM: 24 ticks per 0.5 s
        XCTAssertEqual(f.beats, 2, accuracy: 1e-9)
        XCTAssertEqual(f.tempo!, 120, accuracy: 0.01)
        f.handle(.stop)
        f.handle(.tick(3))
        XCTAssertEqual(f.beats, 2, accuracy: 1e-9)
        f.handle(.songPosition(16)) // 16 sixteenths = 4 beats
        XCTAssertEqual(f.beats, 4, accuracy: 1e-9)
    }

    func testInternalClockAndRates() {
        var item = RundownItem(title: "x")
        item.bpm = 90
        var clock = InternalClock()
        clock.start(at: 0, now: 10)
        XCTAssertEqual(clock.advance(now: 12, rate: TimingMath.rate(for: item)), 3, accuracy: 1e-9)
        clock.jump(to: 8, now: 12)
        XCTAssertEqual(clock.advance(now: 13, rate: TimingMath.rate(for: item)), 9.5, accuracy: 1e-9)
        item.timeBase = .seconds
        XCTAssertEqual(TimingMath.position(beats: 3, for: item), 2, accuracy: 1e-9)
    }

    func testLTCFollowerUsesTheItemStartOrTheFirstFrame() {
        var item = RundownItem(title: "x")
        item.timeBase = .seconds
        var f = LTCFollower()
        XCTAssertEqual(f.position(forTimecode: 3600, item: item, fps: 25), 0, "first frame anchors")
        XCTAssertEqual(f.position(forTimecode: 3610, item: item, fps: 25), 10)
        item.ltcStart = "01:00:05:00"
        f.reset()
        XCTAssertEqual(f.position(forTimecode: 3610, item: item, fps: 25), 5)
    }

    // MARK: LTC

    func testLTCRoundTrip() {
        let start = LTCFrame(hours: 1, minutes: 59, seconds: 58, frames: 20)
        var frames: [LTCFrame] = []
        var f = start
        for _ in 0..<12 {
            frames.append(f)
            f.frames += 1
            if f.frames == 25 { f.frames = 0; f.seconds += 1 }
            if f.seconds == 60 { f.seconds = 0; f.minutes += 1 }
            if f.minutes == 60 { f.minutes = 0; f.hours += 1 }
        }
        for rate in [48000.0, 44100.0] {
            let audio = LTCEncoder.samples(frames: frames, fps: 25, sampleRate: rate)
            var decoder = LTCDecoder(sampleRate: rate, fps: 25)
            // Feed in odd-sized chunks, as an audio callback would.
            var decoded: [LTCFrame] = []
            var i = 0
            while i < audio.count {
                let end = min(i + 937, audio.count)
                decoded += decoder.process(Array(audio[i..<end]))
                i = end
            }
            XCTAssertGreaterThanOrEqual(decoded.count, 10, "at \(rate) Hz")
            XCTAssertEqual(decoded.last, frames.last, "at \(rate) Hz")
            XCTAssertTrue(decoded.allSatisfy { frames.contains($0) })
        }
        XCTAssertEqual(LTCFrame(hours: 1, minutes: 0, seconds: 2, frames: 5).seconds(fps: 25), 3602.2, accuracy: 1e-9)
    }

    func testLTCDecodesInvertedAndQuietSignals() {
        let frames = (0..<6).map { LTCFrame(hours: 10, minutes: 0, seconds: 0, frames: $0) }
        let audio = LTCEncoder.samples(frames: frames, fps: 30, sampleRate: 48000, amplitude: 0.08).map { -$0 }
        var decoder = LTCDecoder(sampleRate: 48000, fps: 30)
        let decoded = decoder.process(audio)
        XCTAssertEqual(decoded.last, frames.last)
    }

    // MARK: Controller with the simulator

    func testControllerDrivesTheSimulatorAndPausesOnAManualCut() throws {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let controller = EngineController(show: show, itemID: song, profile: MachineProfile())
        defer { controller.shutdown() }
        controller.connectSwitcher()
        XCTAssertTrue(controller.status.switcherConnected)
        XCTAssertEqual(controller.status.switcherKind, .simulator)

        controller.setMode(.cut)
        XCTAssertEqual(controller.status.preview, 1, "first shot primed on preview")
        controller.next()
        XCTAssertEqual(controller.status.program, 1)
        XCTAssertEqual(controller.status.preview, 2)
        controller.next()
        XCTAssertEqual(controller.status.program, 2)
        XCTAssertNil(controller.status.pauseReason)

        // The director cuts by hand.
        let device = try XCTUnwrap(controller.deviceForTesting(show.mainOutput!.switcherID!))
        device.setProgram(4)
        XCTAssertEqual(controller.status.pauseReason, "Manual cut to input 4 on Simulator")
        controller.next()
        XCTAssertEqual(controller.status.program, 4, "paused: OnCue leaves the director's cut alone")
        controller.resume()
        XCTAssertNil(controller.status.pauseReason)
    }

    func testFastNextThroughAMixDoesNotLookLikeAManualCut() {
        let (show, song) = scriptedShow(transitions: [.auto, .cut, .cut])
        let S = show.mainOutput!.switcherID!
        let controller = EngineController(show: show, itemID: song, profile: MachineProfile())
        defer { controller.shutdown() }
        controller.connectSwitcher()
        controller.setMode(.cut)
        controller.next()   // mixes to camera 1 (the simulator takes a second)
        controller.next()   // queued behind the mix
        controller.next()
        let settled = expectation(description: "commands sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { settled.fulfill() }
        wait(for: [settled], timeout: 5)
        XCTAssertNil(controller.status.pauseReason, "OnCue's own queued cuts are not manual cuts")
        XCTAssertEqual(controller.status.program, 3)
    }

    // MARK: ATEM protocol against a stand-in switcher

    func testATEMHandshakeStateAndCommands() throws {
        let fake = try FakeATEM()
        defer { fake.stop() }
        let ready = expectation(description: "listening")
        fake.onReady = { ready.fulfill() }
        fake.start()
        wait(for: [ready], timeout: 5)

        var config = SwitcherConfig(name: "ATEM", kind: .atem, role: .main)
        config.host = "127.0.0.1:\(fake.port)"
        let atem = ATEMSwitcher(config: config)
        let connected = expectation(description: "connected with program 1")
        atem.onChange = {
            if atem.state.connected, atem.state.program == 1 { connected.fulfill(); atem.onChange = nil }
        }
        atem.connect()
        wait(for: [connected], timeout: 5)
        XCTAssertEqual(atem.state.preview, 2)
        XCTAssertEqual(atem.state.modelName, "Stand-in ATEM")

        let commands = expectation(description: "preview and cut received")
        fake.onCommand = { names in if names.contains("DCut") { commands.fulfill() } }
        atem.setPreview(3)
        atem.cut()
        wait(for: [commands], timeout: 5)
        XCTAssertEqual(fake.received.first { $0.name == "CPvI" }?.payload, [0, 0, 0, 3])
        XCTAssertNotNil(fake.received.first { $0.name == "DCut" })

        let switched = expectation(description: "program report")
        atem.onChange = { if atem.state.program == 3 { switched.fulfill(); atem.onChange = nil } }
        fake.sendState(program: 3, preview: 1)
        wait(for: [switched], timeout: 5)
        atem.disconnect()
    }
}


/// A minimal ATEM on localhost: answers the hello, sends a state dump, acknowledges commands.
final class FakeATEM {
    struct Command: Equatable { let name: String; let payload: [UInt8] }

    var onReady: (() -> Void)?
    var onCommand: (([String]) -> Void)?
    private(set) var received: [Command] = []
    private(set) var port: UInt16 = 0

    private let listener: NWListener
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "fake.atem")
    private let session: UInt16 = 0x8001
    private var packetID: UInt16 = 0

    init() throws {
        listener = try NWListener(using: .udp, on: .any)
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self, case .ready = state else { return }
            self.port = self.listener.port?.rawValue ?? 0
            DispatchQueue.main.async { self.onReady?() }
        }
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            self.connection = conn
            conn.start(queue: self.queue)
            self.receive(conn)
        }
        listener.start(queue: queue)
    }

    func stop() {
        connection?.cancel()
        listener.cancel()
    }

    func sendState(program: Int, preview: Int) {
        queue.async {
            self.sendPacket(commands: [("PrgI", [0, 0, 0, UInt8(program)]), ("PrvI", [0, 0, 0, UInt8(preview)])])
        }
    }

    private func receive(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, data.count >= 12 { self.handle([UInt8](data)) }
            if error == nil { self.receive(conn) }
        }
    }

    private func handle(_ p: [UInt8]) {
        let flags = p[0] >> 3
        if flags & 0x02 != 0 {
            // Hello: accept, then send the initial state.
            var reply = header(flags: 0x02, length: 20, session: 0x1234, packetID: 0)
            reply += [0x02, 0, 0, 0, 0, 0, 0, 0]
            connection?.send(content: Data(reply), completion: .idempotent)
            queue.asyncAfter(deadline: .now() + 0.05) {
                self.sendPacket(commands: [
                    ("_pin", Array("Stand-in ATEM".utf8) + [UInt8](repeating: 0, count: 31)),
                    ("PrgI", [0, 0, 0, 1]),
                    ("PrvI", [0, 0, 0, 2]),
                    ("InCm", [1, 0, 0, 0]),
                ])
            }
            return
        }
        if flags & 0x01 != 0 {
            // A command packet from the client: record it and acknowledge.
            var names: [String] = []
            var i = 12
            while i + 8 <= p.count {
                let len = Int(UInt16(p[i]) << 8 | UInt16(p[i + 1]))
                guard len >= 8, i + len <= p.count else { break }
                let name = String(bytes: p[(i + 4)..<(i + 8)], encoding: .ascii) ?? ""
                let command = Command(name: name, payload: Array(p[(i + 8)..<(i + len)]))
                names.append(name)
                DispatchQueue.main.async { self.received.append(command) }
                i += len
            }
            let remote = UInt16(p[10]) << 8 | UInt16(p[11])
            let ack = header(flags: 0x10, length: 12, session: session, packetID: 0, ackID: remote)
            connection?.send(content: Data(ack), completion: .idempotent)
            DispatchQueue.main.async { self.onCommand?(names) }
        }
    }

    private func sendPacket(commands: [(String, [UInt8])]) {
        var body: [UInt8] = []
        for (name, payload) in commands {
            let len = 8 + payload.count
            body += [UInt8(len >> 8), UInt8(len & 0xFF), 0, 0] + Array(name.utf8) + payload
        }
        packetID += 1
        let packet = header(flags: 0x01, length: 12 + body.count, session: session, packetID: packetID) + body
        connection?.send(content: Data(packet), completion: .idempotent)
    }

    private func header(flags: UInt8, length: Int, session: UInt16, packetID: UInt16, ackID: UInt16 = 0) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 12)
        let word = (UInt16(flags) << 11) | (UInt16(length) & 0x07FF)
        b[0] = UInt8(word >> 8); b[1] = UInt8(word & 0xFF)
        b[2] = UInt8(session >> 8); b[3] = UInt8(session & 0xFF)
        b[4] = UInt8(ackID >> 8); b[5] = UInt8(ackID & 0xFF)
        b[10] = UInt8(packetID >> 8); b[11] = UInt8(packetID & 0xFF)
        return b
    }
}

final class MTCTests: XCTestCase {
    func testQuarterFramesGiveTimeTwoFramesOn() {
        var d = MTCDecoder()
        let bytes = MTCDecoder.quarterFrames(hours: 1, minutes: 2, seconds: 3, frames: 10, rateBits: 1)
        var result: Double?
        for (k, b) in bytes.enumerated() {
            let r = d.quarterFrame(b)
            if k < 7 { XCTAssertNil(r) } else { result = r }
        }
        XCTAssertEqual(d.fps, 25)
        XCTAssertEqual(result!, 3723 + 12.0 / 25, accuracy: 1e-9)
    }

    func testOutOfOrderPiecesAreIgnored() {
        var d = MTCDecoder()
        let bytes = MTCDecoder.quarterFrames(hours: 0, minutes: 0, seconds: 5, frames: 0, rateBits: 3)
        for b in bytes.dropFirst(2) { XCTAssertNil(d.quarterFrame(b)) }
        var last: Double?
        for b in bytes { last = d.quarterFrame(b) }
        XCTAssertEqual(last!, 5 + 2.0 / 30, accuracy: 1e-9)
    }

    func testFullFrame() {
        var d = MTCDecoder()
        let t = d.fullFrame([0xF0, 0x7F, 0x7F, 0x01, 0x01, 0x20 | 10, 30, 15, 12, 0xF7])
        XCTAssertEqual(d.fps, 25)
        XCTAssertEqual(t!, 10 * 3600 + 30 * 60 + 15 + 12.0 / 25, accuracy: 1e-9)
        XCTAssertNil(d.fullFrame([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]))
    }
}
