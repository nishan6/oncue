import XCTest
@testable import OnCueCore

final class EditingTests: XCTestCase {

    // MARK: Running order

    func testAddSongsAndSegmentsInPlace() {
        var show = Show.starter()
        let first = show.items[0].id
        let seg = show.addSegment(after: first)
        let song = show.addSong(title: "Closer")
        XCTAssertEqual(show.items.map(\.id), [first, seg, song])
        XCTAssertEqual(show.item(seg)?.kind, .segment)
        XCTAssertEqual(show.item(seg)?.timeBase, .seconds)
        XCTAssertEqual(show.item(song)?.title, "Closer")
        XCTAssertNotNil(show.mainShotTrackID(inItem: song), "new items get a shots track")
    }

    func testRenameReorderDuplicateDelete() {
        var show = Show.starter()
        let a = show.items[0].id
        let b = show.addSong(title: "B")
        let c = show.addSong(title: "C")
        show.renameItem(a, to: "A")
        show.moveItems(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(show.items.map(\.title), ["C", "A", "B"])
        show.addShot(inItem: b, cameraID: show.cameras[0].id)
        let copy = show.duplicateItem(b)!
        XCTAssertEqual(show.items.map(\.title), ["C", "A", "B", "B copy"])
        XCTAssertEqual(show.shotRows(forItem: copy).count, 1)
        XCTAssertNotEqual(show.shotRows(forItem: copy)[0].id, show.shotRows(forItem: b)[0].id, "fresh IDs")
        show.deleteItems([c, copy])
        XCTAssertEqual(show.items.map(\.title), ["A", "B"])
    }

    func testMoveHelperMatchesSwiftUISemantics() {
        XCTAssertEqual(Show.moved([0, 1, 2, 3], fromOffsets: [0], toOffset: 4), [1, 2, 3, 0])
        XCTAssertEqual(Show.moved([0, 1, 2, 3], fromOffsets: [3], toOffset: 0), [3, 0, 1, 2])
        XCTAssertEqual(Show.moved([0, 1, 2, 3], fromOffsets: [1, 2], toOffset: 4), [0, 3, 1, 2])
        XCTAssertEqual(Show.moved([0, 1, 2, 3], fromOffsets: [2], toOffset: 1), [0, 2, 1, 3])
    }

    // MARK: Sections

    func testAddRenameDeleteSections() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [] }
        let intro = show.addSection(toItem: song, name: "Intro")!
        let verse = show.addSection(toItem: song)!
        XCTAssertEqual(show.item(song)?.sortedSections.map(\.at), [0, 32], "8 bars of 4/4 apart")
        show.renameSection(verse, inItem: song, to: "Verse 1")
        XCTAssertEqual(show.item(song)?.sortedSections.map(\.name), ["Intro", "Verse 1"])
        show.deleteSection(intro, inItem: song)
        XCTAssertEqual(show.item(song)?.sections.count, 1)
    }

    func testMovingSectionsCarriesTheirShots() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [] }
        let a = show.addSection(toItem: song, name: "A", at: 0)!
        let b = show.addSection(toItem: song, name: "B", at: 16)!
        let c = show.addSection(toItem: song, name: "C", at: 48)!
        let cams = show.sortedCameras.map(\.id)
        let shotA = show.addShot(inItem: song, cameraID: cams[0], at: 4)!
        let shotB = show.addShot(inItem: song, cameraID: cams[1], at: 20)!
        let shotC = show.addShot(inItem: song, cameraID: cams[2], at: 48)!

        // Move B (16 beats long) to the end: C then starts at 16, B after C.
        show.moveSections(inItem: song, fromOffsets: [1], toOffset: 3)
        let item = show.item(song)!
        XCTAssertEqual(item.sortedSections.map(\.name), ["A", "C", "B"])
        XCTAssertEqual(item.sections.first { $0.id == a }?.at, 0)
        XCTAssertEqual(item.sections.first { $0.id == c }?.at, 16)
        let cLength = 32.0 // default section length for the last section (8 bars)
        XCTAssertEqual(item.sections.first { $0.id == b }?.at, 16 + cLength)
        let at = Dictionary(uniqueKeysWithValues: show.shotRows(forItem: song).map { ($0.id, $0.cue.at) })
        XCTAssertEqual(at[shotA], 4)
        XCTAssertEqual(at[shotC], 16)
        XCTAssertEqual(at[shotB], 16 + cLength + 4)
        XCTAssertEqual(show.shotRows(forItem: song).first { $0.id == shotB }?.sectionID, b)
    }

    // MARK: Cameras

    func testCamerasNumberingAndDeletion() throws {
        var show = Show.starter()
        let five = show.addCamera()
        XCTAssertEqual(show.cameras.first { $0.id == five }?.number, 5)
        XCTAssertEqual(show.cameras.first { $0.id == five }?.input, 5)
        XCTAssertThrowsError(try show.renumberCamera(five, to: 1)) { error in
            XCTAssertEqual(error as? ShowEditError, .cameraNumberTaken(1))
        }
        XCTAssertThrowsError(try show.renumberCamera(five, to: 0))
        try show.renumberCamera(five, to: 12)
        XCTAssertEqual(show.sortedCameras.map(\.number), [1, 2, 3, 4, 12])
        XCTAssertEqual(show.nextFreeCameraNumber, 5)

        show.updateCamera(five) { $0.name = "Jib"; $0.operatorName = "Rohan"; $0.number = 99 }
        let cam = show.cameras.first { $0.id == five }!
        XCTAssertEqual(cam.label, "Jib (Rohan)")
        XCTAssertEqual(cam.number, 12, "numbers only change through renumberCamera")

        let song = show.items[0].id
        show.addShot(inItem: song, cameraID: five)
        show.addShot(inItem: song, cameraID: five)
        XCTAssertEqual(show.shotCount(forCamera: five), 2)
        XCTAssertEqual(show.deleteCamera(five), 2)
        XCTAssertEqual(show.shotRows(forItem: song).map(\.cue.cameraID), [nil, nil], "shots keep their place")
        XCTAssertTrue(show.shotRows(forItem: song).allSatisfy { $0.issues.contains { $0.kind == .noCamera } })
    }

    // MARK: Shots

    func testAddShotsAtEndAfterAndInSection() {
        var show = Show.starter()
        let song = show.items[0].id // sections at 0, 16, 48 beats (4/4)
        let cams = show.sortedCameras.map(\.id)
        let s1 = show.addShot(inItem: song, cameraID: cams[0])!
        let s2 = show.addShot(inItem: song, cameraID: cams[1])!
        XCTAssertEqual(show.shotRows(forItem: song).map(\.cue.at), [0, 4], "one bar apart")
        let between = show.addShot(inItem: song, after: s1)!
        XCTAssertEqual(show.shotRows(forItem: song).first { $0.id == between }?.cue.at, 2, "halfway when no room")
        let chorusID = show.item(song)!.sortedSections[2].id
        let inChorus = show.addShot(inItem: song, inSection: chorusID)!
        XCTAssertEqual(show.shotRows(forItem: song).first { $0.id == inChorus }?.cue.at, 48)
        XCTAssertEqual(show.shotRows(forItem: song).map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(show.shotRows(forItem: song).map(\.id), [s1, between, s2, inChorus])
    }

    func testDragReorderKeepsTimeSlots() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [] }
        let cams = show.sortedCameras.map(\.id)
        let ids = (0..<4).map { show.addShot(inItem: song, cameraID: cams[$0], at: Double($0 * 4))! }
        // Drag the last shot to the top.
        show.moveShots(inItem: song, section: nil, fromOffsets: [3], toOffset: 0)
        let rows = show.shotRows(forItem: song)
        XCTAssertEqual(rows.map(\.id), [ids[3], ids[0], ids[1], ids[2]])
        XCTAssertEqual(rows.map(\.cue.at), [0, 4, 8, 12], "slots unchanged")
        XCTAssertEqual(rows.map(\.cue.cameraID), [cams[3], cams[0], cams[1], cams[2]])
    }

    func testReorderWithinSectionOnly() {
        var show = Show.starter()
        let song = show.items[0].id // sections at 0, 16, 48
        let verse = show.item(song)!.sortedSections[1].id
        let cams = show.sortedCameras.map(\.id)
        let intro = show.addShot(inItem: song, cameraID: cams[0], at: 0)!
        let v1 = show.addShot(inItem: song, cameraID: cams[1], at: 16)!
        let v2 = show.addShot(inItem: song, cameraID: cams[2], at: 24)!
        show.moveShots(inItem: song, section: verse, fromOffsets: [1], toOffset: 0)
        let at = Dictionary(uniqueKeysWithValues: show.shotRows(forItem: song).map { ($0.id, $0.cue.at) })
        XCTAssertEqual(at[intro], 0)
        XCTAssertEqual(at[v2], 16)
        XCTAssertEqual(at[v1], 24)
    }

    func testNudgeDuplicateEditDelete() {
        var show = Show.starter()
        let song = show.items[0].id
        let cams = show.sortedCameras.map(\.id)
        let a = show.addShot(inItem: song, cameraID: cams[0], at: 0)!
        let b = show.addShot(inItem: song, cameraID: cams[1], at: 4)!
        show.nudgeShot(b, inItem: song, by: -1)
        XCTAssertEqual(show.shotRows(forItem: song).map(\.id), [b, a])
        show.updateCue(a, inItem: song) { $0.text = "Wide"; $0.note = "Hold"; $0.transition = .auto }
        let copies = show.duplicateCues([a], inItem: song)
        XCTAssertEqual(copies.count, 1)
        let copy = show.shotRows(forItem: song).first { $0.id == copies[0] }!.cue
        XCTAssertEqual(copy.text, "Wide")
        XCTAssertEqual(copy.note, "Hold")
        XCTAssertEqual(copy.transition, .auto)
        XCTAssertEqual(copy.cameraID, cams[0])
        show.setCamera(cams[3], forCues: [a, b], inItem: song)
        show.setTransition(.cut, forCues: [a], inItem: song)
        XCTAssertEqual(show.shotRows(forItem: song).filter { [a, b].contains($0.id) }.map(\.cue.cameraID), [cams[3], cams[3]])
        show.deleteCues([a, copies[0]], inItem: song)
        XCTAssertEqual(show.shotRows(forItem: song).map(\.id), [b])
    }

    func testScriptChecks() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.bpm = 120; $0.sections = [] }
        let cams = show.sortedCameras.map(\.id)
        show.addShot(inItem: song, cameraID: cams[0], at: 0)
        show.addShot(inItem: song, cameraID: cams[0], at: 1)   // same camera, 0.5 s after
        show.addShot(inItem: song, at: 8)                      // no camera
        let rows = show.shotRows(forItem: song)
        XCTAssertTrue(rows[0].issues.contains { $0.kind == .tooShort }, "0.5 s is under the 1.5 s minimum")
        XCTAssertTrue(rows[1].issues.contains { $0.kind == .sameCameraAsPrevious })
        XCTAssertTrue(rows[2].issues.contains { $0.kind == .noCamera })
        XCTAssertEqual(rows[1].lengthSeconds ?? 0, 3.5, accuracy: 1e-9)
        XCTAssertEqual(show.unusedCameras(inItem: song).map(\.number), [2, 3, 4])
    }

    func testOrderBasedItemsStayNumbered() {
        var show = Show.starter()
        let encore = show.addSong(title: "Encore")
        show.setTimeBase(.order, forItem: encore)
        let a = show.addShot(inItem: encore)!
        let b = show.addShot(inItem: encore)!
        let mid = show.addShot(inItem: encore, after: a)!
        XCTAssertEqual(show.shotRows(forItem: encore).map(\.id), [a, mid, b])
        XCTAssertEqual(show.shotRows(forItem: encore).map(\.cue.at), [1, 2, 3])
        show.deleteCues([mid], inItem: encore)
        XCTAssertEqual(show.shotRows(forItem: encore).map(\.cue.at), [1, 2])
    }

    func testTimeBaseConversionKeepsTiming() {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.bpm = 120 }
        show.addShot(inItem: song, at: 8) // 8 beats at 120 BPM = 4 s
        show.setTimeBase(.seconds, forItem: song)
        XCTAssertEqual(show.shotRows(forItem: song).first?.cue.at ?? -1, 4, accuracy: 1e-9)
        XCTAssertEqual(show.item(song)?.sortedSections.map(\.at), [0, 8, 24])
        show.setTimeBase(.bars, forItem: song)
        XCTAssertEqual(show.shotRows(forItem: song).first?.cue.at ?? -1, 8, accuracy: 1e-9)
    }

    // MARK: Whole workflow survives save and reopen

    func testSampleProductionSurvivesSaveAndReopen() throws {
        let show = Show.sample()
        XCTAssertEqual(show.cameraCount, 8)
        XCTAssertEqual(show.items.map(\.title), ["Neon Skyline", "Monsoon Letters", "Crowd talk break", "Encore: Homecoming"])
        XCTAssertEqual(show.shotRows(forItem: show.items[0].id).count, 19)
        XCTAssertEqual(show.item(show.items[0].id)?.sections.count, 7)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample-\(UUID()).oncue")
        defer { try? FileManager.default.removeItem(at: url) }
        try ShowFileIO.write(show, to: url)
        let reopened = try ShowFileIO.read(url)
        XCTAssertEqual(reopened, show)
        XCTAssertEqual(reopened.id, show.id, "show identity survives, so its workspace can be restored")
    }
}
