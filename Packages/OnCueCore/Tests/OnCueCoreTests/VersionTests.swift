import XCTest
@testable import OnCueCore

final class VersionTests: XCTestCase {
    func testSaveRestoreAndLimits() throws {
        var show = Show.sample()
        let originalTitle = show.items[0].title
        XCTAssertTrue(show.saveVersion(name: "Before rehearsal"))
        XCTAssertFalse(show.saveVersion(name: "auto", automatic: true), "nothing changed since the last version")
        show.renameItem(show.items[0].id, to: "Changed")
        XCTAssertTrue(show.saveVersion(name: "Before Live", automatic: true))
        XCTAssertEqual(show.versions.count, 2)
        XCTAssertEqual(try show.show(in: show.versions[0]).items[0].title, originalTitle)
        XCTAssertTrue(try show.show(in: show.versions[0]).versions.isEmpty, "versions don't nest")

        try show.restoreVersion(show.versions[0].id)
        XCTAssertEqual(show.items[0].title, originalTitle)
        XCTAssertEqual(show.versions.count, 2, "restoring keeps the list")

        // Survives the file.
        let back = try ShowCoding.decode(ShowCoding.encode(show))
        XCTAssertEqual(back.versions.map(\.name), ["Before rehearsal", "Before Live"])

        // Automatic versions make room first.
        for k in 0..<40 {
            show.renameItem(show.items[0].id, to: "Edit \(k)")
            show.saveVersion(name: "auto \(k)", automatic: true)
        }
        XCTAssertEqual(show.versions.count, Show.maxVersions)
        XCTAssertEqual(show.versions.first?.name, "Before rehearsal", "named versions are kept")
    }

    func testBackupFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("oncue-backup-\(UUID().uuidString)")
        var show = Show.sample()
        show.name = "Arena: Night/2"
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for k in 0..<5 { try ShowBackup.write(show, to: folder, date: start.addingTimeInterval(Double(k)), keep: 3) }
        let dir = folder.appendingPathComponent("Arena- Night-2")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        XCTAssertEqual(files.count, 4, "latest plus three timestamped copies")
        XCTAssertTrue(files.contains("Arena- Night-2.oncue"))
        let latest = try ShowCoding.decode(Data(contentsOf: dir.appendingPathComponent("Arena- Night-2.oncue")))
        XCTAssertEqual(latest.id, show.id)
    }
}
