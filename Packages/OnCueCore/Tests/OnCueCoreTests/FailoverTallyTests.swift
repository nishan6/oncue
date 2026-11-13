import XCTest
@testable import OnCueCore

final class TallyStateTests: XCTestCase {
    func testProgramPreviewAndNames() {
        var show = Show.starter()
        show.cameras[0].name = "Wide"
        show.cameras[0].operatorName = "Arjun"
        let config = TallyOutputConfig()
        let p = show.cameras[0].input, v = show.cameras[1].input
        let states = show.tallyStates(program: p, preview: v, switcherID: nil, config: config)
        XCTAssertEqual(states.count, show.cameras.count)
        XCTAssertEqual(states[0], TallyState(index: show.cameras[0].number, program: true, preview: false, text: "\(show.cameras[0].number) Wide – Arjun"))
        XCTAssertTrue(states[1].preview)
        XCTAssertFalse(states[1].program)
        XCTAssertTrue(states.dropFirst(2).allSatisfy { !$0.program && !$0.preview })
    }

    func testIndexByInputAndNoNames() {
        var show = Show.starter()
        show.cameras[0].input = 9
        var config = TallyOutputConfig()
        config.indexMode = .switcherInput
        config.sendNames = false
        let states = show.tallyStates(program: 9, preview: nil, switcherID: nil, config: config)
        XCTAssertEqual(states.first { $0.program }?.index, 9)
        XCTAssertTrue(states.allSatisfy { $0.text.isEmpty })
    }

    func testPacketsPerVersion() {
        let t = [TallyState(index: 1, program: true, text: "1 Wide")]
        var c = TallyOutputConfig()
        c.version = .v31
        XCTAssertEqual(Show.tallyPackets(t, config: c).first?.count, 18)
        c.version = .v50
        c.transport = .tcp
        XCTAssertEqual(Array(Show.tallyPackets(t, config: c).first!.prefix(2)), [0xFE, 0x02])
    }
}

final class FailoverTests: XCTestCase {
    private func rig(policy: FailoverPolicy) -> (EngineController, UUID, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        for k in 0..<3 { show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) }
        let main = show.switchers[0].id
        show.switchers[0].failover = policy
        show.switchers[0].failoverTimeout = 0
        var parallel = SwitcherConfig(name: "Parallel")
        parallel.kind = .simulator
        parallel.mirrorOf = main
        show.switchers.append(parallel)
        let c = EngineController(show: show, itemID: song, profile: MachineProfile(),
                                 logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        c.connectSwitcher()
        return (c, main, parallel.id)
    }

    func testParallelSwitcherGetsEveryCommand() {
        let (c, main, parallel) = rig(policy: .automatic)
        defer { c.shutdown() }
        c.go()
        c.next()
        let byID = Dictionary(uniqueKeysWithValues: c.status.switchers.map { ($0.id, $0) })
        XCTAssertEqual(byID[parallel]?.program, byID[main]?.program)
        XCTAssertEqual(byID[parallel]?.preview, byID[main]?.preview)
    }

    func testAutomaticFailoverAndRecovery() {
        let (c, main, parallel) = rig(policy: .automatic)
        defer { c.shutdown() }
        c.go()
        c.simulateLoss(main, lost: true)
        c.tickForTesting()
        XCTAssertEqual(c.failedOver[main], parallel)
        XCTAssertTrue(c.failoverLog.last?.message.contains("Failed over") ?? false)
        c.simulateLoss(main, lost: false)
        XCTAssertNil(c.failedOver[main])
        XCTAssertTrue(c.failoverLog.last?.message.contains("is back") ?? false)
    }

    func testAskFirstWaitsForYou() {
        let (c, main, parallel) = rig(policy: .ask)
        defer { c.shutdown() }
        c.go()
        c.simulateLoss(main, lost: true)
        c.tickForTesting()
        XCTAssertNil(c.failedOver[main])
        XCTAssertEqual(c.failoverPrompt, main)
        c.failover(main)
        XCTAssertEqual(c.failedOver[main], parallel)
        XCTAssertNil(c.failoverPrompt)
    }

    func testRealSwitchersAreNeverUnpluggedFromHere() {
        var show = Show.starter()
        show.switchers[0].kind = .atem
        show.switchers[0].host = "192.0.2.1"
        let c = EngineController(show: show, itemID: show.items[0].id, profile: MachineProfile(),
                                 logFolder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { c.shutdown() }
        c.simulateLoss(show.switchers[0].id, lost: true)   // no device yet, and not a simulator: nothing happens
        XCTAssertTrue(c.failoverLog.isEmpty)
    }
}

final class ParallelSwitcherEditingTests: XCTestCase {
    func testParallelSwitcherAddsNoOutputs() {
        var show = Show.starter()
        let outputs = show.outputs.count
        let main = show.switchers[0].id
        let id = show.addParallelSwitcher(mirroring: main)
        XCTAssertEqual(show.outputs.count, outputs)
        XCTAssertEqual(show.switchers.first { $0.id == id }?.mirrorOf, main)
        XCTAssertEqual(show.switchers.first { $0.id == id }?.kind, show.switchers[0].kind)
    }
}
