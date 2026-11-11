import XCTest
@testable import OnCueCore

final class PersistenceTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                                "Missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("OnCueTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    // MARK: New files save and reopen

    func testStarterShowRoundTrips() throws {
        let show = Show.starter()
        let decoded = try ShowCoding.decode(try ShowCoding.encode(show))
        XCTAssertEqual(decoded, show)
        XCTAssertEqual(decoded.schemaVersion, Show.currentSchemaVersion)
    }

    func testEncodedFileCarriesCurrentSchemaVersion() throws {
        var show = Show.starter()
        show.schemaVersion = 0
        let json = try JSONSerialization.jsonObject(with: try ShowCoding.encode(show)) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, Show.currentSchemaVersion)
    }

    func testSaveCloseReopenOnDisk() throws {
        let url = try tempDir().appendingPathComponent("show.oncue")
        var show = Show.starter()
        show.name = "Saved and reopened"
        try ShowFileIO.write(show, to: url)
        let reopened = try ShowFileIO.read(url)
        XCTAssertEqual(reopened, show)
    }

    /// Every field set to a non-default value must survive encode → decode. This guards the key
    /// names in TolerantDecoding.swift against typos.
    func testEveryFieldSurvivesRoundTrip() throws {
        let show = Self.fullyPopulatedShow()
        let decoded = try ShowCoding.decode(try ShowCoding.encode(show))
        XCTAssertEqual(decoded, show)
    }

    // MARK: Existing files remain readable

    func testGoldenSchema0FileOpens() throws {
        let show = try ShowCoding.decode(try fixture("show-v0-golden"))
        XCTAssertEqual(show.schemaVersion, Show.currentSchemaVersion, "migrated in memory")
        XCTAssertEqual(show.name, "Golden v0 show")
        XCTAssertEqual(show.cameras.count, 3)
        XCTAssertEqual(show.cameras[0].operatorName, "Ravi")
        XCTAssertEqual(show.cameras[1].displayName, "Jib")
        XCTAssertEqual(show.switchers.count, 2)
        XCTAssertEqual(show.switchers[1].role, .sub)
        XCTAssertEqual(show.switchers[1].feedInput, 8)
        XCTAssertEqual(show.outputs[1].bus, .aux)
        XCTAssertTrue(show.outputs[1].mirrorMain)
        XCTAssertEqual(show.items.count, 2)
        let song = show.items[0]
        XCTAssertEqual(song.syncMode, .midiClock)
        XCTAssertEqual(song.bpm, 124)
        XCTAssertEqual(song.sections.map(\.name), ["Intro", "Verse", "Chorus"])
        XCTAssertEqual(song.tracks.count, 4)
        XCTAssertEqual(song.tracks[0].cues[1].transition, .auto)
        XCTAssertEqual(song.tracks[1].cues[0].fxAction, .dskOn)
        XCTAssertEqual(song.tracks[2].cues[0].oscAddress, "/composition/columns/2/connect")
        XCTAssertEqual(song.tracks[3].cues[0].controlAction, .loadNext)
        XCTAssertEqual(show.items[1].hardOut, "21:30")
        XCTAssertEqual(show.ptzCameras[0].proto, .panasonic)
        XCTAssertEqual(show.comments[0].text, "Jib earlier?")
        XCTAssertEqual(show.midiBindings.count, 2)
        XCTAssertEqual(show.settings.ltcFPS, 25)
        XCTAssertEqual(show.settings.monitors.first?.name, "Backstage")
    }

    func testGoldenFileResavesAsCurrentSchemaAndReopens() throws {
        let original = try ShowCoding.decode(try fixture("show-v0-golden"))
        let resaved = try ShowCoding.decode(try ShowCoding.encode(original))
        XCTAssertEqual(resaved, original)
    }

    // MARK: Missing fields get defaults

    func testMissingFieldsGetDefaults() throws {
        let json = """
        {"name": "Sparse", "items": [{"title": "Song A", "tracks": [{"kind": "shots", "cues": [{"at": 4}]}]}],
         "cameras": [{"number": 7}], "switchers": [{}], "settings": {}}
        """
        let show = try ShowCoding.decode(Data(json.utf8))
        XCTAssertEqual(show.name, "Sparse")
        XCTAssertEqual(show.schemaVersion, Show.currentSchemaVersion)
        let item = try XCTUnwrap(show.items.first)
        XCTAssertEqual(item.kind, .song)
        XCTAssertEqual(item.timeBase, .bars)
        XCTAssertEqual(item.syncMode, .tap)
        XCTAssertEqual(item.bpm, 120)
        XCTAssertEqual(item.beatsPerBar, 4)
        XCTAssertTrue(item.sections.isEmpty)
        let cue = try XCTUnwrap(item.tracks.first?.cues.first)
        XCTAssertEqual(cue.at, 4)
        XCTAssertEqual(cue.transition, .cut)
        XCTAssertEqual(cue.ptzPreset, 1)
        XCTAssertNil(cue.fxAction)
        XCTAssertEqual(show.cameras.first?.number, 7)
        XCTAssertEqual(show.cameras.first?.displayName, "Cam 7")
        XCTAssertEqual(show.switchers.first?.kind, .simulator)
        XCTAssertEqual(show.switchers.first?.inputCount, 20)
        XCTAssertEqual(show.settings.minShotSeconds, 1.5)
        XCTAssertTrue(show.outputs.isEmpty)
    }

    func testEmptyObjectIsAnEmptyShow() throws {
        let show = try ShowCoding.decode(Data("{}".utf8))
        XCTAssertEqual(show.itemCount, 0)
        XCTAssertEqual(show.cameraCount, 0)
    }

    func testUnknownEnumValuesFallBackSafely() throws {
        let json = """
        {"schemaVersion": 1, "items": [{"title": "X", "kind": "hologram", "syncMode": "telepathy",
          "tracks": [{"kind": "laser", "name": "Future", "cues": [{"at": 1, "fxAction": "warp", "transition": "teleport"}]}]}],
         "midiBindings": [{"command": "selfDestruct", "number": 5}]}
        """
        let show = try ShowCoding.decode(Data(json.utf8))
        let item = try XCTUnwrap(show.items.first)
        XCTAssertEqual(item.kind, .song)
        XCTAssertEqual(item.syncMode, .tap)
        XCTAssertEqual(item.tracks.first?.kind, .notes, "unknown track kinds are kept, as notes")
        XCTAssertEqual(item.tracks.first?.cues.count, 1, "cues of unknown tracks are not lost")
        XCTAssertNil(item.tracks.first?.cues.first?.fxAction)
        XCTAssertEqual(item.tracks.first?.cues.first?.transition, .cut)
        XCTAssertEqual(show.midiBindings.first?.command, .stop)
    }

    // MARK: Future versions are refused safely

    func testFutureSchemaIsRefusedWithClearError() {
        let json = #"{"schemaVersion": 99, "name": "From the future"}"#
        XCTAssertThrowsError(try ShowCoding.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? ShowFileError, .unsupportedVersion(found: 99, supported: Show.currentSchemaVersion))
            XCTAssertTrue(error.localizedDescription.contains("newer version of OnCue"))
        }
    }

    func testFutureSchemaFileIsLeftUntouched() throws {
        let url = try tempDir().appendingPathComponent("future.oncue")
        let bytes = Data(#"{"schemaVersion": 2, "name": "Future"}"#.utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try ShowFileIO.read(url))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    // MARK: Corrupt files

    func testEmptyFileGivesClearError() {
        XCTAssertThrowsError(try ShowCoding.decode(Data())) { error in
            XCTAssertEqual(error as? ShowFileError, .empty)
            XCTAssertTrue(error.localizedDescription.contains("empty"))
        }
    }

    func testNonJSONGivesClearError() {
        XCTAssertThrowsError(try ShowCoding.decode(Data("not a show {".utf8))) { error in
            guard case .notAShowFile? = error as? ShowFileError else {
                return XCTFail("expected notAShowFile, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("Nothing was changed"))
        }
    }

    func testJSONArrayIsNotAShow() {
        XCTAssertThrowsError(try ShowCoding.decode(Data("[1, 2, 3]".utf8))) { error in
            guard case .notAShowFile? = error as? ShowFileError else {
                return XCTFail("expected notAShowFile, got \(error)")
            }
        }
    }

    func testWrongValueTypeNamesTheField() {
        let json = #"{"items": [{"title": "Song", "bpm": "fast"}]}"#
        XCTAssertThrowsError(try ShowCoding.decode(Data(json.utf8))) { error in
            guard case .invalidContent(let detail)? = error as? ShowFileError else {
                return XCTFail("expected invalidContent, got \(error)")
            }
            XCTAssertTrue(detail.contains("bpm"), detail)
            XCTAssertTrue(detail.contains("number"), detail)
        }
    }

    func testCorruptFileOnDiskIsNotModified() throws {
        let url = try tempDir().appendingPathComponent("corrupt.oncue")
        let bytes = Data("{\"name\": \"half a fi".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try ShowFileIO.read(url))
        XCTAssertEqual(try Data(contentsOf: url), bytes, "reading must never change the file")
    }

    func testMissingFileGivesError() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID()).oncue")
        XCTAssertThrowsError(try ShowFileIO.read(url))
    }

    // MARK: Fixtures

    static func fullyPopulatedShow() -> Show {
        var show = Show()
        show.name = "Every field"
        let swA = SwitcherConfig(id: UUID(), name: "A", kind: .atem, host: "10.0.0.2", me: 1, role: .main,
                                 parentID: nil, feedInput: 0,
                                 companion: CompanionMapping(inputs: [CompanionInputButtons(input: 3,
                                     preview: CompanionButton(page: 2, row: 3, column: 4, bank: 5, enabled: true),
                                     program: CompanionButton(page: 6, row: 7, column: 8, bank: 9, enabled: true))],
                                     cut: CompanionButton(page: 1, row: 1, column: 1, bank: 1, enabled: true),
                                     auto: CompanionButton(page: 1, row: 1, column: 2, bank: 2, enabled: true)),
                                 inputCount: 40)
        let swB = SwitcherConfig(id: UUID(), name: "B", kind: .companion, host: "", me: 0, role: .sub,
                                 parentID: swA.id, feedInput: 12, companion: CompanionMapping(), inputCount: 8)
        show.switchers = [swA, swB]
        let out = OutputConfig(id: UUID(), name: "LED", switcherID: swA.id, bus: .aux, auxIndex: 2, mirrorMain: true)
        show.outputs = [out]
        let ptz = PTZCamera(id: UUID(), name: "PTZ", proto: .viscaTCP, host: "10.0.0.9", port: 5678, macroBase: 4,
                            switcherID: swA.id, companionStart: CompanionButton(page: 3, row: 1, column: 0, bank: 1, enabled: true))
        show.ptzCameras = [ptz]
        let cam = Camera(id: UUID(), number: 12, name: "Steadicam", operatorName: "Asha", switcherID: swB.id, input: 5, ptzID: ptz.id)
        show.cameras = [cam]
        let osc = OSCTarget(id: UUID(), name: "Resolume", host: "10.0.0.50", port: 7001)
        show.oscTargets = [osc]
        let cue = Cue(id: UUID(), at: 33.5, cameraID: cam.id, text: "Tight", note: "Rack focus", transition: .auto,
                      fxAction: .keyOn, fxIndex: 2, fxValue: 3, controlAction: .jump, jumpItemID: UUID(),
                      oscTargetID: osc.id, oscAddress: "/a/b", oscArgs: "1 \"two\"", ptzCameraID: ptz.id, ptzPreset: 9)
        let track = Track(id: UUID(), kind: .ptz, name: "PTZ track", outputID: out.id, switcherID: swA.id, cues: [cue], muted: true)
        let item = RundownItem(id: UUID(), kind: .segment, title: "Segment", timeBase: .seconds, syncMode: .ltc, bpm: 98,
                               beatsPerBar: 3, ltcStart: "10:00:00:00", plannedDuration: 420, hardOut: "22:15",
                               sections: [SongSection(id: UUID(), name: "Open", at: 2)], tracks: [track], notes: "Notes")
        show.items = [item]
        show.comments = [Comment(id: UUID(), itemID: item.id, cueID: cue.id, author: "PM", text: "Earlier",
                                 date: Date(timeIntervalSince1970: 1_800_000_000), resolved: true)]
        show.midiBindings = [MIDIBinding(id: UUID(), command: .takeCamera, cameraNumber: 12, channel: 3, number: 40, isCC: true)]
        show.settings = ShowSettings(ltcFPS: 29.97, minShotSeconds: 2.5, unusedCameraMinutes: 7, manualCutWindow: 0.6,
                                     monitors: [MonitorConfig(id: UUID(), name: "Cam wall", kind: .cameras,
                                                              cameraIDs: [cam.id], screenName: "LG")])
        return show
    }
}
