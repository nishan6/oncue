import XCTest
@testable import OnCueCore

final class ProjectStorageTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testPackageRoundTripAndInsideBackups() throws {
        let project = Project.starter(name: "Package", frameRate: .r25)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        var wrapper = try ProjectPackage.fileWrapper(for: project, existing: nil, now: t0)
        XCTAssertEqual(ProjectPackage.insideBackupDates(wrapper).count, 1)

        // A save 2 minutes later adds no backup; 5 minutes later adds one.
        wrapper = try ProjectPackage.fileWrapper(for: project, existing: wrapper, now: t0.addingTimeInterval(120))
        XCTAssertEqual(ProjectPackage.insideBackupDates(wrapper).count, 1)
        wrapper = try ProjectPackage.fileWrapper(for: project, existing: wrapper, now: t0.addingTimeInterval(300))
        XCTAssertEqual(ProjectPackage.insideBackupDates(wrapper).count, 2)

        // Only the newest 24 stay.
        for k in 2...40 {
            wrapper = try ProjectPackage.fileWrapper(for: project, existing: wrapper, now: t0.addingTimeInterval(Double(k) * 300))
        }
        let dates = ProjectPackage.insideBackupDates(wrapper)
        XCTAssertEqual(dates.count, ProjectPackage.insideBackupsKept)
        XCTAssertEqual(dates.last, t0.addingTimeInterval(40 * 300))

        guard case .project(let back) = try ProjectPackage.read(wrapper) else { return XCTFail("not a project") }
        XCTAssertEqual(back.name, "Package")
        XCTAssertEqual(back.playlists.count, 1)
    }

    func testOlderSingleFileShowIsRecognised() throws {
        var show = Show.starter()
        show.name = "Old show"
        let wrapper = FileWrapper(regularFileWithContents: try ShowCoding.encode(show))
        guard case .legacyShow(let s) = try ProjectPackage.read(wrapper) else { return XCTFail("expected legacy") }
        XCTAssertEqual(s.name, "Old show")
    }

    func testBackupFolderKeepsEveryCopyAndFindsTheNewest() throws {
        let root = try tempDir()
        var project = Project.starter(name: "Backed up", frameRate: .r25)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        for k in 0..<30 { try ProjectBackupFolder.write(project, root: root, date: t0.addingTimeInterval(Double(k) * 300)) }
        let dir = ProjectBackupFolder.folder(for: project, root: root)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 30, "nothing is deleted")
        XCTAssertEqual(ProjectBackupFolder.newest(for: project, root: root)?.date, t0.addingTimeInterval(29 * 300))

        // After a rename the same folder is found by the project's id.
        project.name = "Renamed"
        XCTAssertEqual(ProjectBackupFolder.folder(for: project, root: root), dir)
        let restored = try ProjectBackupFolder.read(try XCTUnwrap(ProjectBackupFolder.newest(for: project, root: root)?.url))
        XCTAssertEqual(restored.id, project.id)
    }

    func testLibraryCreateScanSortAndSearch() throws {
        let folder = try tempDir()
        var a = Project.starter(name: "Arena", frameRate: .r25)
        a.artist = "Shilpa Rao"
        a.editedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var b = Project.starter(name: "Club", frameRate: .r50)
        b.venue = "Rishikesh"
        b.editedAt = Date(timeIntervalSince1970: 1_800_001_000)
        let urlA = try ProjectLibrary.create(a, in: folder)
        let urlB = try ProjectLibrary.create(b, in: folder)
        try ShowCoding.encode(Show.starter()).write(to: folder.appendingPathComponent("Legacy.oncue"))

        var entries = ProjectLibrary.scan(folder)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.filter(\.isLegacy).count, 1)
        let club = try XCTUnwrap(entries.first { $0.url == urlB })
        XCTAssertEqual(club.frameRate, .r50)
        XCTAssertEqual(club.sceneCount, 1)

        try ProjectLibrary.setPinned(true, urlA, in: folder)
        entries = ProjectLibrary.sorted(ProjectLibrary.scan(folder))
        XCTAssertEqual(entries.first?.url, urlA, "pinned first")

        XCTAssertEqual(ProjectLibrary.filter(entries, search: "shilpa").map(\.url), [urlA])
        XCTAssertEqual(ProjectLibrary.filter(entries, search: "rishikesh").map(\.url), [urlB])

        try ProjectLibrary.setArchived(true, urlB, in: folder)
        XCTAssertTrue(ProjectLibrary.scan(folder).first { $0.url == urlB }!.archived)
    }

    func testDuplicateAndRename() throws {
        let folder = try tempDir()
        let url = try ProjectLibrary.create(Project.starter(name: "Tour", frameRate: .r25), in: folder)
        try ProjectLibrary.setPinned(true, url, in: folder)

        let copy = try ProjectLibrary.duplicate(url, in: folder)
        guard case .project(let original) = try ProjectPackage.read(at: url),
              case .project(let copied) = try ProjectPackage.read(at: copy) else { return XCTFail("unreadable") }
        XCTAssertNotEqual(original.id, copied.id)
        XCTAssertEqual(copied.name, "Tour copy")

        let renamed = try ProjectLibrary.rename(url, to: "Tour 2027", in: folder)
        XCTAssertEqual(renamed.lastPathComponent, "Tour 2027.oncue")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        guard case .project(let p) = try ProjectPackage.read(at: renamed) else { return XCTFail("unreadable") }
        XCTAssertEqual(p.name, "Tour 2027")
        XCTAssertEqual(p.id, original.id, "renaming keeps the identity")
        XCTAssertTrue(ProjectLibrary.scan(folder).first { $0.url == renamed }!.pinned, "pin follows the rename")
    }

    func testUniqueNames() throws {
        let folder = try tempDir()
        let first = try ProjectLibrary.create(Project.starter(name: "Same", frameRate: .r25), in: folder)
        let second = try ProjectLibrary.create(Project.starter(name: "Same", frameRate: .r25), in: folder)
        XCTAssertEqual(first.lastPathComponent, "Same.oncue")
        XCTAssertEqual(second.lastPathComponent, "Same 2.oncue")
    }
}
