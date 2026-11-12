import XCTest
@testable import OnCueCore

final class SourcesTests: XCTestCase {
    func testSourcesAreNumberedFrom100AndKeepTheirKind() throws {
        var show = Show.starter()
        let cams = show.cameras.count
        let black = show.addSource(kind: .internalSource, name: "Black", input: 0)
        let ndi = show.addSource(kind: .ndi, name: "Slides", input: 9, ndiName: "STUDIO-PC (Slides)")
        XCTAssertEqual(show.camera(black)?.number, 100)
        XCTAssertEqual(show.camera(ndi)?.number, 101)
        XCTAssertEqual(show.camera(ndi)?.ndiName, "STUDIO-PC (Slides)")
        XCTAssertEqual(show.cameras.filter { $0.kind == .camera }.count, cams)
        let data = try JSONEncoder().encode(show.camera(ndi)!)
        let back = try JSONDecoder().decode(Camera.self, from: data)
        XCTAssertEqual(back.kind, .ndi)
        XCTAssertEqual(try JSONDecoder().decode(Camera.self, from: Data(#"{"number": 3}"#.utf8)).kind, .camera, "older files")
    }

    func testAShotCanCutToASource() {
        var show = Show.starter()
        let song = show.items[0].id
        let bars = show.addSource(kind: .internalSource, name: "Colour bars", input: 1000)
        let shot = show.addShot(inItem: song, cameraID: bars, at: 0)
        XCTAssertNotNil(shot)
        XCTAssertTrue(show.shotRows(forItem: song)[0].issues.isEmpty, "a source is a valid shot target")
        XCTAssertEqual(InternalSourcePreset.atem.first { $0.name == "Colour bars" }?.input, 1000)
    }

    func testKeyUsage() {
        var show = Show.starter()
        let song = show.items[0].id
        for (k, action) in [FXAction.dskOn, .dskOff, .keyOn, .macro].enumerated() {
            if let c = show.addTrackCue(.fx, inItem: song, at: Double(k)) {
                show.updateCue(c, inItem: song) { $0.fxAction = action; $0.fxIndex = 0 }
            }
        }
        let usage = show.keyUsage()
        XCTAssertEqual(usage.map(\.name), ["DSK 1", "Upstream key 1"])
        XCTAssertEqual(usage.first?.cues, 2)
    }
}
