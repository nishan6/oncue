import XCTest
@testable import OnCueCore

final class ShotVocabularyTests: XCTestCase {
    func testStandardLists() {
        let v = ShotVocabulary()
        XCTAssertEqual(v.sizes.map(\.short), ["ECU", "CU", "MCU", "MS", "MLS", "LS", "WS", "EWS"])
        XCTAssertEqual(v.statuses.map(\.label), ["Planned", "Confirmed", "Cut"])
        XCTAssertEqual(v.transitions.map(\.base), [.mix, .dip, .wipe, .dve, .stinger])
        XCTAssertEqual(v.movements.count, 13)
        XCTAssertEqual(v.framings.count, 7)
        XCTAssertTrue(v.cast.isEmpty)
    }

    func testNewShotDefaults() {
        let cue = Cue(at: 0)
        XCTAssertEqual(cue.shotStatus, "planned")
        XCTAssertEqual(cue.transitionStyle, "mix")
        XCTAssertNil(cue.transitionFrames)
        XCTAssertTrue(cue.reviews.isEmpty)
    }

    func testCutStatusGreysOutAndCustomStatusesFollowTheirRole() {
        var v = ShotVocabulary()
        let maybe = ShotStatusTerm.custom("Maybe")
        let dropped = ShotStatusTerm.custom("Dropped at rehearsal", role: .cut)
        v.statuses += [maybe, dropped]
        var cue = Cue(at: 0)
        XCTAssertFalse(v.isCut(cue))
        cue.shotStatus = "cut"
        XCTAssertTrue(v.isCut(cue))
        cue.shotStatus = maybe.key
        XCTAssertFalse(v.isCut(cue))
        cue.shotStatus = dropped.key
        XCTAssertTrue(v.isCut(cue))
    }

    func testOldShotsDecodeWithDefaults() throws {
        let json = #"{"at": 4, "text": "Wide", "transition": "auto"}"#
        let cue = try JSONDecoder().decode(Cue.self, from: Data(json.utf8))
        XCTAssertEqual(cue.transition, .auto)
        XCTAssertEqual(cue.transitionStyle, "mix")
        XCTAssertEqual(cue.shotStatus, "planned")
        XCTAssertEqual(cue.shotSize, "")
    }

    func testOldProjectGetsStandardVocabulary() throws {
        let json = #"{"sceneDefaults": {}, "roles": []}"#
        let p = try JSONDecoder().decode(ProjectProperties.self, from: Data(json.utf8))
        XCTAssertEqual(p.shots, ShotVocabulary())
        XCTAssertEqual(p.countdown.standbySeconds, 5)
    }

    func testRemovedBuiltInsComeBackInPlaceAndCustomTermsStay() throws {
        var v = ShotVocabulary()
        let custom = ShotTerm.custom("Drone top shot", short: "DRONE")
        v.sizes.removeAll { $0.key == "mcu" }
        v.sizes.append(custom)
        v.transitions.append(.custom("Logo sting", base: .stinger, durationFrames: 25))
        let data = try JSONEncoder().encode(v)
        let back = try JSONDecoder().decode(ShotVocabulary.self, from: data)
        XCTAssertEqual(back.sizes.map(\.key), ["ecu", "cu", "mcu", "ms", "mls", "ls", "ws", "ews", custom.key])
        XCTAssertEqual(back.transitions.last?.label, "Logo sting")
        XCTAssertEqual(back.transitions.last?.durationFrames, 25)
        XCTAssertEqual(back.transitions.last?.short, "LOGO STING")
    }

    func testShotDetailsSurviveAProjectRoundTrip() throws {
        var project = Project.starter(name: "Arena", frameRate: .r25)
        let vocal = ShotTerm.custom("Lead vocal")
        project.properties.shots.cast = [vocal]
        project.properties.countdown.standbySeconds = 3
        let itemIndex = 0
        guard let trackIndex = project.playlists[0].items[itemIndex].tracks.firstIndex(where: { $0.kind == .shots }) else {
            return XCTFail("starter scene has no shots track")
        }
        var cue = Cue(at: 0)
        cue.shotSize = "cu"
        cue.movement = "push-in"
        cue.framing = "single"
        cue.subjects = [vocal.key]
        cue.shotStatus = "confirmed"
        cue.transition = .auto
        cue.transitionStyle = "dip"
        cue.transitionFrames = 12
        cue.reviews = [ShotNote(text: "Too slow at rehearsal", author: "Nishan", date: Date(timeIntervalSince1970: 1_800_000_000))]
        project.playlists[0].items[itemIndex].tracks[trackIndex].cues = [cue]

        let data = try ProjectCoding.encode(project)
        guard case .project(let back) = try ProjectCoding.decode(data) else { return XCTFail("not a project") }
        let backCue = try XCTUnwrap(back.playlists[0].items[itemIndex].tracks[trackIndex].cues.first)
        XCTAssertEqual(backCue.shotSize, "cu")
        XCTAssertEqual(backCue.movement, "push-in")
        XCTAssertEqual(backCue.framing, "single")
        XCTAssertEqual(backCue.subjects, [vocal.key])
        XCTAssertEqual(backCue.shotStatus, "confirmed")
        XCTAssertEqual(backCue.transitionStyle, "dip")
        XCTAssertEqual(backCue.transitionFrames, 12)
        XCTAssertEqual(backCue.reviews.first?.text, "Too slow at rehearsal")
        XCTAssertEqual(back.properties.shots.cast.first?.label, "Lead vocal")
        XCTAssertEqual(back.properties.countdown.standbySeconds, 3)
    }
}
