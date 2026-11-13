import XCTest
@testable import OnCueCore

final class ConsoleTests: XCTestCase {
    private func msgs(_ kind: ConsoleKind, _ configure: (inout ConsoleAction) -> Void, settings: (inout ConsoleSettings) -> Void = { _ in }) -> [ConsoleMessage] {
        var a = ConsoleAction()
        configure(&a)
        var s = ConsoleSettings(kind: kind)
        settings(&s)
        return ConsoleWire.messages(a, settings: s)
    }

    func testGrandMA() {
        XCTAssertEqual(msgs(.grandMA3) { $0.kind = .goCue; $0.number = 12.5; $0.list = 3 }, [.osc("/gma3/cmd", [.string("Goto Sequence 3 Cue 12.5")])])
        XCTAssertEqual(msgs(.grandMA3, { $0.kind = .goNext }, settings: { $0.prefix = "/show/" }), [.osc("/show/cmd", [.string("Go+ Sequence 1")])])
        XCTAssertEqual(msgs(.grandMA2) { $0.kind = .goCue; $0.number = 5; $0.list = 1 }, [.line("Goto Executor 1 Cue 5")])
        var s = ConsoleSettings(kind: .grandMA2)
        s.password = "pw"
        XCTAssertEqual(ConsoleWire.greeting(s), ["Login \"administrator\" \"pw\""])
        XCTAssertTrue(msgs(.grandMA2) { $0.kind = .mute }.isEmpty, "not something a lighting desk does")
    }

    func testXPression() {
        XCTAssertEqual(msgs(.xpression) { $0.kind = .take; $0.number = 105; $0.list = 1; $0.channel = 7 }, [.line("TAKE 105:0:7")])
        XCTAssertEqual(msgs(.xpression) { $0.kind = .takeOut; $0.number = 105 }, [.line("SEQO 105")])
        XCTAssertEqual(msgs(.xpression) { $0.kind = .clearLayer; $0.list = 2; $0.channel = 3 }, [.line("CLFB 1:3")])
    }

    func testResolume() {
        XCTAssertEqual(msgs(.resolume) { $0.kind = .playClip; $0.channel = 2; $0.number = 4 }, [.osc("/composition/layers/2/clips/4/connect", [.int(1)])])
        XCTAssertEqual(msgs(.resolume) { $0.kind = .column; $0.number = 3 }, [.osc("/composition/columns/3/connect", [.int(1)])])
    }

    func testX32() {
        XCTAssertEqual(msgs(.x32) { $0.kind = .mute; $0.channel = 3; $0.on = true }, [.osc("/ch/03/mix/on", [.int(0)])])
        XCTAssertEqual(msgs(.x32) { $0.kind = .scene; $0.number = 7 }, [.osc("/-action/goscene", [.int(7)])])
        XCTAssertEqual(ConsoleWire.x32Fader(dB: 0), 0.75, accuracy: 1e-9)
        XCTAssertEqual(ConsoleWire.x32Fader(dB: 10), 1, accuracy: 1e-9)
        XCTAssertEqual(ConsoleWire.x32Fader(dB: -200), 0)
    }

    func testYamaha() {
        XCTAssertEqual(msgs(.yamahaRCP) { $0.kind = .mute; $0.channel = 16; $0.on = true }, [.line("set MIXER:Current/InCh/Fader/On 15 0 0")])
        XCTAssertEqual(msgs(.yamahaRCP) { $0.kind = .fader; $0.channel = 1; $0.level = -10 }, [.line("set MIXER:Current/InCh/Fader/Level 0 0 -1000")])
        XCTAssertEqual(msgs(.yamahaRCP, { $0.kind = .scene; $0.number = 5 }, settings: { $0.yamahaTF = true }), [.line("ssrecall_ex scene_a 5")])
    }

    func testAllenHeath() {
        XCTAssertEqual(msgs(.allenHeath) { $0.kind = .scene; $0.number = 130 }, [.bytes([0xB0, 0x00, 0x01, 0xC0, 0x01])])
        XCTAssertEqual(msgs(.allenHeath, { $0.kind = .mute; $0.channel = 1; $0.on = false }, settings: { $0.midiChannel = 2 }),
                       [.bytes([0x91, 0x00, 0x3F, 0x91, 0x00, 0x00])])
    }

    func testEveryListedActionProducesSomething() {
        for kind in ConsoleKind.allCases {
            for action in kind.actions {
                var a = ConsoleAction(kind: action)
                a.text = "Go"
                XCTAssertFalse(ConsoleWire.messages(a, settings: ConsoleSettings(kind: kind)).isEmpty, "\(kind) \(action)")
            }
        }
    }
}

final class ConsoleReadBackTests: XCTestCase {
    func testX32Updates() {
        var s = ConsoleReadBack()
        XCTAssertTrue(s.apply(address: "/-show/prepos/current", value: 7))
        XCTAssertFalse(s.apply(address: "/-show/prepos/current", value: 7))
        XCTAssertTrue(s.apply(address: "/ch/03/mix/on", value: 0))
        XCTAssertTrue(s.apply(address: "/ch/05/mix/on", value: 0))
        XCTAssertTrue(s.apply(address: "/ch/05/mix/on", value: 1))
        XCTAssertFalse(s.apply(address: "/ch/01/mix/fader", value: 1))
        XCTAssertEqual(s.summary, "scene 7 · muted 3")
    }
}
