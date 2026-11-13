import XCTest
@testable import OnCueCore

final class NetworkSwitcherTests: XCTestCase {
    func testVMixTally() {
        let t = VMixProtocol.parseTally("TALLY OK 0201000")
        XCTAssertEqual(t?.program, 3)
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
