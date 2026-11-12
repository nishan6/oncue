import XCTest
@testable import OnCueCore

final class ControlsTests: XCTestCase {
    func testAPC40DefaultsMapPadsAndButtons() {
        let bindings = MIDIBinding.apc40Defaults()
        XCTAssertEqual(ControlMapping.binding(for: 0, number: 0, isCC: false, value: 127, in: bindings)?.command, .takeCamera)
        XCTAssertEqual(ControlMapping.binding(for: 0, number: 0, isCC: false, value: 127, in: bindings)?.cameraNumber, 1)
        XCTAssertEqual(ControlMapping.binding(for: 0, number: 82, isCC: false, value: 127, in: bindings)?.command, .next)
        XCTAssertNil(ControlMapping.binding(for: 0, number: 82, isCC: false, value: 0, in: bindings), "releases do nothing")
        XCTAssertNil(ControlMapping.binding(for: 1, number: 82, isCC: false, value: 127, in: bindings), "other channel")
    }

    func testPadColorsShowTally() {
        let show = Show.starter() // cameras 1-4
        let colors = ControlMapping.padColors(show: show, bindings: MIDIBinding.apc40Defaults(),
                                              program: show.sortedCameras[0].id, preview: show.sortedCameras[2].id)
        XCTAssertEqual(colors[0], .red)
        XCTAssertEqual(colors[1], .dim)
        XCTAssertEqual(colors[2], .green)
        XCTAssertEqual(colors[10], .off, "pads without a camera are dark")
    }

    func testOSCAddresses() {
        XCTAssertEqual(ControlMapping.command(fromOSC: "/oncue/next", intArgument: nil)?.0, .next)
        let take = ControlMapping.command(fromOSC: "/oncue/takeCamera/7", intArgument: nil)
        XCTAssertEqual(take?.0, .takeCamera)
        XCTAssertEqual(take?.1, 7)
        XCTAssertEqual(ControlMapping.command(fromOSC: "/oncue/previewcamera", intArgument: 3)?.1, 3)
        XCTAssertNil(ControlMapping.command(fromOSC: "/other/next", intArgument: nil))
        XCTAssertNil(ControlMapping.command(fromOSC: "/oncue/dance", intArgument: nil))
    }

    func testTapTempo() {
        var t = TapTempo()
        XCTAssertNil(t.tap(at: 0))
        XCTAssertNil(t.tap(at: 0.5))
        XCTAssertEqual(t.tap(at: 1.0)!, 120, accuracy: 1e-9)
        XCTAssertNil(t.tap(at: 5), "a long pause starts over")
    }

    func testMIDILearnReplacesOldBindings() {
        var show = Show.starter()
        show.setMIDIBinding(.next, channel: 2, number: 60, isCC: false)
        XCTAssertEqual(show.midiBindings.filter { $0.command == .next }.count, 1)
        XCTAssertEqual(show.midiBindings.first { $0.command == .next }?.number, 60)
        show.setMIDIBinding(.panic, channel: 2, number: 60, isCC: false)
        XCTAssertNil(show.midiBindings.first { $0.command == .next }, "the message moved to panic")
        show.resetMIDIBindingsToAPC40()
        XCTAssertEqual(show.midiBindings.count, MIDIBinding.apc40Defaults().count)
        XCTAssertEqual(show.midiBindings.first { $0.command == .next }?.number, 82)
    }

    func testControllerPerformsTakeCameraAsAManualCut() throws {
        var show = Show.starter()
        let song = show.items[0].id
        for k in 0..<3 { show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: Double(k * 4)) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let controller = EngineController(show: show, itemID: song, profile: MachineProfile(), logFolder: folder)
        defer { controller.shutdown() }
        controller.connectSwitcher()
        controller.setMode(.cut)
        controller.next()
        controller.perform(.takeCamera, camera: 4)
        XCTAssertEqual(controller.status.program, 4)
        XCTAssertNotNil(controller.status.pauseReason, "a take from the controller is the director's manual cut")
        controller.perform(.resume)
        XCTAssertNil(controller.status.pauseReason)
        controller.perform(.panic)
        XCTAssertEqual(controller.status.mode(show.mainOutput?.id), .display)
        controller.saveLog()
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "the switch log is written")
        let log = try SwitchLog.decode(Data(contentsOf: files[0]))
        XCTAssertTrue(log.cuts.contains { $0.input == 4 })
    }
}
