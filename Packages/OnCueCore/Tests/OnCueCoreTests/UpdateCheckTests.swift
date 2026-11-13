import XCTest
@testable import OnCueCore

final class UpdateCheckTests: XCTestCase {
    private func release(tag: String = "v1.2.0", assets: [String], draft: Bool = false, pre: Bool = false) -> Data {
        let list = assets.map { #"{"name":"\#($0)","browser_download_url":"https://github.com/nishan6/oncue/releases/download/\#(tag)/\#($0)","size":1234}"# }
        return Data(#"{"tag_name":"\#(tag)","name":"OnCue 1.2.0","body":"Fixes","draft":\#(draft),"prerelease":\#(pre),"published_at":"2026-11-20T10:00:00Z","html_url":"https://github.com/nishan6/oncue/releases/tag/\#(tag)","assets":[\#(list.joined(separator: ","))]}"#.utf8)
    }

    func testVersionsCompareNumerically() {
        XCTAssertLessThan(AppVersion("1.9.0")!, AppVersion("1.10.0")!)
        XCTAssertLessThan(AppVersion("1.2")!, AppVersion("1.2.1")!)
        XCTAssertEqual(AppVersion("1.2")!, AppVersion("v1.2.0")!)
        XCTAssertLessThan(AppVersion("1.2.0", build: 5)!, AppVersion("1.2.0", build: 6)!)
        XCTAssertNil(AppVersion("beta"))
        XCTAssertNil(AppVersion("1.-2"))
    }

    func testDMGNames() {
        XCTAssertEqual(UpdateCheck.dmgVersion("OnCue-1.2.0-57.dmg")?.0, "1.2.0")
        XCTAssertEqual(UpdateCheck.dmgVersion("OnCue-1.2.0-57.dmg")?.1, 57)
        XCTAssertNil(UpdateCheck.dmgVersion("OnCue-1.2.0.dmg"))
        XCTAssertNil(UpdateCheck.dmgVersion("Other-1.2.0-5.dmg"))
        XCTAssertNil(UpdateCheck.dmgVersion("OnCue-1.2.0-57.zip"))
    }

    func testOffersANewerRelease() throws {
        let u = try XCTUnwrap(UpdateCheck.update(fromRelease: release(assets: ["notes.txt", "OnCue-1.2.0-57.dmg"]),
                                                 current: AppVersion("1.1.0", build: 40)!))
        XCTAssertEqual(u.version.description, "1.2.0")
        XCTAssertEqual(u.version.build, 57)
        XCTAssertEqual(u.notes, "Fixes")
        XCTAssertEqual(u.size, 1234)
        XCTAssertEqual(u.dmgURL.lastPathComponent, "OnCue-1.2.0-57.dmg")
        XCTAssertNotNil(u.published)
    }

    func testNoOfferWhenSameOlderSkippedDraftOrWithoutDMG() {
        let current = AppVersion("1.2.0", build: 57)!
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.2.0-57.dmg"]), current: current))
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.1.0-50.dmg"]), current: current))
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.3.0-60.dmg"]), current: current, skipped: "1.3.0-60"))
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.3.0-60.dmg"], draft: true), current: current))
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.3.0-60.dmg"], pre: true), current: current))
        XCTAssertNil(UpdateCheck.update(fromRelease: release(assets: ["source.zip"]), current: current))
        XCTAssertNil(UpdateCheck.update(fromRelease: Data("not json".utf8), current: current))
        XCTAssertNotNil(UpdateCheck.update(fromRelease: release(assets: ["OnCue-1.2.0-58.dmg"]), current: current), "a newer build of the same version")
    }

    func testNeverChecksDuringLiveMode() {
        let now = Date()
        XCTAssertTrue(UpdateCheck.shouldCheck(lastCheck: nil, now: now, live: false, enabled: true))
        XCTAssertFalse(UpdateCheck.shouldCheck(lastCheck: nil, now: now, live: true, enabled: true))
        XCTAssertFalse(UpdateCheck.shouldCheck(lastCheck: nil, now: now, live: false, enabled: false))
        XCTAssertFalse(UpdateCheck.shouldCheck(lastCheck: now.addingTimeInterval(-3600), now: now, live: false, enabled: true))
        XCTAssertTrue(UpdateCheck.shouldCheck(lastCheck: now.addingTimeInterval(-6 * 3600), now: now, live: false, enabled: true))
    }

    func testProfileKeepsUpdateAndAccessibilitySettings() throws {
        let p = try JSONDecoder().decode(MachineProfile.self, from: Data(#"{"textScale":3,"tallyShapes":true}"#.utf8))
        XCTAssertTrue(p.checkForUpdates, "on by default")
        XCTAssertEqual(p.textScale, 1.5, "clamped")
        XCTAssertTrue(p.tallyShapes)
    }
}
