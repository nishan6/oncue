import XCTest
@testable import OnCueCore

final class MachineProfileTests: XCTestCase {

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("OnCueProfile-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testMissingProfileIsCreatedWithDefaults() throws {
        let dir = try tempDir()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
        let store = MachineProfileStore(directory: dir)
        XCTAssertEqual(store.profile, MachineProfile())
        XCTAssertNil(store.issue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path), "profile file created")
    }

    func testProfileChangesPersistAcrossLaunches() throws {
        let dir = try tempDir()
        let store = MachineProfileStore(directory: dir)
        try store.update {
            $0.machineName = "Backup Mac"
            $0.midiClockSource = "IAC Driver Bus 1"
            $0.ltcChannel = 2
            $0.backupRole = "backup"
            $0.primaryHost = "10.0.0.20"
        }
        let relaunched = MachineProfileStore(directory: dir)
        XCTAssertEqual(relaunched.profile, store.profile)
        XCTAssertEqual(relaunched.profile.machineName, "Backup Mac")
    }

    func testOpeningAnotherShowDoesNotTouchTheProfile() throws {
        let dir = try tempDir()
        let store = MachineProfileStore(directory: dir)
        try store.update { $0.midiClockSource = "My Ableton"; $0.crewInterface = "en7" }
        let before = try Data(contentsOf: store.fileURL)

        // The golden schema-0 show carries another Mac's MIDI port, LTC device and interface.
        let show = try ShowCoding.decode(try fixture("show-v0-golden"))
        XCTAssertEqual(show.name, "Golden v0 show")
        _ = try ShowCoding.encode(show)

        let reloaded = MachineProfileStore(directory: dir)
        XCTAssertEqual(reloaded.profile.midiClockSource, "My Ableton")
        XCTAssertEqual(reloaded.profile.crewInterface, "en7")
        XCTAssertEqual(try Data(contentsOf: store.fileURL), before, "profile file unchanged")
    }

    func testShowFilesCarryNoMachineSettings() throws {
        let data = try ShowCoding.encode(try ShowCoding.decode(try fixture("show-v0-golden")))
        let text = String(decoding: data, as: UTF8.self)
        for key in ["midiClockSource", "ltcDeviceUID", "crewInterface", "backupRole", "primaryHost",
                    "controllerSource", "companionHost", "logFolder", "oscControlPort", "crewPort"] {
            XCTAssertFalse(text.contains("\"\(key)\""), "\(key) must not be written into show files")
        }
    }

    func testProfileChangesDoNotMutateShows() throws {
        let dir = try tempDir()
        let store = MachineProfileStore(directory: dir)
        let show = Show.starter()
        let before = try ShowCoding.encode(show)
        try store.update { $0.midiClockSource = "Changed"; $0.backupRole = "primary" }
        XCTAssertEqual(try ShowCoding.encode(show), before)
    }

    func testCorruptProfileIsKeptAsBackupAndDefaultsUsed() throws {
        let dir = try tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(MachineProfileStore.fileName)
        let garbage = Data("{ this is not json".utf8)
        try garbage.write(to: file)

        let store = MachineProfileStore(directory: dir)
        XCTAssertEqual(store.profile, MachineProfile())
        XCTAssertNotNil(store.issue)

        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("MachineProfile.unreadable-") }
        XCTAssertEqual(backups.count, 1, "the unreadable file is kept, not deleted")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(backups[0])), garbage)
        XCTAssertNoThrow(try JSONDecoder().decode(MachineProfile.self, from: Data(contentsOf: file)), "a fresh profile was written")
    }

    func testNewerProfileFormatIsNotOverwrittenInPlace() throws {
        let dir = try tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(MachineProfileStore.fileName)
        let future = Data(#"{"schemaVersion": 7, "midiClockSource": "Future port"}"#.utf8)
        try future.write(to: file)

        let store = MachineProfileStore(directory: dir)
        XCTAssertNotNil(store.issue)
        XCTAssertEqual(store.profile.midiClockSource, "")
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("MachineProfile.unreadable-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(backups[0])), future)
    }

    func testProfileMissingFieldsGetDefaults() throws {
        let profile = try JSONDecoder().decode(MachineProfile.self, from: Data(#"{"machineName": "Main"}"#.utf8))
        XCTAssertEqual(profile.machineName, "Main")
        XCTAssertEqual(profile.crewPort, 8080)
        XCTAssertEqual(profile.companionPort, 8000)
        XCTAssertTrue(profile.apcLEDs)
        XCTAssertEqual(profile.backupRole, "off")
    }
}
