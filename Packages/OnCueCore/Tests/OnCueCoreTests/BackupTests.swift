import XCTest
@testable import OnCueCore

/// The backup Mac: follows the main Mac without sending anything, takes over on request,
/// and the link itself over localhost.
final class BackupTests: XCTestCase {
    private func scriptedShow() -> (Show, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        for k in 0..<3 { show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) }
        return (show, song)
    }

    func testBackupFollowsWithoutSendingThenTakesOver() {
        let (show, song) = scriptedShow()
        let S = show.mainOutput!.switcherID!
        let main = EngineController(show: show, itemID: song, profile: MachineProfile())
        let backup = EngineController(show: show, itemID: song, profile: MachineProfile())
        defer { main.shutdown(); backup.shutdown() }
        main.connectSwitcher()
        backup.connectSwitcher()
        backup.startFollowing()
        XCTAssertTrue(backup.status.following)
        let programBefore = backup.deviceForTesting(S)?.state.program

        main.setMode(.cut)
        main.next()
        main.next()
        XCTAssertEqual(main.status.program, 2)
        backup.follow(main.backupState)
        XCTAssertEqual(backup.status.index, 1, "same shot as the main Mac")
        XCTAssertEqual(backup.status.transport, .running)
        XCTAssertEqual(backup.deviceForTesting(S)?.state.program, programBefore, "the backup sends nothing while following")
        XCTAssertEqual(backup.log.scripted.count, 1, "the backup still logs the shot it joined on")

        // Main Mac lost: the backup takes the show in the main Mac's modes and continues.
        backup.takeOver()
        XCTAssertFalse(backup.status.following)
        XCTAssertEqual(backup.status.mode(show.mainOutput?.id), .cut)
        backup.next()
        XCTAssertEqual(backup.deviceForTesting(S)?.state.program, show.sortedCameras[2].input)
    }

    func testFollowIgnoresAnotherShow() {
        let (show, song) = scriptedShow()
        let backup = EngineController(show: show, itemID: song, profile: MachineProfile())
        defer { backup.shutdown() }
        backup.startFollowing()
        backup.follow(BackupState(showID: UUID(), itemID: song, index: 2, position: 8, transport: "running",
                                  modes: [:], freeMode: false, loopSectionID: nil, sentAt: Date()))
        XCTAssertEqual(backup.status.index, -1)
    }

    func testLinkOverLocalhost() {
        let server = BackupLinkServer()
        let ready = expectation(description: "listening")
        var port: UInt16 = 0
        server.start(port: 0) { if case .success(let p) = $0 { port = p }; ready.fulfill() }
        wait(for: [ready], timeout: 5)
        defer { server.stop() }
        server.send(show: Data("show-bytes".utf8))

        let client = BackupLinkClient()
        defer { client.disconnect() }
        let connected = expectation(description: "connected")
        let gotShow = expectation(description: "show on connect")
        let gotState = expectation(description: "state")
        let state = BackupState(showID: UUID(), itemID: UUID(), index: 3, position: 12.5, transport: "running",
                                modes: ["a": "cut"], freeMode: true, loopSectionID: nil, sentAt: Date(timeIntervalSince1970: 1_800_000_000))
        client.onConnectedChanged = { if $0 { connected.fulfill() } }
        client.onMessage = { message in
            switch message {
            case .show(let d): if d == Data("show-bytes".utf8) { gotShow.fulfill(); server.send(state: state) }
            case .state(let s): if s == state { gotState.fulfill() }
            default: break
            }
        }
        client.connect(to: "127.0.0.1:\(port)")
        wait(for: [connected, gotShow, gotState], timeout: 5)
    }
}
