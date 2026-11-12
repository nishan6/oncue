import XCTest
import Network
@testable import OnCueCore

/// The pre-show check against stand-ins: a simulator, a stand-in ATEM, an address nobody answers
/// on, a TCP listener standing in for a PTZ camera, and stubbed MIDI and audio devices.
final class PreShowCheckTests: XCTestCase {

    private func profile() -> MachineProfile {
        var p = MachineProfile()
        p.logFolder = FileManager.default.temporaryDirectory.appendingPathComponent("oncue-check-\(UUID().uuidString)").path
        return p
    }

    private func runToEnd(_ check: PreShowCheck, timeout: TimeInterval = 10) {
        check.run()
        let end = Date().addingTimeInterval(timeout)
        while check.running && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertFalse(check.running, "check finished")
    }

    private func item(_ check: PreShowCheck, _ prefix: String) -> CheckItem? {
        check.items.first { $0.id.hasPrefix(prefix) }
    }

    func testSampleShowOnTheSimulator() {
        let show = Show.sample()
        let check = PreShowCheck(show: show, profile: profile())
        runToEnd(check)
        XCTAssertEqual(item(check, "inputs")?.status, .pass)
        XCTAssertEqual(item(check, "nocam")?.status, .pass)
        XCTAssertEqual(item(check, "sw-")?.status, .info, "simulator")
        XCTAssertEqual(item(check, "signal")?.status, .info, "picture is never claimed")
        XCTAssertEqual(item(check, "logs")?.status, .pass)
        XCTAssertEqual(check.failures, 0)
    }

    func testProblemsAreFound() {
        var show = Show.sample()
        let song = show.items[0].id
        show.addShot(inItem: song, cameraID: nil, at: 200)
        show.updateCamera(show.sortedCameras[1].id) { $0.input = 0 }
        let firstInput = show.sortedCameras[0].input
        show.updateCamera(show.sortedCameras[2].id) { $0.input = firstInput }
        show.updateItem(song) { $0.syncMode = .midiClock }
        var p = profile()
        p.midiClockSource = "Ableton Push"
        let check = PreShowCheck(show: show, profile: p)
        check.midiSources = { ["IAC Driver Bus 1"] }
        runToEnd(check)
        XCTAssertEqual(item(check, "inputs")?.status, .fail)
        XCTAssertEqual(item(check, "clash")?.status, .warn)
        XCTAssertEqual(item(check, "nocam")?.status, .fail)
        XCTAssertTrue(item(check, "nocam")!.detail.contains(show.items[0].title))
        XCTAssertEqual(item(check, "midi")?.status, .fail)

        let present = PreShowCheck(show: show, profile: p)
        present.midiSources = { ["Ableton Push"] }
        runToEnd(present)
        XCTAssertEqual(item(present, "midi")?.status, .pass)
    }

    func testATEMThatAnswersAndOneThatDoesnt() throws {
        let fake = try FakeATEM()
        defer { fake.stop() }
        let ready = expectation(description: "listening")
        fake.onReady = { ready.fulfill() }
        fake.start()
        wait(for: [ready], timeout: 5)

        var show = Show.sample()
        let main = show.mainOutput!.switcherID!
        show.updateSwitcher(main) { $0.kind = .atem; $0.host = "127.0.0.1:\(fake.port)" }
        let check = PreShowCheck(show: show, profile: profile())
        runToEnd(check)
        let sw = item(check, "sw-")
        XCTAssertEqual(sw?.status, .pass, sw?.detail ?? "")
        XCTAssertTrue(sw?.detail.contains("Stand-in ATEM") ?? false)

        // Nothing listens on this port.
        show.updateSwitcher(main) { $0.host = "127.0.0.1:9" }
        let silent = PreShowCheck(show: show, profile: profile())
        silent.timeout = 1
        runToEnd(silent)
        XCTAssertEqual(item(silent, "sw-")?.status, .fail)
    }

    func testPTZOverTCP() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = expectation(description: "listening")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.newConnectionHandler = { $0.start(queue: .global()) }
        listener.start(queue: .global())
        wait(for: [ready], timeout: 5)
        defer { listener.cancel() }

        var show = Show.sample()
        show.ptzCameras = [PTZCamera(name: "Jib head", proto: .viscaTCP, host: "127.0.0.1", port: Int(listener.port!.rawValue)),
                           PTZCamera(name: "Closed", proto: .viscaTCP, host: "127.0.0.1", port: 9),
                           PTZCamera(name: "UDP head", proto: .viscaIP, host: "10.0.0.9")]
        let check = PreShowCheck(show: show, profile: profile())
        check.timeout = 2
        runToEnd(check)
        let ptz = check.items.filter { $0.group == "PTZ" }
        XCTAssertEqual(ptz.map(\.status), [.pass, .fail, .info])
    }
}
