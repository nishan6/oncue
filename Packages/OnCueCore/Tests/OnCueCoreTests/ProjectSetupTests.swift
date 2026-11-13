import XCTest
@testable import OnCueCore

final class ProjectSetupTests: XCTestCase {
    func testCameraLines() {
        let c = ProjectSetup.cameras("Wide – Arjun\nCentre - Meera\nJib, Rohan\n\nSteadicam\nDrums | Isha")
        XCTAssertEqual(c.map(\.name), ["Wide", "Centre", "Jib", "Steadicam", "Drums"])
        XCTAssertEqual(c.map(\.operatorName), ["Arjun", "Meera", "Rohan", "", "Isha"])
        XCTAssertEqual(ProjectSetup.cameras("Stage-left – Kabir")[0].name, "Stage-left", "a hyphen inside a name stays")
    }

    func testSetlistLines() {
        let s = ProjectSetup.scenes("1. Neon Skyline\n2) Ballad\n12 Encore\n* Opening speech\nNo number\n24K Magic")
        XCTAssertEqual(s.map(\.title), ["Neon Skyline", "Ballad", "Encore", "Opening speech", "No number", "24K Magic"])
        XCTAssertEqual(s.map(\.number), ["1", "2", "12", "", "", ""])
        XCTAssertEqual(s.map(\.segment), [false, false, false, true, false, false])
    }

    func testApplyBuildsCamerasSwitcherAndScenes() {
        var p = Project.starter(name: "Assam", frameRate: .r25)
        var setup = ProjectSetup()
        setup.cameraCount = 6
        setup.cameraLines = "Wide – Arjun\nCentre – Meera"
        setup.switcherKind = .atem
        setup.switcherHost = " 192.168.10.240 "
        setup.setlist = "1. Intro\n2. Song two\n* Speech"
        p.apply(setup)
        XCTAssertEqual(p.cameras.count, 6)
        XCTAssertEqual(p.cameras[0].name, "Wide")
        XCTAssertEqual(p.cameras[1].operatorName, "Meera")
        XCTAssertEqual(p.cameras.map(\.input), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(p.switchers.count, 1)
        XCTAssertEqual(p.switchers[0].kind, .atem)
        XCTAssertEqual(p.switchers[0].host, "192.168.10.240")
        XCTAssertTrue(p.cameras.allSatisfy { $0.switcherID == p.switchers[0].id })
        XCTAssertTrue(p.outputs.allSatisfy { $0.switcherID == p.switchers[0].id })
        XCTAssertEqual(p.playlists[0].items.map(\.title), ["Intro", "Song two", "Speech"])
        XCTAssertEqual(p.playlists[0].items.map(\.kind), [.song, .song, .segment])
        XCTAssertEqual(p.playlists[0].items.map(\.number), ["1", "2", "3"])
    }

    func testMoreNamesThanCountAddsCameras() {
        var p = Project.starter(name: "X", frameRate: .r25)
        var setup = ProjectSetup()
        setup.cameraCount = 2
        setup.cameraLines = "A\nB\nC"
        p.apply(setup)
        XCTAssertEqual(p.cameras.count, 3)
        XCTAssertEqual(p.playlists[0].items.count, 1, "no setlist keeps the starter scene")
    }
}
