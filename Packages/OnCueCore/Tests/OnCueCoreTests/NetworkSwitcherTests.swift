import XCTest
@testable import OnCueCore

final class NetworkSwitcherTests: XCTestCase {
    func testVMixTally() {
        // One digit per input from input 1: input 2 on preview, input 4 on program.
        let t = VMixProtocol.parseTally("TALLY OK 0201000")
        XCTAssertEqual(t?.program, 4)
        XCTAssertEqual(t?.preview, 2)
        XCTAssertNil(VMixProtocol.parseTally("FUNCTION OK Completed"))
        XCTAssertNil(VMixProtocol.parseTally("TALLY OK 0000")?.program)
    }

    func testOBSAuthentication() {
        let a = OBSProtocol.authentication(password: "secret", salt: "c2FsdA==", challenge: "Y2hhbGxlbmdl")
        XCTAssertEqual(a.count, 44, "base64 of 32 bytes")
        XCTAssertEqual(a, OBSProtocol.authentication(password: "secret", salt: "c2FsdA==", challenge: "Y2hhbGxlbmdl"))
        XCTAssertNotEqual(a, OBSProtocol.authentication(password: "other", salt: "c2FsdA==", challenge: "Y2hhbGxlbmdl"))
    }

    func testOBSScenesTopToBottom() {
        let scenes: [[String: Any]] = [["sceneName": "Bottom", "sceneIndex": 0], ["sceneName": "Top", "sceneIndex": 2],
                                       ["sceneName": "Middle", "sceneIndex": 1]]
        XCTAssertEqual(OBSProtocol.sceneOrder(scenes), ["Top", "Middle", "Bottom"])
    }

    func testLineSwitcherHostAndPort() {
        var c = SwitcherConfig(name: "vMix")
        c.kind = .vmix
        c.host = "10.0.0.9"
        XCTAssertEqual(VMixSwitcher(config: c).endpoint.1, 8099)
        c.host = "10.0.0.9:9000"
        XCTAssertEqual(VMixSwitcher(config: c).endpoint.0, "10.0.0.9")
        XCTAssertEqual(VMixSwitcher(config: c).endpoint.1, 9000)
    }
}

final class WaveBProtocolTests: XCTestCase {
    func testRossTalk() {
        XCTAssertEqual(RossTalk.preview(me: 2, input: 6), "XPT ME:2:PST:IN:6")
        XCTAssertEqual(RossTalk.program(me: 1, input: 3), "XPT ME:1:PGM:IN:3")
        XCTAssertEqual(RossTalk.customControl(4), "CC 1:05")
    }

    func testRolandV160Replies() {
        let replies = RolandProtocol.replies("PGM:HDMI2,INPUT2;ACK;PST:SDI1,INPUT9;ACK;")
        XCTAssertEqual(replies.compactMap { RolandProtocol.inputNumber($0, command: "PGM") }, [2])
        XCTAssertEqual(replies.compactMap { RolandProtocol.inputNumber($0, command: "PST") }, [9])
    }

    func testRolandV60Tally() {
        let t = RolandProtocol.tally(RolandProtocol.replies("\u{02}TLY:0,1,2,0,0,0,0,0;").first!)
        XCTAssertEqual(t?.program, 2)
        XCTAssertEqual(t?.preview, 3)
    }

    func testPanasonic() {
        XCTAssertEqual(PanasonicProtocol.selectBus(2, input: 1), "SBUS:02:50")
        XCTAssertEqual(PanasonicProtocol.selectBus(3, input: 13), "SBUS:03:62")
        XCTAssertEqual(PanasonicProtocol.busStatus("ABSC:02:51:1")?.input, 2)
        XCTAssertNil(PanasonicProtocol.busStatus("ABSC:02:70:1")?.input, "colour bars is not an input")
    }
}

final class PanasonicIPTests: XCTestCase {
    func testCrosspoints() {
        XCTAssertEqual(PanasonicProtocol.crosspointSelect(bus: 1, input: 1), "SBUS:01:01")
        XCTAssertEqual(PanasonicProtocol.crosspointSelect(bus: 2, input: 32), "SBUS:02:32")
        XCTAssertEqual(PanasonicProtocol.crosspoint("ABSC:01:05")?.input, 5)
        XCTAssertEqual(PanasonicProtocol.crosspoint("ABUS:02:07")?.bus, 2)
        XCTAssertNil(PanasonicProtocol.crosspoint("EROR:01"))
    }
}
