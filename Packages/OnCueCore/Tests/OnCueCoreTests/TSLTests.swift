import XCTest
@testable import OnCueCore

final class TSLTests: XCTestCase {
    func test31() {
        let t = TallyState(index: 3, program: true, preview: false, text: "CAM 3 Kabir")
        let b = TSL.encode31(t)
        XCTAssertEqual(b.count, 18)
        XCTAssertEqual(b[0], 0x83)
        XCTAssertEqual(b[1], 0x31, "tally 1 on, brightness 3")
        XCTAssertEqual(TSL.decode31(b), t)
        XCTAssertEqual(TSL.decode31(TSL.encode31(TallyState(index: 1, text: "A very long camera name")))?.text, "A very long came")
    }

    func test40ChecksumAndColours() {
        let b = TSL.encode40(TallyState(index: 5, preview: true, text: "WIDE"))
        XCTAssertEqual(b.count, 22)
        XCTAssertEqual(b.prefix(19).reduce(0) { ($0 + Int($1)) } & 0x7F, 0, "header + data + checksum sum to 0 mod 128")
        XCTAssertEqual(b[19], 0x02, "two XDATA bytes")
        XCTAssertEqual(b[20], 0x22, "green on the right and left lamps")
    }

    func test50RoundTrip() {
        for unicode in [false, true] {
            let t = TallyState(index: 12, program: true, text: unicode ? "Cam 12 · Tara" : "Cam 12")
            let b = TSL.encode50(t, screen: 2, unicode: unicode)
            XCTAssertEqual(Int(b[0]) | Int(b[1]) << 8, b.count - 2)
            let back = TSL.decode50(b)
            XCTAssertEqual(back?.screen, 2)
            XCTAssertEqual(back?.tallies, [t])
        }
        let preview = TSL.decode50(TSL.encode50(TallyState(index: 1, preview: true)))
        XCTAssertEqual(preview?.tallies.first?.preview, true)
        XCTAssertEqual(preview?.tallies.first?.program, false)
    }

    func testTCPFramingDoublesDLE() {
        XCTAssertEqual(TSL.frameTCP([0x01, 0xFE, 0x02]), [0xFE, 0x02, 0x01, 0xFE, 0xFE, 0x02])
    }
}
