import XCTest
@testable import OnCueCore

final class ShotPhraseTests: XCTestCase {
    private var vocab: ShotVocabulary {
        var v = ShotVocabulary()
        v.cast = [ShotTerm(key: "lead", label: "Lead vocal"), ShotTerm(key: "drums", label: "Drums")]
        return v
    }

    func testShortFormsAndFullNames() {
        let p = ShotPhrase.parse("CU push 2S lead vocal", vocabulary: vocab)
        XCTAssertEqual(p.size, "cu")
        XCTAssertEqual(p.movement, "push-in")
        XCTAssertEqual(p.framing, "two-shot")
        XCTAssertEqual(p.subjects, ["lead"])
        XCTAssertEqual(p.text, "")
        XCTAssertEqual(ShotPhrase.parse("close-up zoom in drums", vocabulary: vocab).movement, "zoom-in")
    }

    func testCameraAndLeftoverDescription() {
        let p = ShotPhrase.parse("3 ws Crowd hands up on chorus", vocabulary: vocab)
        XCTAssertEqual(p.camera, 3)
        XCTAssertEqual(p.size, "ws")
        XCTAssertEqual(p.framing, "crowd")
        XCTAssertEqual(p.text, "hands up on chorus", "unmatched words keep their case")
    }

    func testLongestMatchWins() {
        // "medium close-up" must not be read as "MS" + leftover.
        XCTAssertEqual(ShotPhrase.parse("medium close-up", vocabulary: vocab).size, "mcu")
        XCTAssertEqual(ShotPhrase.parse("ecu", vocabulary: vocab).size, "ecu")
    }

    func testSecondSizeIsText() {
        let p = ShotPhrase.parse("cu ws", vocabulary: vocab)
        XCTAssertEqual(p.size, "cu")
        XCTAssertEqual(p.text, "ws")
    }

    func testApplyOnlyChangesWhatWasTyped() {
        var cue = Cue(at: 0)
        cue.text = "Keep"
        cue.movement = "pan"
        ShotPhrase.parse("cu confirmed", vocabulary: vocab).apply(to: &cue) { _ in nil }
        XCTAssertEqual(cue.shotSize, "cu")
        XCTAssertEqual(cue.movement, "pan")
        XCTAssertEqual(cue.text, "Keep")
        XCTAssertEqual(cue.shotStatus, "confirmed")
        XCTAssertEqual(ShotPhrase.parse("cu push 2s", vocabulary: vocab).summary(vocab), "CU · PUSH · 2S")
    }
}
